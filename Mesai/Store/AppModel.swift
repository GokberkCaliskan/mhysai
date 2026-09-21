import Foundation
import Observation

@Observable
@MainActor
final class AppModel {
    private(set) var profile: SalaryProfile?
    private(set) var engine: EarningsEngine?
    /// Gün anahtarı ("2026-09-15") → kaytarma türü → dakika
    private(set) var activityMinutes: [String: [String: Int]]
    private(set) var budgetItems: [BudgetItem]
    private(set) var holdings: [Holding]
    private(set) var quotes: [String: Quote]
    private(set) var quotesUpdatedAt: Date?
    private(set) var quoteFailure: QuoteFailure?
    private(set) var isRefreshingQuotes = false
    private(set) var notificationPreferences: NotificationPreferences
    /// Gün anahtarı → o gün geçerli dakikalık kazanç; maaş değişince geçmiş günler bozulmasın diye.
    private var activityRates: [String: Double]
    /// Her açılışta gizli başlar; göz butonuyla açılır.
    var amountsHidden = true

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored var quoteService = QuoteService()

    private enum Key {
        static let profile = "salaryProfile"
        static let activityMinutes = "activityMinutes"
        static let budgetItems = "budgetItems"
        static let activityRates = "activityRates"
        static let holdings = "holdings"
        static let quotes = "quotes"
        static let quotesUpdatedAt = "quotesUpdatedAt"
        static let notificationPreferences = "notificationPreferences"
        static let activeDays = "activeDays"
        static let reviewRequestedVersion = "reviewRequestedVersion"
    }

    init(defaults: UserDefaults = .standard, calendar: Calendar = .turkish) {
        self.defaults = defaults
        self.calendar = calendar
        profile = Self.load(SalaryProfile.self, key: Key.profile, from: defaults)
        activityMinutes = Self.load([String: [String: Int]].self, key: Key.activityMinutes, from: defaults) ?? [:]
        budgetItems = Self.load([BudgetItem].self, key: Key.budgetItems, from: defaults) ?? []
        activityRates = Self.load([String: Double].self, key: Key.activityRates, from: defaults) ?? [:]
        holdings = Self.load([Holding].self, key: Key.holdings, from: defaults) ?? []
        quotes = Self.load([String: Quote].self, key: Key.quotes, from: defaults) ?? [:]
        quotesUpdatedAt = Self.load(Date.self, key: Key.quotesUpdatedAt, from: defaults)
        notificationPreferences = Self.load(NotificationPreferences.self, key: Key.notificationPreferences, from: defaults) ?? NotificationPreferences()
        engine = profile.map { EarningsEngine(profile: $0, calendar: calendar) }
        pruneOldActivities()
    }

    // MARK: - Profil

    func saveProfile(_ profile: SalaryProfile) {
        self.profile = profile
        engine = EarningsEngine(profile: profile, calendar: calendar)
        Self.save(profile, key: Key.profile, to: defaults)
        Task { await rescheduleNotifications() }
    }

    func resetAll() {
        profile = nil
        engine = nil
        activityMinutes = [:]
        activityRates = [:]
        budgetItems = []
        holdings = []
        quotes = [:]
        quotesUpdatedAt = nil
        notificationPreferences = NotificationPreferences()
        defaults.removeObject(forKey: Key.holdings)
        defaults.removeObject(forKey: Key.quotes)
        defaults.removeObject(forKey: Key.quotesUpdatedAt)
        defaults.removeObject(forKey: Key.notificationPreferences)
        defaults.removeObject(forKey: Key.activityRates)
        defaults.removeObject(forKey: Key.profile)
        defaults.removeObject(forKey: Key.activityMinutes)
        defaults.removeObject(forKey: Key.budgetItems)
    }

    // MARK: - Günlük ortalama

    /// Bu ayın bir iş gününe düşen maaş.
    func dailyEarnings(at date: Date = AppClock.now) -> Double {
        guard let engine else { return 0 }
        let days = engine.workdayCount(inMonthOf: date)
        return days > 0 ? engine.netSalary(forMonthOf: date) / Double(days) : 0
    }

    // MARK: - Kaytarma dakikaları

    func minutes(for kind: ActivityKind, on date: Date = AppClock.now) -> Int {
        activityMinutes[dayKey(date)]?[kind.id] ?? 0
    }

    func totalMinutes(on date: Date = AppClock.now) -> Int {
        activityMinutes[dayKey(date)]?.values.reduce(0, +) ?? 0
    }

