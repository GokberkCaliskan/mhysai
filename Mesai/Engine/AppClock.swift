import Foundation

/// Uygulamanın "şimdi"si. Geliştirme sürümünde `-demoNow 2026-09-15T14:32:00` başlatma
/// argümanıyla saat kaydırılabilir (App Store ekran görüntüleri için); yayında hep gerçek saattir.
enum AppClock {
    #if DEBUG
    static let offset: TimeInterval = {
        guard let value = UserDefaults.standard.string(forKey: "demoNow") else { return 0 }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        guard let target = formatter.date(from: value) else { return 0 }
        return target.timeIntervalSinceNow
    }()
    #else
    static let offset: TimeInterval = 0
    #endif

    static var now: Date { Date().addingTimeInterval(offset) }

    static func adjusted(_ date: Date) -> Date {
        date.addingTimeInterval(offset)
    }
}
