import SwiftUI

/// Brüt maaşın 12 aylık bordro dökümü: dilim yükseldikçe netin düşüşü.
struct PayrollView: View {
    let profile: SalaryProfile
    @Environment(\.hidesAmounts) private var hidden

    private var year: Int { Calendar.turkish.component(.year, from: AppClock.now) }
    private var currentMonth: Int { Calendar.turkish.component(.month, from: AppClock.now) }

    var body: some View {
        let months = profile.payroll(year: year)
        let totalNet = months.reduce(0) { $0 + $1.net }
        let totalGross = months.reduce(0) { $0 + $1.gross }
        let totalTax = months.reduce(0) { $0 + $1.incomeTax + $1.stampTax }

        List {
            Section {
                LabeledContent("Yıllık brüt", value: Format.lira(totalGross, fractionDigits: 0, hidden: hidden))
                LabeledContent("Yıllık net", value: Format.lira(totalNet, fractionDigits: 0, hidden: hidden))
                LabeledContent("Gelir + damga vergisi", value: Format.lira(totalTax, fractionDigits: 0, hidden: hidden))
                if let first = months.first, let last = months.last, first.net > last.net {
                    Text("Vergi matrahın biriktikçe üst dilime giriyorsun. Ocak'ta \(Format.lira(first.net, fractionDigits: 0, hidden: hidden)) olan net maaşın Aralık'ta \(Format.lira(last.net, fractionDigits: 0, hidden: hidden)) oluyor.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .listRowBackground(Theme.card)

            Section {
                ForEach(months) { month in
                    PayrollRow(month: month, isCurrent: month.month == currentMonth, hidden: hidden)
                }
            } footer: {
                Text("\(year) tarifesiyle hesaplanır: işçi SGK %14, işsizlik %1 (SGK tavanı \(Format.lira(PayrollParameters.forYear(year).sgkCeiling, fractionDigits: 0))), ücret gelir vergisi dilimleri %15–40, damga vergisi binde 7,59 ve asgari ücret istisnası. Her ay aynı brütü aldığın varsayılır; BES, özel sigorta, engellilik indirimi, ikramiye ve yan haklar dahil değildir. Bordronla küçük farklar olabilir.")
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Aylık net döküm")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PayrollRow: View {
    let month: PayrollMonth
    let isCurrent: Bool
    let hidden: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(monthName)
                    .font(.body.weight(isCurrent ? .bold : .regular))
                if isCurrent {
                    Text("bu ay")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.money.opacity(0.2), in: .capsule)
                        .foregroundStyle(Theme.money)
                }
                Spacer()
                Text("%\(Format.number(month.bracketRate * 100, fractionDigits: 0))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(Format.lira(month.net, fractionDigits: 0, hidden: hidden))
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.money)
                    .frame(minWidth: 96, alignment: .trailing)
            }
            if !hidden {
                Text("SGK+İşsizlik \(Format.lira(month.sgk + month.unemployment, fractionDigits: 0)) · Gelir V. \(Format.lira(month.incomeTax, fractionDigits: 0)) · Damga \(Format.lira(month.stampTax, fractionDigits: 0))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var monthName: String {
        Calendar.turkish.standaloneMonthSymbols[month.month - 1].capitalized(with: Format.locale)
    }
}
