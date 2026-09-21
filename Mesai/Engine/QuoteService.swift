import Foundation

/// Fiyatları Yahoo Finance'in herkese açık uç noktasından çeker.
/// Yalnızca sembol adı gönderilir; kullanıcıya ait hiçbir bilgi dışarı çıkmaz.
struct QuoteService {
    var session: URLSession = .shared

    struct Result {
        var quotes: [String: Quote] = [:]
        var failure: QuoteFailure?
    }

    func fetch(symbols: [String]) async -> Result {
        guard !symbols.isEmpty else { return Result() }

        var result = Result()
        await withTaskGroup(of: (String, Swift.Result<Quote, QuoteFailure>).self) { group in
            for symbol in symbols {
                group.addTask {
                    do {
                        return (symbol, .success(try await fetchOne(symbol)))
                    } catch let failure as QuoteFailure {
                        return (symbol, .failure(failure))
                    } catch {
                        return (symbol, .failure(.failed))
                    }
                }
            }
            for await (symbol, outcome) in group {
                switch outcome {
                case .success(let quote): result.quotes[symbol] = quote
                case .failure(let failure):
                    // Hız sınırı en öncelikli mesaj
                    if failure == .rateLimited || result.failure == nil { result.failure = failure }
                    _ = symbol
                }
            }
        }
        return result
    }

    private func fetchOne(_ symbol: String) async throws -> Quote {
        guard let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?interval=1d&range=1d")
        else { throw QuoteFailure.failed }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("Mhysai/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
            throw QuoteFailure.offline
        } catch {
            throw QuoteFailure.failed
        }

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 { throw QuoteFailure.rateLimited }
            guard (200..<300).contains(http.statusCode) else { throw QuoteFailure.failed }
        }
        return try Self.parse(data, symbol: symbol)
    }

    /// Yahoo "chart" yanıtından fiyatı okur.
    static func parse(_ data: Data, symbol: String) throws -> Quote {
        struct Response: Decodable {
            struct Chart: Decodable {
                struct Item: Decodable {
                    struct Meta: Decodable {
                        let regularMarketPrice: Double?
                        let currency: String?
                        let regularMarketTime: Double?
                    }
                    let meta: Meta
                }
                let result: [Item]?
            }
            let chart: Chart
        }

        guard let meta = try? JSONDecoder().decode(Response.self, from: data).chart.result?.first?.meta,
              let price = meta.regularMarketPrice, price > 0
        else { throw QuoteFailure.failed }

        return Quote(
            symbol: symbol,
            price: price,
            currency: meta.currency ?? "USD",
            time: meta.regularMarketTime.map { Date(timeIntervalSince1970: $0) } ?? AppClock.now
        )
    }
}

/// Arama sonucundaki bir sembol.
struct SymbolResult: Identifiable, Equatable, Hashable {
    let symbol: String
    let name: String
    let exchange: String

    var id: String { symbol }
}

/// "nvidia" → NVDA, "aselsan" → ASELS.IS gibi sembol araması.
struct SymbolSearchService {
    var session: URLSession = .shared

    func search(_ query: String) async -> [SymbolResult] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2,
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://query1.finance.yahoo.com/v1/finance/search?q=\(encoded)&quotesCount=12&newsCount=0")
        else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("Mhysai/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        guard let (data, _) = try? await session.data(for: request) else { return [] }
        return Self.parse(data)
    }

    static func parse(_ data: Data) -> [SymbolResult] {
        struct Response: Decodable {
            struct Item: Decodable {
                let symbol: String?
                let shortname: String?
                let longname: String?
                let quoteType: String?
                let exchange: String?
                let exchDisp: String?
            }
            let quotes: [Item]?
        }

        guard let quotes = try? JSONDecoder().decode(Response.self, from: data).quotes else { return [] }
        let allowed: Set<String> = ["EQUITY", "ETF", "MUTUALFUND", "CRYPTOCURRENCY", "CURRENCY", "INDEX"]
        return quotes.compactMap { item in
            guard let symbol = item.symbol, let type = item.quoteType, allowed.contains(type.uppercased()) else { return nil }
            let name = item.longname ?? item.shortname ?? symbol
            let exchange = symbol.hasSuffix(".IS") ? "BIST" : (item.exchDisp ?? item.exchange ?? "")
            return SymbolResult(symbol: symbol, name: name, exchange: exchange)
        }
    }
}
