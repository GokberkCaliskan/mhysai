import StoreKit
import SwiftUI

@main
struct MesaiApp: App {
    @State private var model: AppModel

    init() {
        #if DEBUG
        DemoData.seedIfRequested()
        #endif
        let model = AppModel()
        #if DEBUG
        if DemoData.revealsAmounts { model.amountsHidden = false }
        #endif
        _model = State(initialValue: model)
    }

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
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        Group {
            content
        }
        .environment(\.hidesAmounts, model.amountsHidden)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                #if DEBUG
                if DemoData.revealsAmounts { return }
                #endif
                model.amountsHidden = true
            case .active:
                if model.registerActiveDay() { requestReview() }
            default:
                break
            }
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
