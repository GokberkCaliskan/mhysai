import Foundation

struct Holiday: Equatable {
    enum Kind: Equatable {
        case fullDay
        /// Arife günleri: saat 13:00'ten sonrası tatildir.
        case afternoon
    }

    let name: String
    let kind: Kind

    static let afternoonStartMinute = 13 * 60
}

/// Türkiye'deki resmî tatiller (2429 sayılı Kanun).
/// Dinî bayramlar Umm al-Qura takvimiyle hesaplanır; 2025–2027 Diyanet tarihleriyle birebir örtüşür.
enum TurkishHolidays {
    private static let hijri: Calendar = {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar
    }()

    static func holiday(on date: Date, calendar: Calendar) -> Holiday? {
        fixedHoliday(on: date, calendar: calendar) ?? religiousHoliday(on: date, calendar: calendar)
    }

    private static func fixedHoliday(on date: Date, calendar: Calendar) -> Holiday? {
        let c = calendar.dateComponents([.month, .day], from: date)
        switch (c.month, c.day) {
        case (1, 1): return Holiday(name: "Yılbaşı", kind: .fullDay)
        case (4, 23): return Holiday(name: "Ulusal Egemenlik ve Çocuk Bayramı", kind: .fullDay)
        case (5, 1): return Holiday(name: "Emek ve Dayanışma Günü", kind: .fullDay)
        case (5, 19): return Holiday(name: "Atatürk'ü Anma, Gençlik ve Spor Bayramı", kind: .fullDay)
        case (7, 15): return Holiday(name: "Demokrasi ve Millî Birlik Günü", kind: .fullDay)
        case (8, 30): return Holiday(name: "Zafer Bayramı", kind: .fullDay)
        case (10, 28): return Holiday(name: "Cumhuriyet Bayramı Arifesi", kind: .afternoon)
        case (10, 29): return Holiday(name: "Cumhuriyet Bayramı", kind: .fullDay)
        default: return nil
        }
    }

    private static func religiousHoliday(on date: Date, calendar: Calendar) -> Holiday? {
        // Hicri tarihe gün ortasından bakarak saat dilimi kaymalarını önle.
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
        let today = hijri.dateComponents([.month, .day], from: noon)
        guard let month = today.month, let day = today.day else { return nil }

        switch (month, day) {
        case (10, 1...3): return Holiday(name: "Ramazan Bayramı", kind: .fullDay)
        case (12, 9): return Holiday(name: "Kurban Bayramı Arifesi", kind: .afternoon)
        case (12, 10...13): return Holiday(name: "Kurban Bayramı", kind: .fullDay)
        default: break
        }

        // Ramazan ayı 29 ya da 30 çekebilir; arife, bayramın ilk gününden bir önceki gündür.
        if month == 9,
           let tomorrow = calendar.date(byAdding: .day, value: 1, to: noon) {
            let next = hijri.dateComponents([.month, .day], from: tomorrow)
            if next.month == 10 && next.day == 1 {
                return Holiday(name: "Ramazan Bayramı Arifesi", kind: .afternoon)
            }
        }
        return nil
    }
}
