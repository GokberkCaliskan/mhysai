import SwiftUI

struct PortfolioView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.hidesAmounts) private var hidden
    @State private var editing: Holding?

    var body: some View {
        NavigationStack {
            List {
                if model.holdings.isEmpty {
                    emptyState
                } else {
                    summarySection
                    holdingsSection
                }
                sourceFooter
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Varlıklarım")
            .refreshable { await model.refreshQuotesIfNeeded(force: true) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { PrivacyToggle() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editing = Holding(kind: .gold) } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Varlık ekle")
                }
            }
            .sheet(item: $editing) { HoldingEditor(holding: $0) }
            .task { await model.refreshQuotesIfNeeded() }
        }
    }

    // MARK: - Bölümler

    private var emptyState: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("Elindeki altın, döviz ve hisseleri ekle; güncel fiyatlarıyla kaç iş günü mesaiye denk geldiklerini gör.")
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Holding.Kind.allCases) { kind in
                            Button {
                                editing = Holding(kind: kind, symbol: kind == .stock ? "AAPL" : "")
                            } label: {
                                Text("\(kind.emoji) \(kind.title)")
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.08), in: .capsule)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(.vertical, 6)
        }
        .listRowBackground(Theme.card)
    }

    private var summarySection: some View {
        let total = model.portfolioValue
        let engine = model.engine

        return Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("Varlıklarının toplamı")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(Format.lira(total, fractionDigits: 0, hidden: hidden))
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText(value: total))

                if let engine, total > 0 {
                    let workTime = Format.workTime(
                        engine.workDuration(for: total, at: AppClock.now),
                        dailyPaidMinutes: engine.profile.schedule.dailyPaidMinutes
                    )
                    let monthly = engine.netSalary(forMonthOf: AppClock.now)
                    Text("\(workTime) mesaiye denk · \(Format.number(monthly > 0 ? total / monthly : 0, fractionDigits: 1)) maaş")
                        .font(.subheadline)
                        .foregroundStyle(Theme.money)
                }

                statusLine
            }
            .padding(.vertical, 6)
        }
        .listRowBackground(Theme.card)
    }

    @ViewBuilder
    private var statusLine: some View {
        if model.isRefreshingQuotes {
            Label("Fiyatlar güncelleniyor…", systemImage: "arrow.clockwise")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if let failure = model.quoteFailure, model.quotesUpdatedAt != nil {
            Label(failure.message, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        } else if let failure = model.quoteFailure {
            Label(failure.message, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        } else if let updated = model.quotesUpdatedAt {
            Text("Fiyatlar \(Format.dayAndClock(updated)) itibarıyla · aşağı çekerek yenile")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var holdingsSection: some View {
        Section("Varlıklar") {
            ForEach(model.holdings) { holding in
                Button { editing = holding } label: {
                    HoldingRow(
                        holding: holding,
                        value: PortfolioValuation.value(of: holding, quotes: model.quotes),
                        unitPrice: PortfolioValuation.unitPrice(of: holding, quotes: model.quotes),
                        hidden: hidden
                    )
                }
                .foregroundStyle(.primary)
                .swipeActions {
                    Button("Sil", systemImage: "trash", role: .destructive) {
                        withAnimation { model.delete(holding) }
                    }
                }
            }
        }
        .listRowBackground(Theme.card)
    }

    private var sourceFooter: some View {
        Section {
            EmptyView()
        } footer: {
            Text("Fiyatlar Yahoo Finance'in herkese açık verisinden gelir ve gecikmeli olabilir. Gram altın, ons altın fiyatı ile dolar kurundan hesaplanır; kapalıçarşı fiyatından farklı olabilir. Uygulama yalnızca sembol adını sorar, sana ait hiçbir bilgi gönderilmez.")
        }
    }
}

private struct HoldingRow: View {
    let holding: Holding
    let value: Double?
    let unitPrice: Double?
    let hidden: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(holding.kind.emoji)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.06), in: .circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(holding.name)
                    .font(.body.weight(.semibold))
                Text("\(Format.number(holding.quantity, fractionDigits: 2)) \(holding.kind.unit)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if let unitPrice {
                    Text("birim \(Format.lira(unitPrice, fractionDigits: 0, hidden: hidden))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(value.map { Format.lira($0, fractionDigits: 0, hidden: hidden) } ?? "—")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.money)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

struct HoldingEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var holding: Holding
    @State private var quantityText = ""
    @State private var query = ""
    @State private var results: [SymbolResult] = []
    @State private var isSearching = false
    @State private var searchService = SymbolSearchService()

    init(holding: Holding) {
        _holding = State(initialValue: holding)
        _quantityText = State(initialValue: holding.quantity > 0 ? Format.number(holding.quantity, fractionDigits: 4) : "")
    }

    private var isNew: Bool { !model.holdings.contains { $0.id == holding.id } }

    @ViewBuilder
    private var stockSearchSection: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Şirket adı ya da sembol ara", text: $query)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
            if isSearching { ProgressView().controlSize(.small) }
            else if !query.isEmpty {
                Button { query = ""; results = [] } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Aramayı temizle")
            }
        }

        if !holding.symbol.isEmpty, results.isEmpty {
            Label("\(holding.symbol.uppercased()) · \(holding.title.isEmpty ? "seçildi" : holding.title)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Theme.money)
                .font(.subheadline)
        }

        ForEach(results.isEmpty && query.isEmpty ? Holding.popularStocks : results) { result in
            Button {
                holding.symbol = result.symbol
                holding.title = result.name
                query = ""
                results = []
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.name).font(.subheadline.weight(.medium)).lineLimit(1)
                        Text(result.symbol).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(result.exchange).font(.caption2).foregroundStyle(.secondary)
                    if holding.symbol.uppercased() == result.symbol.uppercased() {
                        Image(systemName: "checkmark").foregroundStyle(Theme.money)
                    }
                }
                .contentShape(.rect)
            }
            .foregroundStyle(.primary)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tür", selection: $holding.kind) {
                        ForEach(Holding.Kind.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if holding.kind == .stock {
                        stockSearchSection
                    }

                    HStack {
                        TextField(holding.kind == .gold ? "Kaç gram?" : "Miktar", text: $quantityText)
                            .keyboardType(.decimalPad)
                            .font(.title3.weight(.semibold).monospacedDigit())
                            .onChange(of: quantityText) { _, new in
                                holding.quantity = Double(new.replacingOccurrences(of: ",", with: ".")) ?? 0
                            }
                        Text(holding.kind.unit).foregroundStyle(.secondary)
                    }
                } footer: {
                    Text(holding.kind == .stock
                         ? "Şirket adını ya da sembolü ara: \"nvidia\", \"aselsan\", \"bitcoin\". ABD hisseleri dolardan, BIST hisseleri TL'den hesaplanır."
                         : "Kaç adet/gram olduğunu yaz; güncel fiyatıyla TL karşılığını hesaplarız.")
                }

                if !isNew {
                    Section {
                        Button("Sil", role: .destructive) {
                            model.delete(holding)
                            dismiss()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .navigationTitle(isNew ? "Varlık ekle" : "Düzenle")
            .task(id: query) {
                let text = query
                guard text.trimmingCharacters(in: .whitespaces).count >= 2 else {
                    results = []
                    return
                }
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                isSearching = true
                let found = await searchService.search(text)
                guard !Task.isCancelled else { return }
                results = found
                isSearching = false
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        model.upsert(holding)
                        Task { await model.refreshQuotesIfNeeded(force: true) }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!holding.isValid)
                }
            }
        }
    }
}
