import SwiftUI

/// Kurulum ve ayarlar ekranının ortak form bölümleri.
struct ProfileFormSections: View {
    @Binding var profile: SalaryProfile
    @Environment(\.hidesAmounts) private var hidden

    var body: some View {
        Section {
            Picker("Tür", selection: $profile.amountType) {
                ForEach(AmountType.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            Picker("Dönem", selection: $profile.period) {
                ForEach(PayPeriod.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            if hidden {
                Label("Maaş gizli · göstermek için 👁 simgesine dokun", systemImage: "eye.slash")
                    .foregroundStyle(.secondary)
            } else {
                HStack {
                    AmountField(amount: $profile.amount)
                    Text("₺").foregroundStyle(.secondary)
                }
            }

            if profile.amountType == .gross, profile.amount > 0 {
                NavigationLink {
                    PayrollView(profile: profile)
                } label: {
                    grossSummary
                }
            }
        } header: {
            Text(profile.amountType == .net ? "Eline geçen net maaş" : "Brüt maaş")
        } footer: {
            if profile.amountType == .gross {
                Text("Brüt maaştan SGK, gelir vergisi ve damga vergisi düşülür. Vergi dilimin yıl içinde yükseldikçe net maaşın aydan aya azalır; sayaç her ayın kendi netiyle çalışır.")
            } else if profile.period == .yearly, profile.amount > 0, !hidden {
                Text("Aylık ortalama \(Format.lira(profile.monthlyAmount, fractionDigits: 0))")
            }
        }

        Section("Çalıştığın günler") {
            WeekdayPicker(selection: $profile.schedule.workdays)
                .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
        }

        Section {
            DatePicker("Mesai başlangıcı", selection: minutes(\.startMinute), displayedComponents: .hourAndMinute)
            DatePicker("Mesai bitişi", selection: minutes(\.endMinute), displayedComponents: .hourAndMinute)

            Toggle("Öğle arası ücretsiz", isOn: $profile.schedule.hasLunchBreak)
            if profile.schedule.hasLunchBreak {
                DatePicker("Öğle arası", selection: minutes(\.lunchStartMinute), displayedComponents: .hourAndMinute)
                Stepper(
                    "Süre: \(profile.schedule.lunchDurationMinutes) dk",
                    value: $profile.schedule.lunchDurationMinutes,
                    in: 15...120,
                    step: 15
                )
            }
        } header: {
            Text("Mesai saatleri")
        } footer: {
            if profile.schedule.endMinute <= profile.schedule.startMinute {
                Text("Bitiş saati başlangıçtan sonra olmalı. Gece vardiyası desteği yakında.")
                    .foregroundStyle(.orange)
            } else {
                let hours = Double(profile.schedule.dailyPaidMinutes) / 60
                Text("Günde \(Format.number(hours)) saat ücretli çalışma")
            }
        }

        Section {
            Toggle("Resmî tatillerde çalışmıyorum", isOn: $profile.schedule.observesPublicHolidays)
        } footer: {
            Text("Bayramlar, milli tatiller ve arifelerde (13:00 sonrası) sayaç çalışmaz; maaşın o ayın kalan iş günlerine dağıtılır.")
        }
    }

    private var grossSummary: some View {
        let calendar = Calendar.turkish
        let c = calendar.dateComponents([.year, .month], from: .now)
        let months = profile.payroll(year: c.year ?? 2026)
        let current = months.first { $0.month == c.month }
        return VStack(alignment: .leading, spacing: 4) {
            Text("Bu ay eline geçen")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(Format.lira(current?.net ?? 0, fractionDigits: 0, hidden: hidden))
                .font(.headline.monospacedDigit())
                .foregroundStyle(Theme.money)
            if let first = months.first, let last = months.last {
                Text("Ocak \(Format.lira(first.net, fractionDigits: 0, hidden: hidden)) → Aralık \(Format.lira(last.net, fractionDigits: 0, hidden: hidden)) · aylık dökümü gör")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func minutes(_ keyPath: WritableKeyPath<WorkSchedule, Int>) -> Binding<Date> {
        Binding(
            get: { Format.minutesToDate(profile.schedule[keyPath: keyPath]) },
            set: { profile.schedule[keyPath: keyPath] = Format.dateToMinutes($0) }
        )
    }
}

/// Tam sayı tutar alanı. Yazarken ham rakamları tutar (araya nokta eklemek hızlı yazımda
/// tuş kaybettiriyor), biçimli hâli yanda gösterir; odaktan çıkınca "60.000" olur.
struct AmountField: View {
    @Binding var amount: Double
    var placeholder = "60.000"
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            TextField(placeholder, text: $text)
                .keyboardType(.numberPad)
                .font(.title2.weight(.semibold).monospacedDigit())
                .focused($focused)
            if focused, amount >= 1000 {
                Text(Self.format(amount))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { text = Self.format(amount) }
        .onChange(of: focused) { _, isFocused in
            text = isFocused ? Self.digits(amount) : Self.format(amount)
        }
        .onChange(of: text) { _, newValue in
            guard focused else { return }
            let digits = String(newValue.filter(\.isNumber).prefix(10))
            amount = Double(digits) ?? 0
            if digits != newValue { text = digits }
        }
    }

    private static func digits(_ value: Double) -> String {
        value > 0 ? String(Int(value)) : ""
    }

    private static func format(_ value: Double) -> String {
        value > 0 ? value.formatted(.number.locale(Format.locale).precision(.fractionLength(0))) : ""
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(isEnabled ? .black : .white.opacity(0.4))
            .background(isEnabled ? Theme.money : Color.white.opacity(0.1), in: .capsule)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy, value: configuration.isPressed)
    }
}

struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    /// Pazartesi'den başlayan sıra.
    private let days: [(weekday: Int, label: String)] = [
        (2, "Pzt"), (3, "Sal"), (4, "Çar"), (5, "Per"), (6, "Cum"), (7, "Cmt"), (1, "Paz"),
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days, id: \.weekday) { day in
                let isOn = selection.contains(day.weekday)
                Button {
                    if isOn { selection.remove(day.weekday) } else { selection.insert(day.weekday) }
                } label: {
                    Text(day.label)
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(isOn ? Theme.money : Color.white.opacity(0.08), in: .rect(cornerRadius: 10))
                        .foregroundStyle(isOn ? .black : .secondary)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: isOn)
            }
        }
    }
}
