import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var draft = SalaryProfile(amount: 0, period: .monthly, schedule: .standard)
    @State private var confirmsReset = false

    var body: some View {
        NavigationStack {
            Form {
                ProfileFormSections(profile: $draft)
                    .environment(\.hidesAmounts, model.amountsHidden)

                NotificationSettingsSection()

                Section("Hakkında") {
                    NavigationLink("Nasıl hesaplanıyor?") { CalculationInfoView() }
                    NavigationLink("Gizlilik") { PrivacyPolicyView() }
                    Link(destination: AppInfo.sourceCodeURL) {
                        Label("Kaynak kodu (açık kaynak)", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    Link(destination: AppInfo.supportURL) {
                        Label("Destek ve geri bildirim", systemImage: "bubble.left.and.text.bubble.right")
                    }
                    if let url = AppInfo.reviewURL {
                        Link(destination: url) { Label("Uygulamayı değerlendir", systemImage: "star") }
                    }
                }

                Section {
                    Button("Tüm verileri sıfırla", role: .destructive) {
                        confirmsReset = true
                    }
                } footer: {
                    Text("Sürüm \(AppInfo.version) · Değişiklikler otomatik kaydedilir. Tüm veriler yalnızca bu cihazda saklanır.")
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .navigationTitle("Ayarlar")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { PrivacyToggle() }
            }
            .onAppear {
                if let profile = model.profile { draft = profile }
            }
            .onChange(of: draft) { _, newValue in
                if newValue.isValid, newValue != model.profile {
                    model.saveProfile(newValue)
                }
            }
            .confirmationDialog("Maaş bilgilerin ve kaytarma geçmişin silinecek.", isPresented: $confirmsReset, titleVisibility: .visible) {
                Button("Sıfırla", role: .destructive) { model.resetAll() }
            }
        }
    }
}

/// Mesai saatlerine bağlı yerel bildirim ayarları.
struct NotificationSettingsSection: View {
    @Environment(AppModel.self) private var model
    @State private var isDenied = false

    var body: some View {
        @Bindable var model = model
        Section {
            Toggle("Mesai bitimine 30 dk kala", isOn: binding(\.countdown))
            Toggle("Gün sonu özeti", isOn: binding(\.endOfDaySummary))
            Toggle("Espri bildirimleri 🚽", isOn: binding(\.jokes))
        } header: {
            Text("Bildirimler")
        } footer: {
            if isDenied {
                Text("Bildirimler kapalı. iPhone Ayarları → Mhysai → Bildirimler'den açman gerekiyor.")
                    .foregroundStyle(.orange)
            } else {
                Text("Bildirimler telefonunda hazırlanır, hiçbir yere veri gönderilmez. Hafta sonu, resmî tatil ve izin günlerinde gelmez.")
            }
        }
        .task {
            isDenied = await NotificationScheduler.authorizationStatus() == .denied
        }
    }

    private func binding(_ keyPath: WritableKeyPath<NotificationPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { model.notificationPreferences[keyPath: keyPath] },
            set: { newValue in
                var preferences = model.notificationPreferences
                preferences[keyPath: keyPath] = newValue
                if newValue {
                    Task {
                        let granted = await NotificationScheduler.requestAuthorization()
                        isDenied = !granted
                        if granted { model.setNotificationPreferences(preferences) }
                    }
                } else {
                    model.setNotificationPreferences(preferences)
                }
            }
        )
    }
}
