import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var draft = SalaryProfile(amount: 0, period: .monthly, schedule: .standard)
    @State private var showsForm = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 28) {
                    Spacer()
                    Text("💸")
                        .font(.system(size: 88))
                    VStack(spacing: 12) {
                        Text("Mesaide her saniye\nne kazandığını gör")
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text("Maaşını ve mesai saatlerini gir, sayaç sabah mesaiyle başlasın. Tuvalette, çay molasında, boş toplantıda ne kadar kazandığını da öğren.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                    Button {
                        showsForm = true
                    } label: {
                        Text("Hadi başlayalım")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Text("Verilerin yalnızca bu telefonda kalır.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
            }
            .navigationDestination(isPresented: $showsForm) {
                Form {
                    // Kurulumda gizlilik modu olamaz: kullanıcı maaşını girebilmeli.
                    ProfileFormSections(profile: $draft)
                        .environment(\.hidesAmounts, false)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollContentBackground(.hidden)
                .background(Theme.background)
                .navigationTitle("Maaş ve mesai")
                .safeAreaInset(edge: .bottom) {
                    Button {
                        model.saveProfile(draft)
                    } label: {
                        Text("Sayacı başlat")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!draft.isValid)
                    .padding()
                    .background(.ultraThinMaterial)
                }
            }
        }
    }
}
