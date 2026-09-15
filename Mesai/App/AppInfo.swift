import Foundation

/// Mağaza ve destek bilgileri. App Store Connect kaydından sonra doldurulmalı.
enum AppInfo {
    /// Geri bildirim e-postası; boşken Ayarlar'da gösterilmez.
    static let supportEmail = ""
    /// App Store uygulama kimliği (sayısal); boşken "Değerlendir" gösterilmez.
    static let appStoreID = ""

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    static var reviewURL: URL? {
        appStoreID.isEmpty ? nil : URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }

    static var feedbackURL: URL? {
        guard !supportEmail.isEmpty else { return nil }
        let subject = "Mesai geri bildirim \(version)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "mailto:\(supportEmail)?subject=\(subject)")
    }
}
