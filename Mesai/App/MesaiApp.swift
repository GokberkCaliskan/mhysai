import SwiftUI

@main
struct MesaiApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .tint(Theme.money)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            content
        }
        .environment(\.hidesAmounts, model.amountsHidden)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { model.amountsHidden = true }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.profile == nil {
            OnboardingView()
        } else {
            TabView {
                HomeView()
                    .tabItem { Label("Sayaç", systemImage: "turkishlirasign.circle.fill") }
                ActivitiesView()
                    .tabItem { Label("Kaytarma", systemImage: "cup.and.saucer.fill") }
                BudgetView()
                    .tabItem { Label("Kaç Mesai?", systemImage: "hourglass") }
                SettingsView()
                    .tabItem { Label("Ayarlar", systemImage: "gearshape.fill") }
            }
        }
    }
}

enum Theme {
    static let money = Color(red: 0.18, green: 0.80, blue: 0.44)
    static let background = LinearGradient(
        colors: [Color(red: 0.04, green: 0.09, blue: 0.07), Color(red: 0.02, green: 0.03, blue: 0.04)],
        startPoint: .top,
        endPoint: .bottom
    )
    static let card = Color.white.opacity(0.06)
}
