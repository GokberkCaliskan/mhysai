#if DEBUG
import Foundation

/// `-demoData YES` ile açıldığında ekran görüntüleri için örnek veri yükler.
enum DemoData {
    static var isRequested: Bool { UserDefaults.standard.bool(forKey: "demoData") }
    static var revealsAmounts: Bool { UserDefaults.standard.bool(forKey: "demoReveal") }

    static func seedIfRequested() {
        guard isRequested else { return }
        let defaults = UserDefaults.standard
        let calendar = Calendar.turkish
        let now = AppClock.now
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        let dayKey = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)

        let profile = SalaryProfile(amount: 85_000, period: .monthly, amountType: .net, schedule: .standard)
        let items = [
            BudgetItem(kind: .expense, emoji: "🏠", name: "Kira", amount: 25_000),
            BudgetItem(kind: .expense, emoji: "🧾", name: "Faturalar", amount: 4_500),
            BudgetItem(kind: .expense, emoji: "🛒", name: "Market", amount: 9_000),
            BudgetItem(kind: .wish, emoji: "📱", name: "iPhone 18 Pro", amount: 110_000),
            BudgetItem(kind: .wish, emoji: "✈️", name: "Kapadokya tatili", amount: 32_000),
            BudgetItem(kind: .wish, emoji: "🎮", name: "PlayStation 5", amount: 28_000),
        ]
        let minutes: [String: [String: Int]] = [dayKey: ["toilet": 25, "tea": 40, "social": 35, "meeting": 60]]

        let encoder = JSONEncoder()
        defaults.set(try? encoder.encode(profile), forKey: "salaryProfile")
        defaults.set(try? encoder.encode(items), forKey: "budgetItems")
        defaults.set(try? encoder.encode(minutes), forKey: "activityMinutes")
        defaults.removeObject(forKey: "activityRates")
    }
}
#endif
