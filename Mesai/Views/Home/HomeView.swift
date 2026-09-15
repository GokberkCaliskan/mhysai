import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                if let engine = model.engine {
                    TimelineView(.periodic(from: .now, by: 0.1)) { context in
                        ScrollView {
                            HomeContent(engine: engine, now: context.date, dailyEarnings: model.dailyEarnings(at: context.date))
                                .padding()
                        }
                    }
                }
            }
            .navigationTitle("Bugün")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { PrivacyToggle() }
            }
        }
    }
}

private struct HomeContent: View {
    let engine: EarningsEngine
    let now: Date
    let dailyEarnings: Double
    @Environment(\.hidesAmounts) private var hidden

    var body: some View {
        let today = engine.earnedToday(at: now)
        let status = engine.status(at: now)

        VStack(spacing: 16) {
            StatusPill(status: status)

            counter(today: today, status: status)

            statsGrid

            comparisons(today: today)

            monthInfo
        }
    }

    private func counter(today: Double, status: WorkStatus) -> some View {
        let parts = hidden ? (main: Format.maskedAmount, tail: "") : Format.tickingLira(today)
        let intervals = engine.paidIntervals(on: now)
        let isWorking = if case .working = status { true } else { false }

        return VStack(spacing: 14) {
            Text("Bugün kazandığın")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(parts.main)
                    .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(parts.tail)
                    .font(.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.money.opacity(0.7))
            }
            .foregroundStyle(isWorking ? Theme.money : .primary)
            .shadow(color: isWorking ? Theme.money.opacity(0.35) : .clear, radius: 16)

            if let first = intervals.first, let last = intervals.last {
                VStack(spacing: 6) {
                    ProgressView(value: engine.dayProgress(at: now))
                        .tint(Theme.money)
                    HStack {
                        Text(Format.clock(first.start))
                        Spacer()
                        Text("Gün sonu: \(Format.lira(engine.expectedToday(at: now), fractionDigits: 0, hidden: hidden))")
                        Spacer()
                        Text(Format.clock(last.end))
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: 24))
    }

    private var statsGrid: some View {
        let rate = engine.currentRatePerSecond(at: now)
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatTile(title: "Günlük", value: Format.lira(dailyEarnings, fractionDigits: 0, hidden: hidden))
                StatTile(title: "Saatte", value: Format.lira(rate * 3600, fractionDigits: 0, hidden: hidden))
                StatTile(title: "Dakikada", value: Format.lira(rate * 60, hidden: hidden))
            }
            HStack(spacing: 12) {
                StatTile(title: "Bu ay", value: Format.lira(engine.earnedThisMonth(at: now), fractionDigits: 0, hidden: hidden))
                StatTile(title: "Bu yıl", value: Format.lira(engine.earnedThisYear(at: now), fractionDigits: 0, hidden: hidden))
            }
        }
    }

    private func comparisons(today: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bugünkü kazancınla")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(PriceComparison.all) { item in
                        VStack(spacing: 4) {
                            Text(item.emoji).font(.title2)
                            Text(hidden ? "**" : Format.number(today / item.price))
                                .font(.headline.monospacedDigit())
                            Text(item.unit)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(minWidth: 76)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                        .background(Theme.card, in: .rect(cornerRadius: 16))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var monthInfo: some View {
        let days = engine.workdayCount(inMonthOf: now)
        let monthName = now.formatted(.dateTime.month(.wide).locale(Format.locale)).capitalized(with: Format.locale)
        var text = "\(monthName) \(days) iş günü çekiyor · maaşın bu günlere bölünür"
        if engine.profile.amountType == .gross {
            text += "\nBu ay eline geçen net: \(Format.lira(engine.netSalary(forMonthOf: now), fractionDigits: 0, hidden: hidden))"
        }
        return Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }
}

struct StatusPill: View {
    let status: WorkStatus

    var body: some View {
        let (icon, text, color) = describe
        Label(text, systemImage: icon)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(color.opacity(0.15), in: .capsule)
            .foregroundStyle(color)
    }

    private var describe: (String, String, Color) {
        switch status {
        case .beforeWork(let start):
            ("sunrise.fill", "Mesai başlangıcı \(Format.clock(start)) · \(Format.duration(start.timeIntervalSinceNow)) kaldı", .orange)
        case .working(let end):
            ("bolt.fill", "Mesaidesin · \(Format.duration(end.timeIntervalSinceNow)) kaldı", Theme.money)
        case .onBreak(let resume):
            ("fork.knife", "Öğle arası · dönüş \(Format.clock(resume))", .yellow)
        case .afterWork(let next):
            ("moon.stars.fill", next.map { "Mesai bitti · sonraki \(Format.dayAndClock($0))" } ?? "Mesai bitti", .indigo)
        case .dayOff(let reason, let next):
            ("beach.umbrella.fill", next.map { "\(reason) · sonraki mesai \(Format.dayAndClock($0))" } ?? reason, .cyan)
        }
    }
}

struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.card, in: .rect(cornerRadius: 18))
    }
}
