import XCTest
@testable import Mesai

final class PortfolioAndNotificationTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        calendar = .turkish
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private func quote(_ symbol: String, _ price: Double, _ currency: String = "USD") -> Quote {
        Quote(symbol: symbol, price: price, currency: currency, time: .now)
    }

    private var quotes: [String: Quote] {
        [
            QuoteSymbol.usdTry: quote(QuoteSymbol.usdTry, 48.80, "TRY"),
            QuoteSymbol.eurTry: quote(QuoteSymbol.eurTry, 56.00, "TRY"),
            QuoteSymbol.goldOunce: quote(QuoteSymbol.goldOunce, 4_380.70),
            "AAPL": quote("AAPL", 338.98),
        ]
    }

    // MARK: - Varlık değerleme

    func testGoldValueUsesOunceAndDollarRate() {
        let holding = Holding(kind: .gold, quantity: 3)
        let expected = 3 * (4_380.70 / QuoteSymbol.gramsPerOunce) * 48.80
        XCTAssertEqual(PortfolioValuation.value(of: holding, quotes: quotes)!, expected, accuracy: 0.01)
        // Gram altın 2026'da altı haneli olmamalı; makul aralık kontrolü
        XCTAssertEqual(PortfolioValuation.unitPrice(of: holding, quotes: quotes)!, expected / 3, accuracy: 0.01)
    }

    func testCurrencyAndStockValues() {
        XCTAssertEqual(PortfolioValuation.value(of: Holding(kind: .usd, quantity: 100), quotes: quotes)!, 4_880, accuracy: 0.01)
        XCTAssertEqual(PortfolioValuation.value(of: Holding(kind: .eur, quantity: 50), quotes: quotes)!, 2_800, accuracy: 0.01)
        let apple = Holding(kind: .stock, symbol: "aapl", quantity: 2)
        XCTAssertEqual(PortfolioValuation.value(of: apple, quotes: quotes)!, 2 * 338.98 * 48.80, accuracy: 0.01)
    }

    func testMissingQuoteGivesNil() {
        let unknown = Holding(kind: .stock, symbol: "ZZZZ", quantity: 1)
        XCTAssertNil(PortfolioValuation.value(of: unknown, quotes: quotes))
        XCTAssertEqual(PortfolioValuation.total(of: [unknown, Holding(kind: .usd, quantity: 1)], quotes: quotes), 48.80, accuracy: 0.01)
    }

    func testRequiredSymbolsAlwaysIncludeDollarRate() {
        let symbols = PortfolioValuation.requiredSymbols(for: [Holding(kind: .gold, quantity: 1)])
        XCTAssertEqual(symbols, [QuoteSymbol.goldOunce, QuoteSymbol.usdTry].sorted())
        XCTAssertTrue(PortfolioValuation.requiredSymbols(for: []).isEmpty)
    }

    // MARK: - Fiyat yanıtı

    func testParsesYahooChartResponse() throws {
        let json = #"""
        {"chart":{"result":[{"meta":{"currency":"TRY","symbol":"USDTRY=X","regularMarketPrice":48.7971,"regularMarketTime":1789000000}}],"error":null}}
        """#
        let quote = try QuoteService.parse(Data(json.utf8), symbol: "USDTRY=X")
        XCTAssertEqual(quote.price, 48.7971, accuracy: 0.0001)
        XCTAssertEqual(quote.currency, "TRY")
    }

    func testParseThrowsOnEmptyResult() {
        let json = #"{"chart":{"result":null,"error":{"code":"Not Found"}}}"#
        XCTAssertThrowsError(try QuoteService.parse(Data(json.utf8), symbol: "ZZZZ"))
    }

    // MARK: - Bildirimler

    private func engine() -> EarningsEngine {
        var schedule = WorkSchedule.standard
        schedule.observesPublicHolidays = false
        return EarningsEngine(profile: SalaryProfile(amount: 60_000, period: .monthly, schedule: schedule), calendar: calendar)
    }

    func testNotificationsOnlyOnWorkdaysAndAtRightTimes() {
        var preferences = NotificationPreferences()
        preferences.countdown = true
        preferences.endOfDaySummary = true
        preferences.jokes = true

        // 18 Eylül 2026 Cuma 08:00
        let planned = NotificationScheduler.plannedNotifications(
            engine: engine(),
            preferences: preferences,
            now: date(2026, 9, 18, 8),
            days: 4
        )

        XCTAssertEqual(planned.filter { $0.date == date(2026, 9, 18, 17, 30) }.count, 1) // 30 dk kala
        XCTAssertEqual(planned.filter { $0.date == date(2026, 9, 18, 17, 5) }.count, 1)  // espri
        XCTAssertEqual(planned.filter { $0.date == date(2026, 9, 18, 18) }.count, 1)     // gün sonu
        // 19–20 Eylül hafta sonu: bildirim yok, 21 Eylül Pazartesi var
        XCTAssertTrue(planned.allSatisfy { !calendar.isDate($0.date, inSameDayAs: date(2026, 9, 19)) })
        XCTAssertTrue(planned.contains { calendar.isDate($0.date, inSameDayAs: date(2026, 9, 21)) })
    }

    func testNoNotificationsWhenAllTogglesOff() {
        XCTAssertTrue(NotificationScheduler.plannedNotifications(
            engine: engine(),
            preferences: NotificationPreferences(),
            now: date(2026, 9, 18, 8)
        ).isEmpty)
    }

    func testSummaryTextContainsDailyEarnings() {
        var preferences = NotificationPreferences()
        preferences.endOfDaySummary = true
        let planned = NotificationScheduler.plannedNotifications(
            engine: engine(),
            preferences: preferences,
            now: date(2026, 9, 18, 8),
            days: 1
        )
        let daily = Format.lira(60_000.0 / 22, fractionDigits: 0)
        XCTAssertEqual(planned.count, 1)
        XCTAssertTrue(planned[0].body.contains(daily), planned[0].body)
    }

    func testPastTimesAreNotScheduled() {
        var preferences = NotificationPreferences()
        preferences.countdown = true
        preferences.endOfDaySummary = true
        // Mesai bitmiş: 18 Eylül 19:00
        let planned = NotificationScheduler.plannedNotifications(
            engine: engine(),
            preferences: preferences,
            now: date(2026, 9, 18, 19),
            days: 1
        )
        XCTAssertTrue(planned.isEmpty)
    }
}

extension PortfolioAndNotificationTests {
    /// Çökme tekrarı: varlık kaydedilip fiyatlar UserDefaults'tan geri okunduğunda toplam hesabı.
    @MainActor
    func testPortfolioSurvivesDefaultsRoundTrip() {
        let suite = "PortfolioTests.roundtrip"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let model = AppModel(defaults: defaults, calendar: calendar)
        model.saveProfile(SalaryProfile(amount: 60_000, period: .monthly, schedule: .standard))
        model.upsert(Holding(kind: .gold, quantity: 3))
        model.upsert(Holding(kind: .stock, symbol: "NVDA", title: "NVIDIA", quantity: 2))

        // Fiyatları elle kaydet (ağ olmadan)
        let encoder = JSONEncoder()
        let quotes: [String: Quote] = [
            QuoteSymbol.usdTry: Quote(symbol: QuoteSymbol.usdTry, price: 48.8, currency: "TRY", time: .now),
            QuoteSymbol.goldOunce: Quote(symbol: QuoteSymbol.goldOunce, price: 4_380, currency: "USD", time: .now),
            "NVDA": Quote(symbol: "NVDA", price: 227, currency: "USD", time: .now),
        ]
        defaults.set(try! encoder.encode(quotes), forKey: "quotes")
        defaults.set(try! encoder.encode(Date.now), forKey: "quotesUpdatedAt")

        let reloaded = AppModel(defaults: defaults, calendar: calendar)
        XCTAssertEqual(reloaded.holdings.count, 2)
        let total = reloaded.portfolioValue
        XCTAssertGreaterThan(total, 0)
        XCTAssertEqual(
            total,
            3 * (4_380 / QuoteSymbol.gramsPerOunce) * 48.8 + 2 * 227 * 48.8,
            accuracy: 0.01
        )
    }
}

extension PortfolioAndNotificationTests {
    func testJokeRotatesEveryDayWithoutRepeating() {
        var day = date(2026, 9, 21)
        var seen: [Int] = []
        for _ in 0..<NotificationScheduler.jokes.count {
            seen.append(NotificationScheduler.jokeIndex(for: day, calendar: calendar))
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        // Espri sayısı kadar gün boyunca hiçbiri tekrar etmemeli
        XCTAssertEqual(Set(seen).count, NotificationScheduler.jokes.count)
        // Ertesi gün başa döner
        XCTAssertEqual(NotificationScheduler.jokeIndex(for: day, calendar: calendar), seen[0])
        XCTAssertTrue(NotificationScheduler.jokes.allSatisfy { !$0.isEmpty && $0.count < 180 })
    }
}
