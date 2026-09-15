import Foundation

/// Mesai sırasında yapılan "kaytarma" türleri.
struct ActivityKind: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    /// Paylaşım kartında kullanılan ifade: "tuvalette", "çay içerek" …
    let phrase: String

    static let all: [ActivityKind] = [
        ActivityKind(id: "toilet", name: "Tuvalet", emoji: "🚽", phrase: "tuvalette"),
        ActivityKind(id: "tea", name: "Çay / Kahve", emoji: "☕️", phrase: "çay içerek"),
        ActivityKind(id: "smoke", name: "Sigara", emoji: "🚬", phrase: "sigara molasında"),
        ActivityKind(id: "social", name: "Sosyal Medya", emoji: "📱", phrase: "telefonda gezinerek"),
        ActivityKind(id: "meeting", name: "Boş Toplantı", emoji: "🧑‍💼", phrase: "boş toplantıda"),
        ActivityKind(id: "tv", name: "Dizi / Maç", emoji: "📺", phrase: "dizi izleyerek"),
        ActivityKind(id: "gossip", name: "Dedikodu", emoji: "🗣️", phrase: "dedikodu yaparak"),
        ActivityKind(id: "shopping", name: "Online Alışveriş", emoji: "🛒", phrase: "alışveriş sitelerinde"),
    ]

    static func find(_ id: String) -> ActivityKind {
        all.first { $0.id == id } ?? ActivityKind(id: id, name: "Diğer", emoji: "⏱️", phrase: "kaytararak")
    }

    static let stepMinutes = 5
    static let maxMinutes = 12 * 60
}

/// Kazancı somut şeylere çevirmek için yaklaşık fiyatlar (₺).
struct PriceComparison: Identifiable {
    let id: String
    let emoji: String
    let unit: String
    let price: Double

    static let all: [PriceComparison] = [
        PriceComparison(id: "tea", emoji: "🍵", unit: "çay", price: 20),
        PriceComparison(id: "simit", emoji: "🥯", unit: "simit", price: 25),
        PriceComparison(id: "coffee", emoji: "☕️", unit: "latte", price: 190),
        PriceComparison(id: "doner", emoji: "🌯", unit: "dürüm", price: 280),
        PriceComparison(id: "fuel", emoji: "⛽️", unit: "litre benzin", price: 58),
    ]
}
