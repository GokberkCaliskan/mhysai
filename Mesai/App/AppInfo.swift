import Foundation

/// Mağaza ve destek bilgileri.
enum AppInfo {
    static let name = "Mhysai"
    /// Destek ve geri bildirim: GitHub Issues (herkese açık e-posta yayınlamadan).
    static let supportURL = URL(string: "https://github.com/GokberkCaliskan/mhysai/issues")!
    static let privacyPolicyURL = URL(string: "https://gokberkcaliskan.github.io/mhysai/privacy.html")!
    /// App Store uygulama kimliği (sayısal); App Store Connect kaydından sonra doldurulur, boşken "Değerlendir" gösterilmez.
    static let appStoreID = "6812497140"

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    static var reviewURL: URL? {
        appStoreID.isEmpty ? nil : URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }
}
