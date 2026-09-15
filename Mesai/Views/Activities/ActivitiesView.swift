import SwiftUI

struct ActivitiesView: View {
    @Environment(AppModel.self) private var model
    @State private var shareImage: ShareImage?
    @Environment(\.hidesAmounts) private var hidden

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                content
            }
            .navigationTitle("Kaytarma Sayacı")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { PrivacyToggle() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        shareImage = ShareImage(image: renderShareCard())
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Günü paylaş")
                    .disabled(model.totalMinutes() == 0)
                }
            }
            .sheet(item: $shareImage) { item in
                ShareSheet(image: item.image)
            }
        }
    }

    private var content: some View {
        let totalMinutes = model.totalMinutes()
        let total = model.earnings(forMinutes: totalMinutes)
        let daily = model.dailyEarnings()
        let share = daily > 0 ? total / daily : 0

        return ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("Bugün kaytararak kazandığın")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(Format.lira(total, hidden: hidden))
                        .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Theme.money)
                        .contentTransition(.numericText(value: total))
                    Text(totalMinutes > 0
                         ? "\(Format.minutes(totalMinutes)) · günlük kazancının %\(Format.number(share * 100))"
                         : "Günlük kazancın \(Format.lira(daily, fractionDigits: 0, hidden: hidden))")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Theme.card, in: .rect(cornerRadius: 24))

                VStack(spacing: 10) {
                    ForEach(ActivityKind.all) { kind in
                        let minutes = model.minutes(for: kind)
                        ActivityRow(
                            kind: kind,
                            minutes: minutes,
                            earned: model.earnings(forMinutes: minutes),
                            hidden: hidden,
                            onDecrement: { adjust(kind, by: -ActivityKind.stepMinutes) },
                            onIncrement: { adjust(kind, by: ActivityKind.stepMinutes) }
                        )
                    }
                }

                Text("Bugün ne kadar kaytardığını \(ActivityKind.stepMinutes)'er dakika ekleyerek gir. Hesap, bu ayki dakikalık kazancına göre yapılır.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }

    private func adjust(_ kind: ActivityKind, by delta: Int) {
        withAnimation(.snappy) { model.adjust(kind, by: delta) }
    }

    @MainActor
    private func renderShareCard() -> UIImage {
        let rows = ActivityKind.all
            .map { kind in
                let minutes = model.minutes(for: kind)
                return (kind: kind, duration: TimeInterval(minutes * 60), earned: model.earnings(forMinutes: minutes))
            }
            .filter { $0.duration > 0 }
            .sorted { $0.earned > $1.earned }

        let card = ShareCardView(
            rows: rows,
            total: rows.reduce(0) { $0 + $1.earned },
            dailyEarnings: model.dailyEarnings()
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        return renderer.uiImage ?? UIImage()
    }
}

private struct ShareImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct ActivityRow: View {
    let kind: ActivityKind
    let minutes: Int
    let earned: Double
    let hidden: Bool
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        let isActive = minutes > 0
        HStack(spacing: 12) {
            Text(kind.emoji)
                .font(.title)
                .frame(width: 44)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(kind.name)
                    .font(.subheadline.weight(.semibold))
                Text(isActive ? "\(Format.minutes(minutes)) · \(Format.lira(earned, hidden: hidden))" : "—")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(isActive ? Theme.money : .secondary)
                    .contentTransition(.numericText(value: earned))
            }

            Spacer()

            StepButton(systemImage: "minus", isEnabled: isActive, action: onDecrement)
                .accessibilityLabel("\(kind.name), \(ActivityKind.stepMinutes) dakika azalt")
            StepButton(systemImage: "plus", isEnabled: minutes < ActivityKind.maxMinutes, action: onIncrement)
                .accessibilityLabel("\(kind.name), \(ActivityKind.stepMinutes) dakika ekle")
        }
        .padding(12)
        .background(isActive ? Theme.money.opacity(0.10) : Theme.card, in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(isActive ? Theme.money.opacity(0.35) : .clear))
        .sensoryFeedback(.selection, trigger: minutes)
    }
}

private struct StepButton: View {
    let systemImage: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.bold))
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(isEnabled ? 0.12 : 0.04), in: .circle)
                .foregroundStyle(isEnabled ? .primary : .tertiary)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}
