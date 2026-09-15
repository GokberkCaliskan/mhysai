import Foundation

/// Kullanıcının isteğe bağlı girdiği sabit giderler ve almak istediği şeyler.
struct BudgetItem: Codable, Identifiable, Equatable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case expense
        case wish

        var id: String { rawValue }

        var title: String {
            switch self {
            case .expense: "Aylık gider"
            case .wish: "İstek"
            }
        }
    }

    var id = UUID()
    var kind: Kind
    var emoji: String
    var name: String
    var amount: Double

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && amount > 0
    }

    struct Suggestion: Identifiable {
        let emoji: String
        let name: String
        var id: String { name }
    }

    static let expenseSuggestions = [
        Suggestion(emoji: "🏠", name: "Kira"),
        Suggestion(emoji: "🧾", name: "Faturalar"),
        Suggestion(emoji: "🛒", name: "Market"),
        Suggestion(emoji: "💳", name: "Kredi kartı"),
        Suggestion(emoji: "🚗", name: "Araba taksiti"),
    ]

    static let wishSuggestions = [
        Suggestion(emoji: "📱", name: "Yeni telefon"),
        Suggestion(emoji: "✈️", name: "Tatil"),
        Suggestion(emoji: "🎮", name: "PlayStation"),
        Suggestion(emoji: "👟", name: "Spor ayakkabı"),
        Suggestion(emoji: "💻", name: "Laptop"),
    ]

    static let emojiChoices = ["🏠", "🧾", "🛒", "💳", "🚗", "📱", "✈️", "🎮", "👟", "💻", "🎁", "💍", "🐶", "🎓", "💊", "⭐️"]
}
