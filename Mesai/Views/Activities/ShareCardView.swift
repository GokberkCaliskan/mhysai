import SwiftUI

/// Hikâyede paylaşılacak gün sonu kartı.
struct ShareCardView: View {
    let rows: [(kind: ActivityKind, duration: TimeInterval, earned: Double)]
    let total: Double
    let dailyEarnings: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("💸 \(AppInfo.name)")
                    .font(.headline)
                Spacer()
                Text(AppClock.now.formatted(.dateTime.day().month(.wide).locale(Format.locale)))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }

            if let top = rows.first {
                Text("Bugün \(top.kind.phrase) \(Format.lira(top.earned)) kazandım \(top.kind.emoji)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                ForEach(rows, id: \.kind.id) { row in
                    HStack {
                        Text("\(row.kind.emoji)  \(row.kind.name)")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer()
                        Text(Format.minutes(Int(row.duration / 60)))
                            .foregroundStyle(.white.opacity(0.6))
                        Text(Format.lira(row.earned))
                            .fontWeight(.semibold)
                            .frame(minWidth: 90, alignment: .trailing)
                    }
                    .font(.body.monospacedDigit())
                }
            }

            Divider().overlay(.white.opacity(0.2))

            HStack {
                VStack(alignment: .leading) {
                    Text("Kaytarma toplamı").font(.caption).foregroundStyle(.white.opacity(0.6))
                    Text(Format.lira(total)).font(.title3.bold()).foregroundStyle(Theme.money)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Günlük kazanç").font(.caption).foregroundStyle(.white.opacity(0.6))
                    Text(Format.lira(dailyEarnings, fractionDigits: 0)).font(.title3.bold())
                }
            }
            .monospacedDigit()
        }
        .padding(28)
        .frame(width: 380)
        .foregroundStyle(.white)
        .background(
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.22, blue: 0.14), Color(red: 0.02, green: 0.05, blue: 0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .environment(\.colorScheme, .dark)
    }
}

struct ShareSheet: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 20))
                    .padding()
            }
            .background(Theme.background)
            .navigationTitle("Günü paylaş")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                ShareLink(
                    item: Image(uiImage: image),
                    preview: SharePreview("Bugün mesaide ne kazandım", image: Image(uiImage: image))
                ) {
                    Label("Paylaş", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding()
            }
        }
    }
}
