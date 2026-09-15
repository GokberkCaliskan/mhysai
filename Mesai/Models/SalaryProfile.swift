import Foundation

enum PayPeriod: String, Codable, CaseIterable, Identifiable {
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly: "Aylık"
        case .yearly: "Yıllık"
        }
    }
}

enum AmountType: String, Codable, CaseIterable, Identifiable {
    case net
    case gross

    var id: String { rawValue }

    var title: String {
        switch self {
        case .net: "Net"
        case .gross: "Brüt"
        }
    }
}

/// Kullanıcının haftalık çalışma düzeni. Saatler gece yarısından itibaren dakika cinsinden tutulur.
struct WorkSchedule: Codable, Equatable {
    /// `Calendar` hafta günleri: 1 = Pazar, 2 = Pazartesi … 7 = Cumartesi
    var workdays: Set<Int>
    var startMinute: Int
    var endMinute: Int
    var hasLunchBreak: Bool
    var lunchStartMinute: Int
    var lunchDurationMinutes: Int
    var observesPublicHolidays: Bool

    static let standard = WorkSchedule(
        workdays: [2, 3, 4, 5, 6],
        startMinute: 9 * 60,
        endMinute: 18 * 60,
        hasLunchBreak: true,
        lunchStartMinute: 12 * 60 + 30,
        lunchDurationMinutes: 60,
        observesPublicHolidays: true
    )

    var isValid: Bool {
        !workdays.isEmpty && endMinute > startMinute && dailyPaidMinutes > 0
    }

    /// Öğle arası düşüldükten sonra sıradan bir iş gününün ücretli dakikası.
    var dailyPaidMinutes: Int {
        let total = endMinute - startMinute
        guard hasLunchBreak else { return total }
        let lunchStart = max(lunchStartMinute, startMinute)
        let lunchEnd = min(lunchStartMinute + lunchDurationMinutes, endMinute)
        return total - max(0, lunchEnd - lunchStart)
    }
}

struct SalaryProfile: Codable, Equatable {
    var amount: Double
    var period: PayPeriod
    var amountType: AmountType
    var schedule: WorkSchedule

    init(amount: Double, period: PayPeriod, amountType: AmountType = .net, schedule: WorkSchedule) {
        self.amount = amount
        self.period = period
        self.amountType = amountType
        self.schedule = schedule
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        amount = try c.decode(Double.self, forKey: .amount)
        period = try c.decode(PayPeriod.self, forKey: .period)
        amountType = try c.decodeIfPresent(AmountType.self, forKey: .amountType) ?? .net
        schedule = try c.decode(WorkSchedule.self, forKey: .schedule)
    }

    /// Girilen tutarın aylık karşılığı (net ya da brüt, girildiği gibi).
    var monthlyAmount: Double {
        period == .monthly ? amount : amount / 12
    }

    /// Brüt girildiyse o yılın 12 aylık bordrosu.
    func payroll(year: Int) -> [PayrollMonth] {
        guard amountType == .gross else { return [] }
        return TurkishPayroll.months(monthlyGross: monthlyAmount, parameters: .forYear(year))
    }

    /// Eline geçen net maaş; brütte vergi dilimi yükseldikçe aydan aya azalır.
    func netSalary(month: Int, year: Int) -> Double {
        switch amountType {
        case .net: monthlyAmount
        case .gross: payroll(year: year).first { $0.month == month }?.net ?? 0
        }
    }

    var isValid: Bool { amount > 0 && schedule.isValid }
}
