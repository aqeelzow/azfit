import AZModel
import AZStore
import AZSync
import SwiftUI

/// Div's estimate of a meal photo, with its uncertainty. Div asks the one question that narrows it most, and the
/// answer, or the meal's weight, tightens the range. The totals are the bridge's sum of the items (D-010), and
/// nothing is saved until Log (D-032). Design: design/source/src/Meal.html
struct MealView: View {
    let photo: MealPhoto

    @Environment(Router.self) private var router
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var image: CGImage?
    @State private var phase = Phase.looking
    /// The estimate on screen, and the one before the last answer, for Undo.
    @State private var current: MealEstimateReply?
    @State private var before: MealEstimateReply?
    /// How each estimate came about, for the ladder.
    @State private var answered: String?
    @State private var weighedG: Double?
    @State private var draft = ""
    @State private var grams = ""
    @State private var isWeighing = false
    /// Why the last answer or weight didn't go through; the estimate on screen stays.
    @State private var problem: String?
    @FocusState private var focus: Field?

    private enum Phase: Equatable {
        case looking
        case ready
        /// Asking again after an answer or a weight; the last estimate stays on screen.
        case revising
        case failed(String)
    }

    private enum Field: Hashable { case answer, grams }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(current?.estimate.mealName ?? "Your meal").font(.az(22, .heavy)).tracking(-0.44)
                        Text(when).font(.az(14)).foregroundStyle(AZColor.muted)
                    }
                    .padding(.top, 18)
                    if let current {
                        estimate(current).padding(.top, 14)
                        ladder.padding(.top, 20)
                        note(current).padding(.top, 18).animation(.snappy(duration: 0.22), value: answered)
                        breakdown(current).padding(.top, 18)
                    } else if case .failed(let reason) = phase {
                        failed(reason).padding(.top, 18)
                    } else {
                        DivNote(
                            title: "Looking at your photo", message: "Div is working out what's on the plate. Usually 10 to 20 seconds."
                        )
                        .padding(.top, 18)
                    }
                }
                .padding(.horizontal, AZSpacing.gutter)
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .ignoresSafeArea(edges: .top)
        .safeAreaInset(edge: .bottom) {
            if let current {
                PrimaryButton(title: "Log \(current.totals.kcal.grouped) kcal") { log(current) }
                    .disabled(phase == .revising)
                    .opacity(phase == .revising ? 0.4 : 1)
                    .padding(.horizontal, AZSpacing.gutter)
                    .padding(.bottom, 8)
                    .background(AZColor.background)
            }
        }
        .azScreen()
        .task {
            image = await Task.detached { PhotoPrep.image(from: photo.jpeg, maxPixels: 900) }.value
            if current == nil { await estimate() }
        }
    }

    /// "Lunch · 1:12 PM", with the day when it isn't today.
    private var when: String {
        let time = photo.takenAt.formatted(date: .omitted, time: .shortened)
        let day = Calendar.current.isDateInToday(photo.takenAt) ? "" : "\(SnapMealView.dayLabel(photo.takenAt)) · "
        return "\(Meal.mealTime(at: photo.takenAt)) · \(day)\(time)"
    }

    // MARK: Header

    private var header: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1).resizable().scaledToFill()
            } else {
                AZColor.fill
            }
        }
        .frame(height: 196)
        .frame(maxWidth: .infinity)
        .clipped()
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [AZColor.Camera.shade.opacity(0.45), AZColor.Camera.shade.opacity(0)], startPoint: .top, endPoint: .bottom
            )
            .frame(height: 120)
        }
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 32, bottomTrailingRadius: 32, style: .continuous))
        .overlay(alignment: .bottom) {
            HStack {
                darkButton("chevron.left", "Back") { dismiss() }
                Spacer()
                darkButton("ellipsis", "Ask Div about this meal") { router.push(.chat) }
            }
            .padding(.horizontal, AZSpacing.gutter)
            .padding(.bottom, 196 - 56 - 44)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Meal photo")
    }

    private func darkButton(_ systemImage: String, _ label: String, action: @escaping () -> Void) -> some View {
        IconButton(systemImage: systemImage, label: label, background: AZColor.Camera.scrim, foreground: .white, action: action)
    }

    // MARK: Estimate

    private func estimate(_ reply: MealEstimateReply) -> some View {
        let kcal = reply.totals.kcal
        let low = Int(reply.estimate.kcalLow.rounded())
        let high = Int(reply.estimate.kcalHigh.rounded())
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(kcal.grouped).font(.az(48, .heavy)).tracking(-1.9).contentTransition(.numericText(value: Double(kcal)))
                    Text(" kcal").font(.az(16, .semibold)).foregroundStyle(AZColor.muted)
                }
                Spacer()
                Text("± \(Self.percent(reply))%")
                    .font(.az(14, .bold)).foregroundStyle(AZColor.divInk)
                    .padding(.horizontal, 12).frame(height: 30)
                    .background(AZColor.divTint, in: .capsule)
                    .padding(.bottom, 6)
            }
            .monospacedDigit()
            RangeBar(low: low, high: high, value: kcal).padding(.top, 14)
            Text("Likely \(low.grouped) to \(high.grouped) kcal").font(.az(13, .semibold)).foregroundStyle(AZColor.muted).monospacedDigit()
                .padding(.top, 7)
        }
        .animation(.snappy(duration: 0.3), value: kcal)
    }

    /// How sure the estimate is: from the photo, then your answer, then weighing it.
    private var ladder: some View {
        HStack(spacing: 8) {
            rung("Photo", done: true)
            rung("Your answer", done: answered != nil)
            rung("Weighed", done: weighedG != nil)
        }
    }

    private func rung(_ label: String, done: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Capsule().fill(done ? AZColor.accent : AZColor.track).frame(height: 6)
            Text(label).font(.az(13, .semibold)).foregroundStyle(done ? AZColor.ink : AZColor.faint).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Div's question

    private func note(_ reply: MealEstimateReply) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            question(reply)
            if let problem {
                Text(problem).font(.az(14)).foregroundStyle(AZColor.muted).fixedSize(horizontal: false, vertical: true).padding(.top, 10)
            }
        }
    }

    @ViewBuilder
    private func question(_ reply: MealEstimateReply) -> some View {
        if phase == .revising {
            DivNote(title: "Updating the estimate", message: "Div is redoing the numbers with what you told it.")
        } else if let answered, let before {
            HStack(alignment: .top, spacing: 12) {
                DivAvatar(size: 36, mood: .proud)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Updated to \(reply.totals.kcal.grouped)").font(.az(15, .bold))
                        if before.totals.kcal != reply.totals.kcal { WasValue(value: before.totals.kcal.grouped).font(.az(15)) }
                    }
                    .monospacedDigit()
                    Text(answered).font(.az(14)).foregroundStyle(AZColor.divMuted).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        PillButton(title: "Undo", systemImage: "arrow.uturn.backward") { undo() }
                        if weighedG == nil { PillButton(title: "Weigh it", systemImage: "scalemass") { startWeighing() } }
                    }
                    .padding(.top, 8)
                    if isWeighing { weighField.padding(.top, 10) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 16))
            .background(AZColor.divTint, in: .rect(cornerRadius: 24, style: .continuous))
            .transition(.opacity)
        } else if !reply.estimate.followUpQuestion.isEmpty {
            DivNote(title: reply.estimate.followUpQuestion, message: reply.estimate.assumptions.first ?? "Your answer narrows the range.")
            questionField(reply.estimate.followUpQuestion)
        } else if weighedG == nil {
            DivNote(
                title: "Confident enough to log", message: reply.estimate.assumptions.first ?? "Weigh it if you want the range tighter.",
                tone: .settled, mood: .side
            ) {
                PillButton(title: "Weigh it", systemImage: "scalemass", style: .fill) { startWeighing() }
            }
            if isWeighing { weighField.padding(.top, 10) }
        }
    }

    private func questionField(_ question: String) -> some View {
        HStack(spacing: 8) {
            TextField("", text: $draft, prompt: Text("Your answer").foregroundStyle(AZColor.faint))
                .font(.az(15, .medium))
                .focused($focus, equals: .answer)
                .submitLabel(.send)
                .onSubmit { Task { await answer(question) } }
                .padding(.horizontal, 16)
                .frame(height: 46)
                .background(AZColor.fill, in: .capsule)
            PillButton(title: "Send", style: .dark, height: 46) { Task { await answer(question) } }
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.top, 10)
    }

    private var weighField: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                TextField("", text: $grams, prompt: Text("Weight").foregroundStyle(AZColor.faint))
                    .font(.az(15, .medium))
                    .monospacedDigit()
                    .keyboardType(.numberPad)
                    .focused($focus, equals: .grams)
                Text("g").font(.az(15, .semibold)).foregroundStyle(AZColor.muted)
            }
            .padding(.horizontal, 16)
            .frame(height: 46)
            .background(AZColor.card, in: .capsule)
            PillButton(title: "Use it", style: .dark, height: 46) { Task { await weigh() } }
                .disabled(Self.grams(grams) == nil)
        }
    }

    // MARK: Breakdown

    private func breakdown(_ reply: MealEstimateReply) -> some View {
        let old = Set((before?.estimate.items ?? reply.estimate.items).map { $0.name.lowercased() })
        return VStack(alignment: .leading, spacing: 0) {
            HairlineStack {
                ForEach(Array(reply.estimate.items.enumerated()), id: \.offset) { _, item in
                    row(item, isNew: answered != nil && !old.contains(item.name.lowercased()))
                }
            }
            HStack(spacing: 18) {
                macro("Protein", reply.totals.proteinG)
                macro("Carbs", reply.totals.carbsG)
                macro("Fat", reply.totals.fatG)
            }
            .padding(.top, 14)
            ForEach(reply.warnings + reply.estimate.assumptions.dropFirst(), id: \.self) { line in
                Text(line).font(.az(13)).foregroundStyle(AZColor.muted).fixedSize(horizontal: false, vertical: true).padding(.top, 8)
            }
        }
    }

    private func row(_ item: MealItem, isNew: Bool) -> some View {
        HStack(spacing: 0) {
            Text(item.name).fontWeight(.semibold).foregroundStyle(isNew ? AZColor.divInk : AZColor.ink).lineLimit(1)
            Spacer(minLength: 8)
            Text(item.portion).foregroundStyle(AZColor.muted).lineLimit(1).frame(maxWidth: 110, alignment: .trailing)
            Text("\(Int(item.kcal.rounded()))").fontWeight(.bold).foregroundStyle(isNew ? AZColor.divInk : AZColor.ink)
                .frame(width: 52, alignment: .trailing)
        }
        .font(.az(15))
        .monospacedDigit()
        .frame(height: 36)
    }

    private func macro(_ name: String, _ grams: Double) -> some View {
        HStack(spacing: 4) {
            Text(name).foregroundStyle(AZColor.muted)
            Text("\(Int(grams.rounded()))g").fontWeight(.bold)
        }
        .font(.az(14))
        .monospacedDigit()
    }

    private func failed(_ reason: String) -> some View {
        DivNote(title: "Couldn't estimate this one", message: reason, tone: .settled, mood: .side) {
            if environment.bridge.isReady {
                PillButton(title: "Try again", systemImage: "arrow.clockwise", style: .fill) { Task { await estimate() } }
            } else {
                PillButton(title: "Connect your Mac", style: .fill) { router.push(.connectMac) }
            }
            PillButton(title: "Describe it", style: .fill) {
                router.pop()
                router.push(.describeMeal)
            }
        }
    }

    // MARK: Asking Div

    private func request(note: String? = nil, grams: Double? = nil) -> MealPhotoRequest {
        let recent = (try? environment.store.recentMeals()) ?? []
        return MealPhotoRequest(
            photo: photo.jpeg, mediaType: .jpeg, note: note, foodWeightG: grams, mealTime: Meal.mealTime(at: photo.takenAt),
            similarMeals: recent.isEmpty ? nil : recent.map(\.similar))
    }

    private func estimate() async {
        guard environment.bridge.isReady else {
            phase = .failed(environment.bridge.offlineReason ?? "Div runs on your Mac. Connect it to estimate photos.")
            return
        }
        phase = .looking
        if let reply = await ask(.estimateMeal(request())) {
            current = reply
            phase = .ready
        }
    }

    private func answer(_ question: String) async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let current, !text.isEmpty, phase == .ready else { return }
        focus = nil
        problem = nil
        phase = .revising
        if let reply = await ask(.reviseMeal(MealRevisionRequest(previous: current.estimate, question: question, answer: text))) {
            before = current
            self.current = reply
            answered = "You said: \(text)"
            draft = ""
        }
        phase = .ready
    }

    private func weigh() async {
        guard let weight = Self.grams(grams), phase == .ready, let current else { return }
        focus = nil
        isWeighing = false
        problem = nil
        phase = .revising
        let note = answered.map { "\($0). The whole meal weighs \(Int(weight)) g." }
        if let reply = await ask(.estimateMeal(request(note: note, grams: weight))) {
            if before == nil { before = current }
            self.current = reply
            weighedG = weight
            answered = [answered, "Weighed at \(Int(weight)) g."].compactMap { $0 }.joined(separator: " ")
        }
        phase = .ready
    }

    /// Sends a job to Div. On failure keeps what's on screen and says why.
    private func ask(_ job: Job) async -> MealEstimateReply? {
        do {
            switch try await environment.bridge.ask(job) {
            case .mealEstimated(let reply): return reply
            case .failed(let reason): fail(reason)
            default: fail("The Mac answered something unexpected. Update AZfit Bridge and try again.")
            }
        } catch {
            fail(environment.bridge.offlineReason ?? error.localizedDescription)
        }
        return nil
    }

    private func fail(_ reason: String) {
        if current == nil { phase = .failed(reason) } else { problem = reason }
    }

    private func startWeighing() {
        isWeighing = true
        focus = .grams
    }

    private func undo() {
        guard let before else { return }
        current = before
        self.before = nil
        answered = nil
        weighedG = nil
    }

    private func log(_ reply: MealEstimateReply) {
        let meal = Meal(
            day: Day.string(photo.takenAt), at: photo.takenAt, name: reply.estimate.mealName, kcal: Double(reply.totals.kcal),
            kcalLow: reply.estimate.kcalLow, kcalHigh: reply.estimate.kcalHigh, proteinG: reply.totals.proteinG,
            carbsG: reply.totals.carbsG, fatG: reply.totals.fatG, source: .photo)
        do {
            try environment.store.logMeal(meal)
            environment.changed()
            router.show(.eat)
        } catch {
            fail("Couldn't save it: \(error.localizedDescription)")
        }
    }

    // MARK: Helpers

    /// Half the range as a share of the estimate: ±18%.
    static func percent(_ reply: MealEstimateReply) -> Int {
        guard reply.totals.kcal > 0 else { return 0 }
        return Int(((reply.estimate.kcalHigh - reply.estimate.kcalLow) / 2 / Double(reply.totals.kcal) * 100).rounded())
    }

    private static func grams(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces)).flatMap { $0 > 0 && $0 < 5000 ? $0 : nil }
    }
}

/// The likely range as a soft band, with a tick at the estimate. The track runs from 60% to 140% of the estimate.
private struct RangeBar: View {
    var low: Int
    var high: Int
    var value: Int

    var body: some View {
        GeometryReader { geo in
            let start = min(Double(low), Double(value) * 0.6)
            let span = max(max(Double(high), Double(value) * 1.4) - start, 1)
            let x = { (kcal: Int) in geo.size.width * CGFloat((Double(kcal) - start) / span) }
            ZStack(alignment: .leading) {
                Capsule().fill(AZColor.track)
                Capsule().fill(AZColor.accentSoft.opacity(0.55)).frame(width: max(x(high) - x(low), 8)).offset(x: x(low))
                RoundedRectangle(cornerRadius: 2).fill(AZColor.accent).frame(width: 4, height: 16).offset(x: x(value) - 2)
            }
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityLabel("Likely \(low) to \(high) kcal")
    }
}

#Preview {
    NavigationStack { MealView(photo: MealPhoto(jpeg: Data(), takenAt: .now)) }
        .environment(Router()).environment(AppEnvironment.preview())
}
