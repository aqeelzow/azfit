import AZModel
import AZStore
import AZSync
import SwiftUI

/// Adding food to a meal: search your own foods and the food database, scan a barcode, make a food, or log
/// something from before again in one tap.
struct AddFoodView: View {
    @Environment(Router.self) private var router
    @Environment(AppEnvironment.self) private var environment

    @State private var slot: Meal.Slot
    @State private var query = ""
    @State private var results: [FoodDatabase.Hit] = []
    @State private var searching = false
    @State private var problem: String?
    @State private var scanning = false
    @State private var missingBarcode: String?
    @FocusState private var searchFocused: Bool

    init(slot: Meal.Slot) {
        _slot = State(initialValue: slot)
    }

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        let mine = (try? environment.store.customFoods(matching: trimmed)) ?? []
        let recent = trimmed.isEmpty ? (try? environment.store.recentMeals(limit: 12)) ?? [] : []
        VStack(spacing: 0) {
            TopBar(title: "Add food", subtitle: slot.title) {
                BackButton()
            } trailing: {
                IconButton(systemImage: "barcode.viewfinder", label: "Scan a barcode") { scanning = true }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SlotPicker(slot: $slot)
                    searchField.padding(.top, 14)
                    HStack(spacing: 8) {
                        PillButton(title: "Scan barcode", systemImage: "barcode.viewfinder", style: .fill) { scanning = true }
                        PillButton(title: "Create food", systemImage: "plus", style: .fill) {
                            router.push(.createFood(slot, barcode: nil))
                        }
                        PillButton(title: "Quick add", systemImage: "number", style: .fill) { router.push(.quickAdd(slot)) }
                    }
                    .padding(.top, 12)

                    if let missingBarcode { notFound(missingBarcode).padding(.top, 18) }
                    if trimmed.isEmpty, let problem {
                        Text(problem).font(.az(14.5)).foregroundStyle(AZColor.muted).padding(.top, 14)
                    }

                    if !mine.isEmpty {
                        SectionHeader(title: "My foods").padding(.top, 26)
                        HairlineStack {
                            ForEach(mine) { custom in foodRow(custom.food) }
                        }
                        .padding(.top, 4)
                    }

                    if trimmed.isEmpty {
                        if !recent.isEmpty {
                            SectionHeader(title: "Logged before", note: "Tap + to add").padding(.top, 26)
                            HairlineStack {
                                ForEach(recent, id: \.meal.id) { recentRow($0) }
                            }
                            .padding(.top, 4)
                        }
                    } else {
                        SectionHeader(title: "Food database", note: searching ? "Searching" : nil).padding(.top, 26)
                        if let problem {
                            Text(problem).font(.az(14.5)).foregroundStyle(AZColor.muted).padding(.top, 8)
                        } else if results.isEmpty && !searching {
                            Text("Nothing found for \"\(trimmed)\". Try other words, or create it.")
                                .font(.az(14.5)).foregroundStyle(AZColor.muted).padding(.top, 8)
                        }
                        HairlineStack {
                            ForEach(results) { hitRow($0) }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .azScreen()
        .task(id: trimmed) { await search() }
        .sheet(isPresented: $scanning) {
            BarcodeScannerSheet { code in
                scanning = false
                Task { await lookUp(code) }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 16, weight: .semibold)).foregroundStyle(AZColor.muted)
            TextField("", text: $query, prompt: Text("Search foods").foregroundStyle(AZColor.faint))
                .font(.az(17, .semibold))
                .focused($searchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(AZColor.muted)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(AZColor.fill, in: .rect(cornerRadius: 16, style: .continuous))
    }

    private func foodRow(_ food: Food) -> some View {
        Button {
            router.push(.food(food, slot))
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(food.name).font(.az(16, .bold)).lineLimit(1)
                    if !food.detail.isEmpty {
                        Text(food.detail).font(.az(13.5)).foregroundStyle(AZColor.muted).lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    let unit = food.units.first ?? .grams
                    Text(Int((food.nutrients(food.defaultAmount(in: unit), unit)?.kcal ?? 0).rounded()).grouped)
                        .font(.az(16, .bold)).monospacedDigit()
                    Text(unit == .grams ? "per 100 g" : "per serving").font(.az(12.5)).foregroundStyle(AZColor.muted)
                }
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(AZColor.faint)
            }
            .frame(minHeight: 60)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func hitRow(_ hit: FoodDatabase.Hit) -> some View {
        Button {
            router.push(.foodHit(hit, slot))
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(hit.name).font(.az(16, .bold)).lineLimit(1)
                    let detail = [hit.brand, hit.serving].compactMap { $0 }.joined(separator: " · ")
                    if !detail.isEmpty {
                        Text(detail).font(.az(13.5)).foregroundStyle(AZColor.muted).lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                if let kcal = hit.kcalPer100g {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(Int(kcal).grouped).font(.az(16, .bold)).monospacedDigit()
                        Text("per 100 g").font(.az(12.5)).foregroundStyle(AZColor.muted)
                    }
                }
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(AZColor.faint)
            }
            .frame(minHeight: 60)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func recentRow(_ recent: RecentMeal) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(recent.meal.name).font(.az(16, .bold)).lineLimit(1)
                Text("\(Int(recent.meal.kcal.rounded()).grouped) kcal · \(DescribeMealView.macros(recent.meal))")
                    .font(.az(13.5)).foregroundStyle(AZColor.muted).monospacedDigit().lineLimit(1)
            }
            Spacer(minLength: 8)
            IconButton(systemImage: "plus", label: "Add \(recent.meal.name) to \(slot.title)", size: 38) { log(recent.meal) }
        }
        .frame(minHeight: 60)
        .accessibilityElement(children: .combine)
    }

    private func notFound(_ code: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Barcode \(code) isn't in the database").font(.az(16, .bold))
            Text("Make it once with the numbers from the label, and scanning it will find it next time.")
                .font(.az(14.5)).foregroundStyle(AZColor.muted).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                PillButton(title: "Create it", style: .dark) { router.push(.createFood(slot, barcode: code)) }
                PillButton(title: "Scan again", style: .card) { scanning = true }
            }
            .padding(.top, 10)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AZColor.fill, in: .rect(cornerRadius: 24, style: .continuous))
    }

    // MARK: Actions

    private func search() async {
        problem = nil
        guard !trimmed.isEmpty else {
            results = []
            return
        }
        // Wait for typing to pause.
        try? await Task.sleep(for: .milliseconds(450))
        guard !Task.isCancelled else { return }
        searching = true
        defer { searching = false }
        do {
            let found = try await environment.foods.search(trimmed)
            guard !Task.isCancelled else { return }
            results = found
        } catch {
            guard !Task.isCancelled else { return }
            results = []
            problem = Self.message(error)
        }
    }

    private func lookUp(_ code: String) async {
        missingBarcode = nil
        if let custom = try? environment.store.customFood(barcode: code) {
            router.push(.food(custom.food, slot))
            return
        }
        searching = true
        defer { searching = false }
        do {
            if let food = try await environment.foods.product(barcode: code) {
                router.push(.food(food, slot))
            } else {
                missingBarcode = code
            }
        } catch {
            problem = Self.message(error)
        }
    }

    /// What went wrong with the food database, in words.
    static func message(_ error: Error) -> String {
        switch error as? FoodDatabase.Problem {
        case .busy: "The food database is busy. Try again in a minute, or create the food yourself."
        case .server: "The food database isn't answering right now. Try again soon, or create the food yourself."
        default: "Couldn't reach the food database. Check your connection, or create the food yourself."
        }
    }

    private func log(_ meal: Meal) {
        guard (try? environment.store.logMeal(meal.again(day: environment.today, slot: slot))) != nil else { return }
        environment.changed()
        router.show(.eat)
    }
}

/// Breakfast, lunch, dinner or snacks.
struct SlotPicker: View {
    @Binding var slot: Meal.Slot

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Meal.Slot.allCases) { option in
                Chip(title: option.title, isOn: option == slot) { slot = option }
            }
        }
    }
}

#Preview {
    NavigationStack { AddFoodView(slot: .lunch) }.environment(Router()).environment(AppEnvironment.preview())
}