    func adjust(_ kind: ActivityKind, by delta: Int, on date: Date = AppClock.now) {
        let key = dayKey(date)
        var day = activityMinutes[key] ?? [:]
        let updated = min(ActivityKind.maxMinutes, max(0, (day[kind.id] ?? 0) + delta))
        day[kind.id] = updated == 0 ? nil : updated
        activityMinutes[key] = day.isEmpty ? nil : day
        activityRates[key] = liveRatePerMinute(on: date)
        Self.save(activityMinutes, key: Key.activityMinutes, to: defaults)
        Self.save(activityRates, key: Key.activityRates, to: defaults)
    }

    /// Verilen dakikanın, o ayın mesai oranıyla karşılığı.
    func earnings(forMinutes minutes: Int, on date: Date = AppClock.now) -> Double {
        let key = dayKey(date)
        if key != dayKey(AppClock.now), let snapshot = activityRates[key] {
            return Double(minutes) * snapshot
        }
        return Double(minutes) * liveRatePerMinute(on: date)
    }

    private func liveRatePerMinute(on date: Date) -> Double {
        (engine?.ratePerSecond(forMonthOf: date) ?? 0) * 60
    }

    private func dayKey(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private func pruneOldActivities() {
        guard let cutoff = calendar.date(byAdding: .day, value: -90, to: AppClock.now) else { return }
        let cutoffKey = dayKey(cutoff)
        let kept = activityMinutes.filter { $0.key >= cutoffKey }
        if kept.count != activityMinutes.count {
            activityMinutes = kept
            activityRates = activityRates.filter { $0.key >= cutoffKey }
            Self.save(activityMinutes, key: Key.activityMinutes, to: defaults)
            Self.save(activityRates, key: Key.activityRates, to: defaults)
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

    // MARK: - Varlıklar

    var portfolioValue: Double {
        PortfolioValuation.total(of: holdings, quotes: quotes)
    }

    func upsert(_ holding: Holding) {
        if let index = holdings.firstIndex(where: { $0.id == holding.id }) {
            holdings[index] = holding
        } else {
            holdings.append(holding)
        }
        Self.save(holdings, key: Key.holdings, to: defaults)
    }

    func delete(_ holding: Holding) {
        holdings.removeAll { $0.id == holding.id }
        Self.save(holdings, key: Key.holdings, to: defaults)
    }

    /// Eksik ya da 15 dakikadan eski fiyatları yeniler.
    func refreshQuotesIfNeeded(force: Bool = false) async {
        let symbols = PortfolioValuation.requiredSymbols(for: holdings)
        guard !symbols.isEmpty, !isRefreshingQuotes else { return }
        if !force, let updated = quotesUpdatedAt, AppClock.now.timeIntervalSince(updated) < 15 * 60,
           symbols.allSatisfy({ quotes[$0] != nil }) { return }

        isRefreshingQuotes = true
        let result = await quoteService.fetch(symbols: symbols)
        isRefreshingQuotes = false

        quoteFailure = result.failure
        guard !result.quotes.isEmpty else { return }
        quotes.merge(result.quotes) { _, new in new }
        quotesUpdatedAt = AppClock.now
        Self.save(quotes, key: Key.quotes, to: defaults)
        Self.save(quotesUpdatedAt, key: Key.quotesUpdatedAt, to: defaults)
    }

    // MARK: - Bildirimler

    func setNotificationPreferences(_ preferences: NotificationPreferences) {
        notificationPreferences = preferences
        Self.save(preferences, key: Key.notificationPreferences, to: defaults)
        Task { await rescheduleNotifications() }
    }

    func rescheduleNotifications() async {
        await NotificationScheduler.reschedule(engine: engine, preferences: notificationPreferences)
    }

    // MARK: - Değerlendirme isteği

    /// Uygulamanın açıldığı günü kaydeder; en az 3 farklı günde kullanılınca bir kez puan istenir.
    func registerActiveDay() -> Bool {
        guard profile != nil else { return false }
        var days = Set(defaults.stringArray(forKey: Key.activeDays) ?? [])
        days.insert(dayKey(AppClock.now))
        defaults.set(Array(days.sorted().suffix(30)), forKey: Key.activeDays)

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        guard days.count >= 3, defaults.string(forKey: Key.reviewRequestedVersion) != version else { return false }
        defaults.set(version, forKey: Key.reviewRequestedVersion)
        return true
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
