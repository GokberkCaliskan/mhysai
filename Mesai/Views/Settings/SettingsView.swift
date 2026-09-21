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
