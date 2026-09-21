import Foundation
import UserNotifications

struct NotificationPreferences: Codable, Equatable {
    var countdown = false
    var endOfDaySummary = false
    var jokes = false

    var isAnyOn: Bool { countdown || endOfDaySummary || jokes }

    /// Mesai bitimine kaç dakika kala hatırlatılsın.
    var countdownMinutes = 30
}

/// Mesai saatlerine göre yerel bildirim planlar. Hiçbir veri dışarı çıkmaz.
enum NotificationScheduler {
    static let scheduledDays = 14

    static let jokes = [
        "Mesai bitmeden tuvalete gitmenin tam sırası 🚽 Şirket saatinde, şirketin parasına.",
        "Çay molası zamanı ☕️ Bardağı doldur, sayaç senin için çalışmaya devam etsin.",
        "Toplantıda mısın? Merak etme, susmak da para kazandırıyor 🧑‍💼",
        "Bugünün en kârlı hareketi: koridorda amaçsız bir tur 🚶 Dakikası cepte.",
        "Ekrana bakıp derin derin düşünüyormuş gibi yapmanın maliyeti patronda 👀",
        "Kahve kuyruğu uzunmuş, ne güzel ☕️ Sıra beklerken de kazanıyorsun.",
        "Klavyeye hızlı hızlı basıp 'yoğunum' demek de bir sanattır ⌨️",
        "Son viraj: e-postaya 'ilgileniyorum, dönüş yapacağım' yaz, kapat 📧",
        "Buzdolabına gitme vakti 🧊 Yolun her adımı ücretli.",
        "Şirket telefonuyla kişisel işini halletme saati geldi 📱",
    ]

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Planlanacak bildirimleri hesaplar (test edilebilir, saf fonksiyon).
    static func plannedNotifications(
        engine: EarningsEngine,
        preferences: NotificationPreferences,
        now: Date,
        days: Int = scheduledDays
    ) -> [PlannedNotification] {
        guard preferences.isAnyOn else { return [] }
        let calendar = engine.calendar
        var planned: [PlannedNotification] = []
        var day = calendar.startOfDay(for: now)

        for offset in 0..<days {
            defer { day = calendar.date(byAdding: .day, value: 1, to: day)! }
            let intervals = engine.paidIntervals(on: day)
            guard let end = intervals.last?.end else { continue }

            if preferences.countdown,
               let fire = calendar.date(byAdding: .minute, value: -preferences.countdownMinutes, to: end),
               fire > now {
                let earned = engine.earnings(from: calendar.startOfDay(for: day), to: fire)
                planned.append(PlannedNotification(
                    id: "countdown-\(offset)",
                    date: fire,
                    title: "Mesai bitimine \(preferences.countdownMinutes) dakika ⏳",
                    body: "Bugün şu ana kadar \(Format.lira(earned, fractionDigits: 0)) kazandın. Son düzlük!"
                ))
            }

            if preferences.jokes,
               let fire = calendar.date(byAdding: .minute, value: -(preferences.countdownMinutes + 25), to: end),
               fire > now {
                let index = abs(calendar.component(.day, from: day) &+ calendar.component(.month, from: day) &* 31) % jokes.count
                planned.append(PlannedNotification(
                    id: "joke-\(offset)",
                    date: fire,
                    title: "Mhysai",
                    body: jokes[index]
                ))
            }

            if preferences.endOfDaySummary, end > now {
                let total = engine.earnings(from: calendar.startOfDay(for: day), to: end)
                planned.append(PlannedNotification(
                    id: "summary-\(offset)",
                    date: end,
                    title: "Mesai bitti 🎉",
                    body: "Bugün \(Format.lira(total, fractionDigits: 0)) kazandın. Kaytarma dakikalarını girmeyi unutma 🚽"
                ))
            }
        }
        return planned
    }

    @MainActor
    static func reschedule(engine: EarningsEngine?, preferences: NotificationPreferences, now: Date = AppClock.now) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        guard let engine, preferences.isAnyOn else { return }
        guard await authorizationStatus() == .authorized else { return }

        let calendar = engine.calendar
        for item in plannedNotifications(engine: engine, preferences: preferences, now: now) {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
        }
    }
}

struct PlannedNotification: Equatable {
    let id: String
    let date: Date
    let title: String
    let body: String
}
