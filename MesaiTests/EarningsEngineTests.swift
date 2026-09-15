import XCTest
@testable import Mesai

final class EarningsEngineTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        calendar = .turkish
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private func engine(
        amount: Double = 60_000,
        period: PayPeriod = .monthly,
        lunch: Bool = false,
        holidays: Bool = true
    ) -> EarningsEngine {
        var schedule = WorkSchedule.standard
        schedule.startMinute = 9 * 60
        schedule.endMinute = 17 * 60
        schedule.hasLunchBreak = lunch
        schedule.lunchStartMinute = 12 * 60
        schedule.lunchDurationMinutes = 60
        schedule.observesPublicHolidays = holidays
        return EarningsEngine(profile: SalaryProfile(amount: amount, period: period, schedule: schedule), calendar: calendar)
    }

    func testFullMonthAddsUpToMonthlySalary() {
        let e = engine()
        let total = e.earnings(from: date(2026, 9, 1), to: date(2026, 10, 1))
        XCTAssertEqual(total, 60_000, accuracy: 0.001)
    }

    func testDailyRateDependsOnWorkdaysInMonth() {
        let e = engine(holidays: false)
        // Eylül 2026: 22 iş günü
        XCTAssertEqual(e.workdayCount(inMonthOf: date(2026, 9, 10)), 22)
        XCTAssertEqual(e.expectedToday(at: date(2026, 9, 14, 8)), 60_000 / 22, accuracy: 0.001)
    }

    func testCounterRunsOnlyDuringWorkHours() {
        let e = engine(holidays: false)
        let dayTotal = 60_000.0 / 22
        XCTAssertEqual(e.earnedToday(at: date(2026, 9, 14, 8, 59)), 0)
        XCTAssertEqual(e.earnedToday(at: date(2026, 9, 14, 13)), dayTotal / 2, accuracy: 0.001)
        XCTAssertEqual(e.earnedToday(at: date(2026, 9, 14, 23)), dayTotal, accuracy: 0.001)
        // Cumartesi
        XCTAssertEqual(e.earnedToday(at: date(2026, 9, 19, 12)), 0)
    }

    func testLunchBreakIsUnpaid() {
        let e = engine(lunch: true, holidays: false)
        let at12 = e.earnedToday(at: date(2026, 9, 14, 12))
        let at13 = e.earnedToday(at: date(2026, 9, 14, 13))
        XCTAssertEqual(at12, at13, accuracy: 0.0001)
        XCTAssertEqual(e.status(at: date(2026, 9, 14, 12, 30)), .onBreak(resumesAt: date(2026, 9, 14, 13)))
    }

    func testYearlySalaryIsSplitMonthly() {
        let e = engine(amount: 720_000, period: .yearly)
        XCTAssertEqual(e.earnings(from: date(2026, 3, 1), to: date(2026, 4, 1)), 60_000, accuracy: 0.001)
    }

    func testPublicHolidaysStopTheCounter() {
        let e = engine()
        // 29 Ekim 2026 Perşembe
        XCTAssertTrue(e.paidIntervals(on: date(2026, 10, 29)).isEmpty)
        // 28 Ekim arifesi: 09:00–13:00
        let arife = e.paidIntervals(on: date(2026, 10, 28))
        XCTAssertEqual(arife.last?.end, date(2026, 10, 28, 13))
        if case .dayOff(let reason, _) = e.status(at: date(2026, 10, 29, 10)) {
            XCTAssertEqual(reason, "Cumhuriyet Bayramı")
        } else {
            XCTFail("Bayramda mesai olmamalı")
        }
    }

    func testReligiousHolidaysMatchDiyanet() {
        XCTAssertEqual(TurkishHolidays.holiday(on: date(2026, 3, 19), calendar: calendar)?.kind, .afternoon)
        XCTAssertEqual(TurkishHolidays.holiday(on: date(2026, 3, 20), calendar: calendar)?.name, "Ramazan Bayramı")
        XCTAssertEqual(TurkishHolidays.holiday(on: date(2026, 3, 22), calendar: calendar)?.name, "Ramazan Bayramı")
        XCTAssertNil(TurkishHolidays.holiday(on: date(2026, 3, 23), calendar: calendar))
        XCTAssertEqual(TurkishHolidays.holiday(on: date(2026, 5, 26), calendar: calendar)?.kind, .afternoon)
        XCTAssertEqual(TurkishHolidays.holiday(on: date(2026, 5, 30), calendar: calendar)?.name, "Kurban Bayramı")
        XCTAssertEqual(TurkishHolidays.holiday(on: date(2025, 3, 30), calendar: calendar)?.name, "Ramazan Bayramı")
        XCTAssertEqual(TurkishHolidays.holiday(on: date(2025, 6, 6), calendar: calendar)?.name, "Kurban Bayramı")
    }

    func testHolidayMonthStillPaysFullSalary() {
        let e = engine()
        XCTAssertEqual(e.earnings(from: date(2026, 5, 1), to: date(2026, 6, 1)), 60_000, accuracy: 0.001)
    }

    func testEarningsAcrossMonthBoundary() {
        let e = engine(holidays: false)
        // 30 Eylül Çarşamba tam gün + 1 Ekim Perşembe tam gün
        let expected = 60_000.0 / 22 + 60_000.0 / Double(e.workdayCount(inMonthOf: date(2026, 10, 1)))
        XCTAssertEqual(e.earnings(from: date(2026, 9, 30), to: date(2026, 10, 2)), expected, accuracy: 0.001)
    }

    func testStatusTransitions() {
        let e = engine(holidays: false)
        XCTAssertEqual(e.status(at: date(2026, 9, 14, 8)), .beforeWork(startsAt: date(2026, 9, 14, 9)))
        XCTAssertEqual(e.status(at: date(2026, 9, 14, 10)), .working(endsAt: date(2026, 9, 14, 17)))
        XCTAssertEqual(e.status(at: date(2026, 9, 18, 18)), .afterWork(nextStart: date(2026, 9, 21, 9)))
        XCTAssertEqual(e.status(at: date(2026, 9, 19, 12)), .dayOff(reason: "Hafta sonu", nextStart: date(2026, 9, 21, 9)))
    }

    func testActivityMinutes() {
        let suite = "EarningsEngineTests.activity"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let model = AppModel(defaults: defaults, calendar: calendar)
        let toilet = ActivityKind.find("toilet")
        let day = date(2026, 9, 14, 10)

        model.adjust(toilet, by: 5, on: day)
        model.adjust(toilet, by: 5, on: day)
        XCTAssertEqual(model.minutes(for: toilet, on: day), 10)
        model.adjust(toilet, by: -15, on: day)
        XCTAssertEqual(model.minutes(for: toilet, on: day), 0)

        model.adjust(toilet, by: 30, on: day)
        XCTAssertEqual(model.minutes(for: toilet, on: date(2026, 9, 15, 10)), 0)
        XCTAssertEqual(AppModel(defaults: defaults, calendar: calendar).minutes(for: toilet, on: day), 30)
    }

    func testActivityEarningsUseMonthlyRate() {
        let suite = "EarningsEngineTests.earnings"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let model = AppModel(defaults: defaults, calendar: calendar)
        var schedule = WorkSchedule.standard
        schedule.observesPublicHolidays = false
        model.saveProfile(SalaryProfile(amount: 130_000, period: .monthly, schedule: schedule))

        let day = date(2026, 9, 15)
        XCTAssertEqual(model.dailyEarnings(at: day), 130_000.0 / 22, accuracy: 0.001)
        // 8 saatlik günün 30 dakikası
        XCTAssertEqual(model.earnings(forMinutes: 30, on: day), 130_000.0 / 22 / 16, accuracy: 0.001)
    }

    func testWorkDurationAndFreedomDate() {
        let e = engine(holidays: false)
        // Eylül 2026: 22 gün × 8 saat; günlük 2.727,27 ₺
        let daily = 60_000.0 / 22
        XCTAssertEqual(e.workDuration(for: daily, at: date(2026, 9, 15)), 8 * 3600, accuracy: 0.01)
        XCTAssertEqual(Format.workTime(e.workDuration(for: daily * 2.5, at: date(2026, 9, 15)), dailyPaidMinutes: 480), "2 iş günü 4 sa")
        XCTAssertEqual(Format.workTime(e.workDuration(for: daily / 16, at: date(2026, 9, 15)), dailyPaidMinutes: 480), "30 dk")

        // 3 günlük gider: 1, 2, 3 Eylül (Sal–Çar–Per) çalışılır, 3 Eylül 17:00'de biter
        XCTAssertEqual(e.dateWhenEarned(daily * 3, inMonthOf: date(2026, 9, 15)), date(2026, 9, 3, 17))
        XCTAssertNil(e.dateWhenEarned(70_000, inMonthOf: date(2026, 9, 15)))
    }

    func testEquivalents() {
        let suite = "EarningsEngineTests.equivalents"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let model = AppModel(defaults: defaults, calendar: calendar)
        var schedule = WorkSchedule.standard
        schedule.observesPublicHolidays = false
        model.saveProfile(SalaryProfile(amount: 100_000, period: .monthly, schedule: schedule))
        model.upsert(BudgetItem(kind: .expense, emoji: "🏠", name: "Kira", amount: 25_000))
        let phone = BudgetItem(kind: .wish, emoji: "📱", name: "iPhone 18", amount: 150_000)

        let values = Dictionary(uniqueKeysWithValues: model.equivalents(for: phone, at: date(2026, 9, 15)).map { ($0.label, $0.value) })
        XCTAssertEqual(values["aylık maaş"], "1,5")
        XCTAssertEqual(values["kira"], "6")
        XCTAssertEqual(values["günlük kazanç"], "33")
        XCTAssertEqual(model.shortEquivalent(for: phone), "1,5 maaş · 6 kira")
    }

    func testGrossToNetPayroll2026() {
        let months = TurkishPayroll.months(monthlyGross: 100_000, parameters: .y2026)
        XCTAssertEqual(months.count, 12)
        let january = months[0]
        // SGK 14.000 + işsizlik 1.000; matrah 85.000 → GV 12.750 − istisna 4.211,33; damga (100.000 − 33.030) × 0,00759
        XCTAssertEqual(january.sgk + january.unemployment, 15_000, accuracy: 0.01)
        XCTAssertEqual(january.incomeTax, 12_750 - 28_075.5 * 0.15, accuracy: 0.01)
        XCTAssertEqual(january.stampTax, 66_970 * 0.00759, accuracy: 0.01)
        XCTAssertEqual(january.net, 75_953.02, accuracy: 0.05)

        // Kümülatif matrah 190.000'i Mart'ta aşar → net düşer, Aralık en düşük
        XCTAssertEqual(months[2].bracketRate, 0.20)
        XCTAssertLessThan(months[2].net, months[1].net)
        XCTAssertLessThan(months[11].net, months[0].net)
        XCTAssertEqual(months[11].bracketRate, 0.27)
    }

    func testMinimumWageGrossHasNoTax() {
        let months = TurkishPayroll.months(monthlyGross: 33_030, parameters: .y2026)
        for month in months {
            XCTAssertEqual(month.incomeTax, 0, accuracy: 0.01)
            XCTAssertEqual(month.stampTax, 0, accuracy: 0.01)
            XCTAssertEqual(month.net, 28_075.5, accuracy: 0.01)
        }
    }

    func testSGKCeilingCapsPremiums() {
        let january = TurkishPayroll.months(monthlyGross: 400_000, parameters: .y2026)[0]
        XCTAssertEqual(january.sgk, 297_270 * 0.14, accuracy: 0.01)
    }

    func testGrossProfileDrivesEngine() {
        var schedule = WorkSchedule.standard
        schedule.startMinute = 9 * 60
        schedule.endMinute = 17 * 60
        schedule.hasLunchBreak = false
        schedule.observesPublicHolidays = false
        let profile = SalaryProfile(amount: 100_000, period: .monthly, amountType: .gross, schedule: schedule)
        let e = EarningsEngine(profile: profile, calendar: calendar)

        let septemberNet = profile.netSalary(month: 9, year: 2026)
        XCTAssertLessThan(septemberNet, profile.netSalary(month: 1, year: 2026))
        XCTAssertEqual(e.earnings(from: date(2026, 9, 1), to: date(2026, 10, 1)), septemberNet, accuracy: 0.01)

        let yearTotal = (1...8).reduce(0) { $0 + profile.netSalary(month: $1, year: 2026) }
        XCTAssertEqual(e.earnedThisYear(at: date(2026, 9, 1)), yearTotal, accuracy: 0.01)
    }

    func testOldProfilesDecodeAsNet() throws {
        let json = #"{"amount":60000,"period":"monthly","schedule":{"workdays":[2],"startMinute":540,"endMinute":1080,"hasLunchBreak":false,"lunchStartMinute":750,"lunchDurationMinutes":60,"observesPublicHolidays":true}}"#
        let profile = try JSONDecoder().decode(SalaryProfile.self, from: Data(json.utf8))
        XCTAssertEqual(profile.amountType, .net)
    }

    func testPastActivityEarningsSurviveSalaryChange() {
        let suite = "EarningsEngineTests.snapshot"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let model = AppModel(defaults: defaults, calendar: calendar)
        var schedule = WorkSchedule.standard
        schedule.observesPublicHolidays = false
        model.saveProfile(SalaryProfile(amount: 60_000, period: .monthly, schedule: schedule))

        // 90 günlük saklama süresinin içinde kalan geçmiş bir gün
        let pastDay = calendar.date(byAdding: .day, value: -3, to: AppClock.now)!
        let toilet = ActivityKind.find("toilet")
        model.adjust(toilet, by: 30, on: pastDay)
        let before = model.earnings(forMinutes: 30, on: pastDay)

        model.saveProfile(SalaryProfile(amount: 120_000, period: .monthly, schedule: schedule))
        XCTAssertEqual(model.earnings(forMinutes: 30, on: pastDay), before, accuracy: 0.001)
        XCTAssertEqual(AppModel(defaults: defaults, calendar: calendar).earnings(forMinutes: 30, on: pastDay), before, accuracy: 0.001)
    }
}
