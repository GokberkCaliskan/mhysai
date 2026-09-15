import Foundation

enum WorkStatus: Equatable {
    case beforeWork(startsAt: Date)
    case working(endsAt: Date)
    case onBreak(resumesAt: Date)
    case afterWork(nextStart: Date?)
    case dayOff(reason: String, nextStart: Date?)
}

/// Maaşı saniyelik kazanca çeviren motor.
///
/// Her ayın maaşı, o ayın toplam ücretli saniyesine bölünür. Böylece 20 iş günü çeken bir ayda
/// günlük kazanç, 23 iş günü çeken aya göre daha yüksek olur; öğle araları ve arifeler de hesaba katılır.
final class EarningsEngine {
    let profile: SalaryProfile
    let calendar: Calendar
    private var rateCache: [Date: Double] = [:]

    init(profile: SalaryProfile, calendar: Calendar = .turkish) {
        self.profile = profile
        self.calendar = calendar
    }

    private var schedule: WorkSchedule { profile.schedule }

    // MARK: - Günlük aralıklar

    func holiday(on date: Date) -> Holiday? {
        guard schedule.observesPublicHolidays else { return nil }
        return TurkishHolidays.holiday(on: date, calendar: calendar)
    }

    func isWorkday(_ date: Date) -> Bool {
        schedule.workdays.contains(calendar.component(.weekday, from: date))
    }

    /// Verilen gündeki ücretli çalışma aralıkları (öğle arası ve tatiller düşülmüş).
    func paidIntervals(on date: Date) -> [DateInterval] {
        guard isWorkday(date) else { return [] }

        var endMinute = schedule.endMinute
        switch holiday(on: date)?.kind {
        case .fullDay: return []
        case .afternoon: endMinute = min(endMinute, Holiday.afternoonStartMinute)
        case nil: break
        }
        guard endMinute > schedule.startMinute else { return [] }

        var ranges = [(schedule.startMinute, endMinute)]
        if schedule.hasLunchBreak {
            let lunchStart = schedule.lunchStartMinute
            let lunchEnd = lunchStart + schedule.lunchDurationMinutes
            ranges = ranges.flatMap { start, end -> [(Int, Int)] in
                guard lunchStart < end, lunchEnd > start else { return [(start, end)] }
                return [(start, min(lunchStart, end)), (max(lunchEnd, start), end)]
                    .filter { $0.1 > $0.0 }
            }
        }

        let dayStart = calendar.startOfDay(for: date)
        return ranges.compactMap { start, end in
            guard let s = calendar.date(byAdding: .minute, value: start, to: dayStart),
                  let e = calendar.date(byAdding: .minute, value: end, to: dayStart) else { return nil }
            return DateInterval(start: s, end: e)
        }
    }

    private func paidSeconds(on day: Date, within range: DateInterval) -> TimeInterval {
        paidIntervals(on: day).reduce(0) { total, interval in
            guard let overlap = interval.intersection(with: range) else { return total }
            return total + overlap.duration
        }
    }

    // MARK: - Oranlar

