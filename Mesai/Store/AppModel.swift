import Foundation
import Observation

@Observable
final class AppModel {
    private(set) var profile: SalaryProfile?
    private(set) var engine: EarningsEngine?
    /// Gün anahtarı ("2026-09-15") → kaytarma türü → dakika
    private(set) var activityMinutes: [String: [String: Int]]
    private(set) var budgetItems: [BudgetItem]
    /// Her açılışta gizli başlar; göz butonuyla açılır.
    var amountsHidden = true

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar

    private enum Key {
        static let profile = "salaryProfile"
        static let activityMinutes = "activityMinutes"
        static let budgetItems = "budgetItems"
    }

    init(defaults: UserDefaults = .standard, calendar: Calendar = .turkish) {
        self.defaults = defaults
        self.calendar = calendar
        profile = Self.load(SalaryProfile.self, key: Key.profile, from: defaults)
        activityMinutes = Self.load([String: [String: Int]].self, key: Key.activityMinutes, from: defaults) ?? [:]
        budgetItems = Self.load([BudgetItem].self, key: Key.budgetItems, from: defaults) ?? []
        engine = profile.map { EarningsEngine(profile: $0, calendar: calendar) }
        pruneOldActivities()
    }

    // MARK: - Profil

    func saveProfile(_ profile: SalaryProfile) {
        self.profile = profile
        engine = EarningsEngine(profile: profile, calendar: calendar)
        Self.save(profile, key: Key.profile, to: defaults)
    }

    func resetAll() {
        profile = nil
        engine = nil
        activityMinutes = [:]
        budgetItems = []
        defaults.removeObject(forKey: Key.profile)
        defaults.removeObject(forKey: Key.activityMinutes)
        defaults.removeObject(forKey: Key.budgetItems)
    }

    // MARK: - Günlük ortalama

    /// Bu ayın bir iş gününe düşen maaş.
    func dailyEarnings(at date: Date = .now) -> Double {
        guard let engine else { return 0 }
        let days = engine.workdayCount(inMonthOf: date)
        return days > 0 ? engine.netSalary(forMonthOf: date) / Double(days) : 0
    }

    // MARK: - Kaytarma dakikaları

    func minutes(for kind: ActivityKind, on date: Date = .now) -> Int {
        activityMinutes[dayKey(date)]?[kind.id] ?? 0
    }

    func totalMinutes(on date: Date = .now) -> Int {
        activityMinutes[dayKey(date)]?.values.reduce(0, +) ?? 0
    }

    func adjust(_ kind: ActivityKind, by delta: Int, on date: Date = .now) {
        let key = dayKey(date)
        var day = activityMinutes[key] ?? [:]
        let updated = min(ActivityKind.maxMinutes, max(0, (day[kind.id] ?? 0) + delta))
        day[kind.id] = updated == 0 ? nil : updated
        activityMinutes[key] = day.isEmpty ? nil : day
        Self.save(activityMinutes, key: Key.activityMinutes, to: defaults)
    }

    /// Verilen dakikanın, o ayın mesai oranıyla karşılığı.
    func earnings(forMinutes minutes: Int, on date: Date = .now) -> Double {
        guard let engine else { return 0 }
        return Double(minutes) * 60 * engine.ratePerSecond(forMonthOf: date)
    }

    private func dayKey(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private func pruneOldActivities() {
        guard let cutoff = calendar.date(byAdding: .day, value: -90, to: .now) else { return }
        let cutoffKey = dayKey(cutoff)
        let kept = activityMinutes.filter { $0.key >= cutoffKey }
        if kept.count != activityMinutes.count {
            activityMinutes = kept
            Self.save(activityMinutes, key: Key.activityMinutes, to: defaults)
        }
    }

    // MARK: - Giderler ve istekler

    func items(of kind: BudgetItem.Kind) -> [BudgetItem] {
        budgetItems.filter { $0.kind == kind }
    }

    func upsert(_ item: BudgetItem) {
        if let index = budgetItems.firstIndex(where: { $0.id == item.id }) {
            budgetItems[index] = item
        } else {
            budgetItems.append(item)
        }
        Self.save(budgetItems, key: Key.budgetItems, to: defaults)
    }

    func delete(_ item: BudgetItem) {
        budgetItems.removeAll { $0.id == item.id }
        Self.save(budgetItems, key: Key.budgetItems, to: defaults)
    }

    // MARK: - Kalıcılık

    private static func load<T: Decodable>(_ type: T.Type, key: String, from defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func save<T: Encodable>(_ value: T, key: String, to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
