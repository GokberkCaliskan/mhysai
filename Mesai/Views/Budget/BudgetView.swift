import SwiftUI

struct BudgetView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.hidesAmounts) private var hidden
    @State private var editing: BudgetItem?

    var body: some View {
        NavigationStack {
            List {
                if let engine = model.engine {
                    summary(engine: engine)
                    section(.expense, engine: engine)
                    section(.wish, engine: engine)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Kaç Mesai?")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { PrivacyToggle() }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Aylık gider ekle", systemImage: "house") { editing = newItem(.expense) }
                        Button("İstek ekle", systemImage: "gift") { editing = newItem(.wish) }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editing) { item in
                BudgetItemEditor(item: item)
            }
        }
    }

    // MARK: - Özet

    @ViewBuilder
    private func summary(engine: EarningsEngine) -> some View {
        let expenses = model.items(of: .expense).reduce(0) { $0 + $1.amount }
        if expenses > 0 {
            let now = AppClock.now
            let monthly = engine.netSalary(forMonthOf: now)
            let share = monthly > 0 ? expenses / monthly : 0

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Aylık giderlerin")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(Format.lira(expenses, fractionDigits: 0, hidden: hidden))
                        .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                    ProgressView(value: min(share, 1))
                        .tint(share > 0.7 ? .orange : Theme.money)
                    Text(summaryText(engine: engine, expenses: expenses, share: share, now: now))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(Theme.card)
        }
    }

    private func summaryText(engine: EarningsEngine, expenses: Double, share: Double, now: Date) -> String {
        let percent = "Maaşına oranı %\(Format.number(share * 100, fractionDigits: 0))."
        guard let freeFrom = engine.dateWhenEarned(expenses, inMonthOf: now) else {
            return "\(percent) Giderlerin bu ayki maaşını aşıyor 😬"
        }
        if freeFrom <= now {
            return "\(percent) Bu ayki giderlerini \(Format.dayMonthClock(freeFrom)) itibarıyla çıkardın, şu an kendin için çalışıyorsun 💸"
        }
        return "\(percent) Bu ay giderlerin için çalışman \(Format.dayMonthClock(freeFrom)) itibarıyla bitecek, sonrası senin 💸"
    }

    // MARK: - Bölümler

    private func section(_ kind: BudgetItem.Kind, engine: EarningsEngine) -> some View {
        let items = model.items(of: kind)
        let daily = engine.profile.schedule.dailyPaidMinutes

        return Section {
            ForEach(items) { item in
                Button {
                    editing = item
                } label: {
                    BudgetRow(
                        item: item,
                        workTime: Format.workTime(engine.workDuration(for: item.amount, at: AppClock.now), dailyPaidMinutes: daily),
                        summary: kind == .wish ? model.shortEquivalent(for: item) : nil,
                        hidden: hidden
                    )
                }
                .foregroundStyle(.primary)
                .swipeActions {
                    Button("Sil", systemImage: "trash", role: .destructive) {
                        withAnimation { model.delete(item) }
                    }
                }
            }

            if items.isEmpty {
                suggestions(for: kind)
            }
        } header: {
            Text(kind == .expense ? "Aylık giderler" : "İstek listesi")
        } footer: {
            Text(kind == .expense
                 ? "Kira, fatura gibi her ay ödediklerin. İstersen boş bırakabilirsin."
                 : "Almak istediğin şeyler için kaç gün mesai yapman gerektiğini gör.")
        }
        .listRowBackground(Theme.card)
    }

    private func suggestions(for kind: BudgetItem.Kind) -> some View {
        let list = kind == .expense ? BudgetItem.expenseSuggestions : BudgetItem.wishSuggestions
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(list) { suggestion in
                    Button {
                        editing = BudgetItem(kind: kind, emoji: suggestion.emoji, name: suggestion.name, amount: 0)
                    } label: {
                        Text("\(suggestion.emoji) \(suggestion.name)")
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

    private func newItem(_ kind: BudgetItem.Kind) -> BudgetItem {
        BudgetItem(kind: kind, emoji: kind == .expense ? "🏠" : "🎁", name: "", amount: 0)
    }
}

private struct BudgetRow: View {
    let item: BudgetItem
    let workTime: String
    let summary: String?
    let hidden: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(item.emoji)
                .font(.title2)
                .accessibilityHidden(true)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.06), in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body.weight(.semibold))
                Text(Format.lira(item.amount, fractionDigits: 0, hidden: hidden))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if let summary {
                    Text(summary)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(workTime)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.money)
                Text(item.kind == .expense ? "her ay" : "mesai")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

struct BudgetItemEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var item: BudgetItem
    @FocusState private var nameFocused: Bool

    init(item: BudgetItem) {
        _item = State(initialValue: item)
    }

    private var isNew: Bool { !model.budgetItems.contains { $0.id == item.id } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tür", selection: $item.kind) {
                        ForEach(BudgetItem.Kind.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    TextField(item.kind == .expense ? "Örn. Kira" : "Örn. iPhone 17 Pro", text: $item.name)
                        .focused($nameFocused)

                    // Düzenleme ekranında tutar her zaman girilebilir olmalı; listede gizli kalır.
                    HStack {
                        AmountField(amount: $item.amount, placeholder: item.kind == .expense ? "25.000" : "85.000")
                        Text("₺").foregroundStyle(.secondary)
                    }
                }

                Section("Simge") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
                        ForEach(BudgetItem.emojiChoices, id: \.self) { emoji in
                            Button {
                                item.emoji = emoji
                            } label: {
                                Text(emoji)
                                    .font(.title3)
                                    .frame(width: 40, height: 40)
                                    .background(item.emoji == emoji ? Theme.money.opacity(0.3) : .clear, in: .circle)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if item.amount > 0 {
                    Section("Neye denk geliyor?") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(model.equivalents(for: item)) { equivalent in
                                EquivalentTile(equivalent: equivalent, isPrimary: equivalent.id == "work")
                            }
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                }

                if !isNew {
                    Section {
                        Button("Sil", role: .destructive) {
                            model.delete(item)
                            dismiss()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .navigationTitle(isNew ? "Yeni kalem" : "Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) { PrivacyToggle() }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        model.upsert(item)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!item.isValid)
                }
            }
            .onAppear {
                if item.name.isEmpty { nameFocused = true }
            }
        }
        .presentationDetents([.large])
    }
}

private struct EquivalentTile: View {
    let equivalent: Equivalent
    let isPrimary: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(equivalent.emoji).font(.title2)
            VStack(alignment: .leading, spacing: 1) {
                Text(equivalent.value)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(isPrimary ? Theme.money : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(equivalent.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Theme.card, in: .rect(cornerRadius: 14))
    }
}
