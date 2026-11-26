import AZMath
import AZModel
import AZStore
import SwiftUI

/// Changing your own targets: calories, protein, fat and water, with carbs as what's left. Saving tells Div, which
/// asks why (when you didn't say) and gives its read. It's your call: Div advises, it doesn't change it back.
struct EditTargetsView: View {
    @Environment(Router.self) private var router
    @Environment(AppEnvironment.self) private var environment
    @State private var kcal = ""
    @State private var protein = ""
    @State private var fat = ""
    @State private var water = ""
    @State private var reason = ""
    @State private var problems: [String] = []
    @State private var before: DailyTargets?
    @FocusState private var focus: Field?

    private enum Field: Hashable { case kcal, protein, fat, water, reason }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Change targets") {
                BackButton()
            } trailing: {
                Color.clear.frame(width: 44, height: 44)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    entry("Calories", unit: "kcal", text: $kcal, field: .kcal)
                    HStack(spacing: 10) {
                        entry("Protein", unit: "g", text: $protein, field: .protein)
                        entry("Fat", unit: "g", text: $fat, field: .fat)
                    }
                    carbsRow
                    entry("Water", unit: "L", text: $water, field: .water)

                    VStack(alignment: .leading, spacing: 7) {
                        SectionLabel(text: "Why the change? (optional)")
                        TextField(
                            "", text: $reason,
                            prompt: Text("Cutting for a wedding, more training, feeling flat").foregroundStyle(AZColor.faint),
                            axis: .vertical
                        )
                        .font(.az(16, .medium))
                        .lineLimit(2...4)
                        .focused($focus, equals: .reason)
                        .padding(14)
                        .background(AZColor.fill, in: .rect(cornerRadius: 16, style: .continuous))
                    }
                    .padding(.top, 4)

                    ForEach(problems, id: \.self) { problem in
                        Text(problem).font(.az(14)).foregroundStyle(AZColor.lagging)
                    }

                    Text(
                        environment.bridge.isReady
                            ? "Div will look at the change in chat and tell you what it thinks."
                            : "Your Mac isn't connected, so Div can't weigh in on this right now."
                    )
                    .font(.az(13.5)).foregroundStyle(AZColor.muted).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Save targets") { save() }
                .disabled(values == nil)
                .opacity(values == nil ? 0.4 : 1)
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.bottom, 8)
                .background(AZColor.background)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focus = nil }.font(.az(16, .bold))
            }
        }
        .azScreen()
        .onAppear(perform: fill)
    }

    /// The typed numbers, when all four read as numbers.
    private var values: (kcal: Int, protein: Int, fat: Int, waterMl: Int)? {
        func int(_ text: String) -> Int? { Double(text.replacingOccurrences(of: ",", with: ".")).map { Int($0.rounded()) } }
        guard let kcal = int(kcal), let protein = int(protein), let fat = int(fat),
            let litres = Double(water.replacingOccurrences(of: ",", with: "."))
        else { return nil }
        return (kcal, protein, fat, Int((litres * 1000).rounded()))
    }

    private var carbsRow: some View {
        let carbs = values.map {
            (Double($0.kcal) - Double($0.protein) * MealMath.kcalPerGram.protein - Double($0.fat) * MealMath.kcalPerGram.fat)
                / MealMath.kcalPerGram.carbs
        }
        return HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Carbs").font(.az(15.5, .bold))
                Text("What's left of the calories").font(.az(13)).foregroundStyle(AZColor.muted)
            }
            Spacer()
            Text(carbs.map { $0 < 0 ? "none left" : "\(Int($0.rounded())) g" } ?? "-")
                .font(.az(17, .heavy)).monospacedDigit()
                .foregroundStyle((carbs ?? 0) < 0 ? AZColor.lagging : AZColor.ink)
        }
        .padding(.horizontal, 16)
        .frame(height: 60)
        .background(AZColor.fill, in: .rect(cornerRadius: 16, style: .continuous))
    }

    private func entry(_ label: String, unit: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionLabel(text: label)
            HStack(spacing: 6) {
                TextField("", text: text, prompt: Text("0").foregroundStyle(AZColor.faint))
                    .keyboardType(.decimalPad)
                    .font(.az(18, .heavy))
                    .monospacedDigit()
                    .focused($focus, equals: field)
                    .onChange(of: text.wrappedValue) { problems = [] }
                Text(unit).font(.az(15, .bold)).foregroundStyle(AZColor.muted)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(AZColor.fill, in: .rect(cornerRadius: 16, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fill() {
        guard before == nil, let current = try? environment.store.dailyTargets(on: environment.today) else { return }
        before = current
        kcal = "\(current.kcal)"
        protein = current.proteinG.map { "\($0)" } ?? ""
        fat = current.fatG.map { "\($0)" } ?? ""
        water = Self.litres(current.waterMl)
    }

    private func save() {
        guard let values else { return }
        do {
            try environment.store.setOwnTargets(
                today: environment.today, kcal: values.kcal, proteinG: values.protein, fatG: values.fat, waterMl: values.waterMl)
        } catch let problem as TargetProblem {
            problems = problem.problems
            return
        } catch {
            problems = ["Couldn't save them: \(error.localizedDescription)"]
            return
        }
        environment.changed()
        guard environment.bridge.isReady, let message = message(values) else {
            router.pop()
            return
        }
        // Div's take, in chat. The message is the person's own words about what they did.
        router.replaceTop(with: .chat)
        Task { await environment.chat.send(message) }
    }

    /// "I changed my targets myself: calories 2,300 to 2,100 kcal, ... Why: .... What do you think?"
    private func message(_ v: (kcal: Int, protein: Int, fat: Int, waterMl: Int)) -> String? {
        var parts: [String] = []
        func add(_ name: String, _ old: Int?, _ new: Int, _ unit: String) {
            guard old != new else { return }
            parts.append(old.map { "\(name) \($0.grouped) to \(new.grouped) \(unit)" } ?? "\(name) to \(new.grouped) \(unit)")
        }
        add("calories", before?.kcal, v.kcal, "kcal")
        add("protein", before?.proteinG, v.protein, "g")
        add("fat", before?.fatG, v.fat, "g")
        if before?.waterMl != v.waterMl {
            parts.append("water \(before.map { Self.litres($0.waterMl) + " to " } ?? "to ")\(Self.litres(v.waterMl)) L")
        }
        guard !parts.isEmpty else { return nil }
        let why = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        return "I changed my daily targets myself: \(parts.joined(separator: ", ")). "
            + (why.isEmpty ? "I haven't said why yet. " : "Why: \(why). ") + "What do you think?"
    }

    /// 2.75, 3
    static func litres(_ ml: Int) -> String {
        let l = Double(ml) / 1000
        return l.rounded() == l ? "\(Int(l))" : String(format: "%g", (l * 100).rounded() / 100)
    }
}

#Preview {
    NavigationStack { EditTargetsView() }.environment(Router()).environment(AppEnvironment.preview())
}