    /// O ayda çalışılan her ücretli saniyenin karşılığı (₺/sn).
    func ratePerSecond(forMonthOf date: Date) -> Double {
        guard let month = calendar.dateInterval(of: .month, for: date) else { return 0 }
        if let cached = rateCache[month.start] { return cached }

        var seconds: TimeInterval = 0
        var day = month.start
        while day < month.end {
            seconds += paidIntervals(on: day).reduce(0) { $0 + $1.duration }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        let rate = seconds > 0 ? netSalary(forMonthOf: date) / seconds : 0
        rateCache[month.start] = rate
        return rate
    }

    /// O ayın eline geçen net maaşı.
    func netSalary(forMonthOf date: Date) -> Double {
        let c = calendar.dateComponents([.year, .month], from: date)
        return profile.netSalary(month: c.month ?? 1, year: c.year ?? 2026)
    }

    func workdayCount(inMonthOf date: Date) -> Int {
        guard let month = calendar.dateInterval(of: .month, for: date) else { return 0 }
        var count = 0
        var day = month.start
        while day < month.end {
            if !paidIntervals(on: day).isEmpty { count += 1 }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return count
    }

    // MARK: - Kazanç

    /// İki an arasında, yalnızca ücretli mesai saatlerine düşen kazanç.
    func earnings(from start: Date, to end: Date) -> Double {
        guard end > start else { return 0 }
        let range = DateInterval(start: start, end: end)
        var total = 0.0
        var day = calendar.startOfDay(for: start)
        while day < end {
            let seconds = paidSeconds(on: day, within: range)
            if seconds > 0 {
                total += seconds * ratePerSecond(forMonthOf: day)
            }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return total
    }

    func earnedToday(at now: Date) -> Double {
        earnings(from: calendar.startOfDay(for: now), to: now)
    }

    func earnedThisMonth(at now: Date) -> Double {
        guard let month = calendar.dateInterval(of: .month, for: now) else { return 0 }
        return earnings(from: month.start, to: now)
    }

    /// Yıl başından bugüne: tamamlanan aylar tam net maaş, içinde bulunulan ay kısmi.
    func earnedThisYear(at now: Date) -> Double {
        let c = calendar.dateComponents([.year, .month], from: now)
        let year = c.year ?? 2026
        let completed = (1..<(c.month ?? 1)).reduce(0) { $0 + profile.netSalary(month: $1, year: year) }
        return completed + earnedThisMonth(at: now)
    }

    /// Bugün mesai sonunda toplam kazanılacak tutar.
    func expectedToday(at now: Date) -> Double {
        let dayStart = calendar.startOfDay(for: now)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        return earnings(from: dayStart, to: dayEnd)
    }

    func dayProgress(at now: Date) -> Double {
        let intervals = paidIntervals(on: now)
        let total = intervals.reduce(0) { $0 + $1.duration }
        guard total > 0 else { return 0 }
        let done = paidSeconds(on: now, within: DateInterval(start: calendar.startOfDay(for: now), end: now))
        return min(1, done / total)
    }

    /// Bu anda saniyede kazanılan (mesai dışındaysa, bu ayın mesai oranı).
    func currentRatePerSecond(at now: Date) -> Double {
        ratePerSecond(forMonthOf: now)
    }

    // MARK: - Emek karşılığı

    /// Bir tutarı kazanmak için gereken ücretli çalışma süresi (bu ayın oranıyla).
    func workDuration(for amount: Double, at date: Date) -> TimeInterval {
        let rate = ratePerSecond(forMonthOf: date)
        return rate > 0 ? amount / rate : 0
    }

    /// Ay başından itibaren çalışınca tutarın hangi anda kazanılmış olacağı.
    /// Tutar aylık maaşı aşıyorsa `nil`.
    func dateWhenEarned(_ amount: Double, inMonthOf date: Date) -> Date? {
        guard amount > 0, let month = calendar.dateInterval(of: .month, for: date) else { return nil }
        let rate = ratePerSecond(forMonthOf: date)
        guard rate > 0 else { return nil }

        var remaining = amount / rate
        var day = month.start
        while day < month.end {
            for interval in paidIntervals(on: day) {
                if remaining <= interval.duration {
                    return interval.start.addingTimeInterval(remaining)
                }
                remaining -= interval.duration
            }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return nil
    }

    // MARK: - Durum

    func nextWorkStart(after date: Date, searchDays: Int = 21) -> Date? {
        var day = calendar.startOfDay(for: date)
        for _ in 0..<searchDays {
            if let start = paidIntervals(on: day).first(where: { $0.start > date })?.start {
                return start
            }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return nil
    }

    func status(at now: Date) -> WorkStatus {
        let intervals = paidIntervals(on: now)

        guard let first = intervals.first, let last = intervals.last else {
            let next = nextWorkStart(after: now)
            if isWorkday(now), let holiday = holiday(on: now) {
                return .dayOff(reason: holiday.name, nextStart: next)
            }
            return .dayOff(reason: isWorkday(now) ? "İzin günü" : "Hafta sonu", nextStart: next)
        }

        if now < first.start { return .beforeWork(startsAt: first.start) }
        if now >= last.end { return .afterWork(nextStart: nextWorkStart(after: now)) }
        if let current = intervals.first(where: { $0.start <= now && now < $0.end }) {
            return .working(endsAt: current.end)
        }
        let resume = intervals.first(where: { $0.start > now })?.start ?? last.end
        return .onBreak(resumesAt: resume)
    }
}

extension Calendar {
    static var turkish: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "tr_TR")
        calendar.firstWeekday = 2
        return calendar
    }
}
