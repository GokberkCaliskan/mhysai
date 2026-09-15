import Foundation

/// Bir tutarın "neye denk geldiği": mesai süresi, maaş, kira, dürüm…
struct Equivalent: Identifiable {
    let id: String
    let emoji: String
    let value: String
    let label: String
}

extension AppModel {
    func equivalents(for item: BudgetItem, at date: Date = AppClock.now) -> [Equivalent] {
        guard let engine, item.amount > 0 else { return [] }
        let amount = item.amount
        var result: [Equivalent] = []

        result.append(Equivalent(
            id: "work",
            emoji: "⏱️",
            value: Format.workTime(engine.workDuration(for: amount, at: date), dailyPaidMinutes: engine.profile.schedule.dailyPaidMinutes),
            label: "mesai"
        ))

        let daily = dailyEarnings(at: date)
        if daily > 0 {
            result.append(Equivalent(id: "daily", emoji: "📅", value: Format.number(amount / daily), label: "günlük kazanç"))
        }

        let monthly = engine.netSalary(forMonthOf: date)
        if monthly > 0 {
            result.append(Equivalent(id: "monthly", emoji: "💰", value: Format.number(amount / monthly, fractionDigits: 2), label: "aylık maaş"))
        }

        for expense in items(of: .expense) where expense.id != item.id && expense.amount > 0 {
            result.append(Equivalent(
                id: "expense-\(expense.id)",
                emoji: expense.emoji,
                value: Format.number(amount / expense.amount),
                label: expense.name.lowercased(with: Format.locale)
            ))
        }

        for comparison in PriceComparison.all where ["doner", "tea"].contains(comparison.id) {
            result.append(Equivalent(
                id: comparison.id,
                emoji: comparison.emoji,
                value: Format.number(amount / comparison.price, fractionDigits: 0),
                label: comparison.unit
            ))
        }
        return result
    }

    /// Listede gösterilecek kısa özet: "0,65 maaş · 3,4 kira"
    func shortEquivalent(for item: BudgetItem) -> String? {
        let monthly = engine?.netSalary(forMonthOf: AppClock.now) ?? 0
        guard item.amount > 0, monthly > 0 else { return nil }
        var parts = ["\(Format.number(item.amount / monthly, fractionDigits: 2)) maaş"]
        if let firstExpense = items(of: .expense).first(where: { $0.amount > 0 }) {
            parts.append("\(Format.number(item.amount / firstExpense.amount)) \(firstExpense.name.lowercased(with: Format.locale))")
        }
        return parts.joined(separator: " · ")
    }
}
