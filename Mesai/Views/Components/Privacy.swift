import SwiftUI

extension EnvironmentValues {
    /// İş yerinde açıldığında tutarların görünmemesi için gizlilik modu.
    @Entry var hidesAmounts = false
}

extension Format {
    static let maskedAmount = "₺ ****"

    static func lira(_ value: Double, fractionDigits: Int = 2, hidden: Bool) -> String {
        hidden ? maskedAmount : lira(value, fractionDigits: fractionDigits)
    }
}

/// Tutarları gösterip gizleyen göz butonu.
struct PrivacyToggle: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            withAnimation(.snappy) { model.amountsHidden.toggle() }
        } label: {
            Image(systemName: model.amountsHidden ? "eye.slash" : "eye")
                .contentTransition(.symbolEffect(.replace))
        }
        .accessibilityLabel(model.amountsHidden ? "Tutarları göster" : "Tutarları gizle")
        .sensoryFeedback(.selection, trigger: model.amountsHidden)
    }
}
