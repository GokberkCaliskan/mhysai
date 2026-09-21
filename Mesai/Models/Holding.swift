import Foundation

/// Kullanıcının elindeki yatırım: gram altın, döviz ya da ABD hissesi.
struct Holding: Codable, Identifiable, Equatable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case gold
        case usd
        case eur
        case stock

        var id: String { rawValue }

        var title: String {
            switch self {
            case .gold: "Gram altın"
            case .usd: "Dolar"
            case .eur: "Euro"
            case .stock: "Hisse / Fon"
            }
        }

        var emoji: String {
            switch self {
            case .gold: "🪙"
            case .usd: "💵"
            case .eur: "💶"
            case .stock: "📈"
            }
        }

        var unit: String {
            switch self {
            case .gold: "gram"
            case .usd: "$"
            case .eur: "€"
            case .stock: "adet"
            }
        }

        /// Fiyatı çekilecek semboller.
        var quoteSymbol: String? {
            switch self {
            case .gold: QuoteSymbol.goldOunce
            case .usd: QuoteSymbol.usdTry
            case .eur: QuoteSymbol.eurTry
            case .stock: nil
            }
        }
    }

    var id = UUID()
    var kind: Kind
    /// Yalnızca hisse için: AAPL, THYAO.IS…
    var symbol: String = ""
    /// Aramadan gelen okunur ad: "NVIDIA Corporation"
    var title: String = ""
    var quantity: Double = 0

    var quoteSymbol: String {
        kind.quoteSymbol ?? symbol.uppercased()
    }

    var name: String {
        guard kind == .stock else { return kind.title }
        return title.isEmpty ? symbol.uppercased() : title
    }

    var isValid: Bool {
        quantity > 0 && (kind != .stock || !symbol.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    static let popularStocks: [SymbolResult] = [
        SymbolResult(symbol: "AAPL", name: "Apple", exchange: "NASDAQ"),
        SymbolResult(symbol: "NVDA", name: "NVIDIA", exchange: "NASDAQ"),
        SymbolResult(symbol: "TSLA", name: "Tesla", exchange: "NASDAQ"),
        SymbolResult(symbol: "MSFT", name: "Microsoft", exchange: "NASDAQ"),
        SymbolResult(symbol: "SPY", name: "S&P 500 ETF", exchange: "NYSE"),
        SymbolResult(symbol: "THYAO.IS", name: "Türk Hava Yolları", exchange: "BIST"),
        SymbolResult(symbol: "ASELS.IS", name: "Aselsan", exchange: "BIST"),
        SymbolResult(symbol: "BTC-USD", name: "Bitcoin", exchange: "Kripto"),
    ]
}

enum QuoteSymbol {
    static let goldOunce = "GC=F"
    static let usdTry = "USDTRY=X"
    static let eurTry = "EURTRY=X"
    /// 1 troy ons = 31,1034768 gram
    static let gramsPerOunce = 31.1034768
}

/// Bir sembolün son bilinen fiyatı.
struct Quote: Codable, Equatable {
    let symbol: String
    let price: Double
    let currency: String
    let time: Date
}

enum QuoteFailure: String, Codable, Equatable, Error {
    case rateLimited
    case offline
    case failed

    var message: String {
        switch self {
        case .rateLimited: "Günlük ücretsiz fiyat sorgusu hakkı doldu. Son bilinen fiyatlar gösteriliyor."
        case .offline: "İnternet yok. Son bilinen fiyatlar gösteriliyor."
        case .failed: "Fiyatlar şu an alınamadı. Son bilinen fiyatlar gösteriliyor."
        }
    }
}

/// Varlıkların güncel fiyatlarla TL karşılığını hesaplar.
enum PortfolioValuation {
    /// Bir varlığın TL değeri; gerekli kur yoksa `nil`.
    static func value(of holding: Holding, quotes: [String: Quote]) -> Double? {
        guard let quote = quotes[holding.quoteSymbol] else { return nil }
        switch holding.kind {
        case .usd, .eur:
            return holding.quantity * quote.price
        case .gold:
            guard let usdTry = quotes[QuoteSymbol.usdTry] else { return nil }
            return holding.quantity * (quote.price / QuoteSymbol.gramsPerOunce) * usdTry.price
        case .stock:
            if quote.currency.uppercased() == "TRY" { return holding.quantity * quote.price }
            guard let usdTry = quotes[QuoteSymbol.usdTry] else { return nil }
            return holding.quantity * quote.price * usdTry.price
        }
    }

    /// Birim fiyatın TL karşılığı (listede "gram başına" göstermek için).
    static func unitPrice(of holding: Holding, quotes: [String: Quote]) -> Double? {
        guard holding.quantity != 0 else { return nil }
        return value(of: holding, quotes: quotes).map { $0 / holding.quantity }
    }

    static func total(of holdings: [Holding], quotes: [String: Quote]) -> Double {
        holdings.reduce(0) { $0 + (value(of: $1, quotes: quotes) ?? 0) }
    }

    /// Fiyatı çekilmesi gereken semboller (kur dönüşümü için USDTRY her zaman gerekir).
    static func requiredSymbols(for holdings: [Holding]) -> [String] {
        var symbols = Set(holdings.map(\.quoteSymbol))
        if !holdings.isEmpty { symbols.insert(QuoteSymbol.usdTry) }
        return symbols.sorted()
    }
}
