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

                Section {
                    Button("Tüm verileri sıfırla", role: .destructive) {
                        confirmsReset = true
                    }
                } footer: {
                    Text("Mesai v0.1 · Değişiklikler otomatik kaydedilir. Tüm veriler yalnızca bu cihazda saklanır.")
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
