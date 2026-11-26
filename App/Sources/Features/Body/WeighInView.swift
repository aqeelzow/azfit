import AZModel
import AZStore
import SwiftUI

/// Weighing in: one number in the person's units (stone and pounds for British) and when it was weighed (now by
/// default), or read from Apple Health once connected. The trend and the Sunday calorie check read these.
struct WeighInView: View {
    @Environment(Router.self) private var router
    @Environment(AppEnvironment.self) private var environment
    @State private var main = ""
    @State private var pounds = ""
    @State private var problem: String?
    @State private var weighedAt = Date.now
    @FocusState private var focus: Field?

    private enum Field: Hashable { case main, pounds }

    var body: some View {
        let units = environment.units
        let latest = try? environment.store.latestWeighIn()
        let weight = try? environment.store.weight(today: environment.today)
        VStack(spacing: 0) {
            TopBar(title: "Weigh in", subtitle: AppEnvironment.caption(environment.today)) {
                BackButton()
            } trailing: {
                Color.clear.frame(width: 44, height: 44)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        number($main, prompt: latest.map { units.bodyWeightFields($0.kg).main } ?? "0", field: .main)
                        unit(units.bodyWeight == .stone ? "st" : units.bodyWeight.rawValue)
                        if units.bodyWeight == .stone {
                            number($pounds, prompt: latest.map { units.bodyWeightFields($0.kg).pounds } ?? "0", field: .pounds)
                                .padding(.leading, 10)
                            unit("lb")
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 22)
                    .frame(height: 112)
                    .background(AZColor.fill, in: .rect(cornerRadius: 28, style: .continuous))
                    .contentShape(.rect)
                    .onTapGesture { focus = focus ?? .main }
                    Text(problem ?? "Same time each day is best: after waking, before eating.")
                        .font(.az(14)).foregroundStyle(AZColor.muted)
                        .padding(.top, 12)
                    HStack {
                        Text("Weighed").font(.az(16, .bold))
                        Spacer()
                        DatePicker("Weighed", selection: $weighedAt, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .tint(AZColor.accent)
                    }
                    .frame(minHeight: 60)
                    .padding(.top, 14)
                    healthRow.padding(.top, 4)
                    if let latest {
                        SectionHeader(title: "Last time").padding(.top, 30)
                        HairlineStack {
                            row("Weighed", units.bodyWeight(latest.kg), note: AppEnvironment.caption(latest.day))
                            if let weight, let change = weight.changeKg, weight.days > 0 {
                                row("Trend", Self.signed(change, units), note: "over \(weight.days) days")
                            }
                        }
                        .padding(.top, 6)
                    }
                }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Save weigh-in") { save() }
                .disabled(typedKg == nil)
                .opacity(typedKg == nil ? 0.4 : 1)
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.bottom, 8)
                .background(AZColor.background)
        }
        .azScreen()
        .onAppear { focus = .main }
    }

    /// Apple Health: connect it, or say it's reading from it.
    @ViewBuilder
    private var healthRow: some View {
        let health = environment.health
        if health.isAvailable {
            HStack(spacing: 12) {
                IconTile(systemImage: "heart.fill", size: 40, foreground: AZColor.ink, background: AZColor.fill)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Apple Health").font(.az(16, .bold))
                    Text(healthNote(health)).font(.az(13.5)).foregroundStyle(AZColor.muted).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if health.isConnected {
                    PillButton(title: health.isSyncing ? "Reading" : "Sync", style: .fill) { environment.syncHealth(allHistory: true) }
                        .disabled(health.isSyncing)
                } else {
                    PillButton(title: "Connect", style: .dark) { environment.connectHealth() }
                }
            }
            .frame(minHeight: 64)
        }
    }

    private func healthNote(_ health: HealthWeights) -> String {
        if let problem = health.problem { return problem }
        guard health.isConnected else { return "Bring in weigh-ins from a smart scale or other apps" }
        if let added = health.lastAdded {
            return added == 0 ? "Up to date. New weights come in when you open the app" : "Brought in \(added) new"
        }
        return "Weights come in when you open the app"
    }

    private var typedKg: Double? { environment.units.bodyWeightKg(typed: main, pounds: pounds) }

    private func number(_ text: Binding<String>, prompt: String, field: Field) -> some View {
        TextField("", text: text, prompt: Text(prompt).foregroundStyle(AZColor.faint))
            .font(.az(56, .heavy))
            .tracking(-2)
            .monospacedDigit()
            .keyboardType(.decimalPad)
            .focused($focus, equals: field)
            .fixedSize()
            .onChange(of: text.wrappedValue) { problem = nil }
    }

    private func unit(_ text: String) -> some View {
        Text(text).font(.az(20, .bold)).foregroundStyle(AZColor.muted)
    }

    private func row(_ title: String, _ value: String, note: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.az(16, .bold))
                Text(note).font(.az(14)).foregroundStyle(AZColor.muted)
            }
            Spacer()
            Text(value).font(.az(16, .bold)).monospacedDigit()
        }
        .frame(minHeight: 60)
    }

    private func save() {
        guard let kg = typedKg else {
            problem = "That doesn't look like a body weight."
            return
        }
        do {
            try environment.store.logWeighIn(kg: kg, day: Day.string(weighedAt), at: weighedAt)
            environment.changed()
            router.pop()
            if router.path.last != .progress { router.push(.progress) }
        } catch {
            problem = "Couldn't save it: \(error.localizedDescription)"
        }
    }

    /// "-1.2 lb", "+0.4 kg"; a stone person sees pounds for small changes.
    static func signed(_ kg: Double, _ units: UnitSystem) -> String {
        let value = units.bodyWeight == .kg ? kg : kg * UnitSystem.poundsPerKg
        let unit = units.bodyWeight == .kg ? "kg" : "lb"
        let text = String(format: "%.1f", abs(value))
        return text == "0.0" ? "0 \(unit)" : "\(value < 0 ? "-" : "+")\(text) \(unit)"
    }
}

#Preview {
    NavigationStack { WeighInView() }.environment(Router()).environment(AppEnvironment.preview())
}
