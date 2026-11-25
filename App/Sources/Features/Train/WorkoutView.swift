import AZModel
import AZStore
import SwiftUI

/// The live session: today's planned exercises one at a time. Each set is logged as lifted, with last time's numbers
/// beside it, and a rest timer starts after every set. Design: design/source/src/Workout.html
struct WorkoutView: View {
    @Environment(Router.self) private var router
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var session: SessionPreview?
    @State private var workout: Workout?
    @State private var logged: [LoggedSet] = []
    @State private var previous: [String: [LoggedSet]] = [:]
    @State private var index = 0
    @State private var load = ""
    @State private var reps = ""
    @State private var restEnds: Date?
    @State private var restLength: TimeInterval = 150

    private var store: AZStore { environment.store }
    private var units: UnitSystem { environment.units }

    var body: some View {
        Group {
            if let session, let workout {
                live(session, workout)
            } else {
                VStack(spacing: 0) {
                    TopBar(title: "Workout") {
                        IconButton(systemImage: "chevron.down", label: "Close") { dismiss() }
                    } trailing: {
                        Color.clear.frame(width: 44, height: 44)
                    }
                    Spacer()
                    Text("No session planned today.").font(.az(17, .semibold)).foregroundStyle(AZColor.muted)
                    Spacer()
                }
            }
        }
        .azScreen()
        .task { start() }
    }

    private func start() {
        guard workout == nil, let today = try? store.todaySession(today: environment.today),
            let started = try? store.startWorkout(today.session, today: environment.today)
        else { return }
        session = today
        workout = started
        logged = (try? store.sets(in: started.id)) ?? []
        previous = (try? store.previousSets(exerciseIDs: today.lines.map(\.exerciseID), before: environment.today)) ?? [:]
        // Resume at the first exercise that still has sets to do.
        index = today.lines.firstIndex { line in logged.filter { $0.exerciseID == line.exerciseID }.count < line.sets } ?? 0
        fillInputs()
        environment.changed()
    }

    // MARK: Live

    private func live(_ session: SessionPreview, _ workout: Workout) -> some View {
        let line = session.lines[index]
        let done = logged.filter { $0.exerciseID == line.exerciseID }
        let totalSets = session.lines.reduce(0) { $0 + $1.sets }
        return VStack(spacing: 0) {
            TopBar {
                IconButton(systemImage: "chevron.down", label: "Minimize") { dismiss() }
            } center: {
                VStack(spacing: 0) {
                    Text(session.session.name).font(.az(17, .heavy))
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(Self.clock(context.date.timeIntervalSince(workout.startedAt)))
                            .font(.az(14)).foregroundStyle(AZColor.muted).monospacedDigit()
                    }
                }
            } trailing: {
                PillButton(title: "Finish", style: .accent, height: 44) { finish(workout) }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            ForEach(session.lines.indices, id: \.self) { i in
                                let l = session.lines[i]
                                let count = logged.filter { $0.exerciseID == l.exerciseID }.count
                                MeterBar(value: Double(min(count, l.sets)) / Double(max(l.sets, 1)), height: 6)
                            }
                        }
                        Text("\(logged.count) of \(totalSets) sets").font(.az(13.5, .semibold)).foregroundStyle(AZColor.muted)
                            .monospacedDigit()
                    }
                    .padding(.top, 18)

                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Exercise \(index + 1) of \(session.lines.count)").font(.az(13, .bold)).foregroundStyle(AZColor.accent)
                            HStack(spacing: 6) {
                                Text(line.name).font(.az(28, .heavy)).tracking(-0.56).lineLimit(2)
                                if line.swappedFrom != nil { DivMark(size: 20) }
                            }
                            Text("\(line.prescription) · rest \(Self.clock(rest(for: line)))").font(.az(14.5))
                                .foregroundStyle(AZColor.muted)
                        }
                        Spacer()
                    }
                    .padding(.top, 20)

                    setTable(line, done: done).padding(.horizontal, -10).padding(.top, 20)

                    HStack(spacing: 10) {
                        if index > 0 {
                            PillButton(title: "Previous", systemImage: "chevron.left", style: .fill) { move(-1) }
                        }
                        Spacer()
                        if index < session.lines.count - 1 {
                            PillButton(title: "Next exercise", style: .fill) { move(1) }
                        }
                    }
                    .padding(.top, 18)

                    if index < session.lines.count - 1 {
                        let next = session.lines[index + 1]
                        SectionLabel(text: "Up next").padding(.top, 22)
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 5) {
                                Text(next.name).font(.az(16, .bold))
                                if next.swappedFrom != nil { DivMark(size: 16) }
                            }
                            Text(next.swappedFrom.map { "Swapped in for \($0.lowercased()) · \(next.prescription)" } ?? next.prescription)
                                .font(.az(14)).foregroundStyle(AZColor.muted)
                        }
                        .frame(minHeight: 56)
                    }
                }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .overlay(alignment: .bottom) {
            if let restEnds { restBar(restEnds) }
        }
    }

    // MARK: Sets

    private func setTable(_ line: SessionPreview.Line, done: [LoggedSet]) -> some View {
        let last = previous[line.exerciseID] ?? []
        let unit = units.liftLoad == .lb ? "lb" : "kg"
        return VStack(spacing: 4) {
            SetRow(set: "Set", previous: "Previous", target: "Target", unit: unit, state: .header)
            ForEach(Array(done.enumerated()), id: \.element.id) { i, set in
                SetRow(
                    set: "\(i + 1)", previous: previousText(last, i), target: line.reps,
                    kg: Self.number(units.loadValue(set.loadKg)), reps: "\(set.reps)", state: .done,
                    missedReps: set.reps < line.repMin)
            }
            if done.count < line.sets {
                SetRow(
                    set: "\(done.count + 1)", previous: previousText(last, done.count), target: line.reps,
                    load: $load, repsText: $reps, unit: unit, state: .current
                ) { log(line, position: done.count) }
                ForEach(done.count + 1..<line.sets, id: \.self) { i in
                    SetRow(set: "\(i + 1)", previous: previousText(last, i), target: line.reps, state: .upcoming)
                }
            } else {
                Text("All \(line.sets) sets done.").font(.az(14.5)).foregroundStyle(AZColor.muted).padding(.horizontal, 10)
                    .padding(.top, 6)
            }
        }
    }

    private func previousText(_ sets: [LoggedSet], _ i: Int) -> String {
        guard i < sets.count else { return "-" }
        return "\(Self.number(units.loadValue(sets[i].loadKg))) × \(sets[i].reps)"
    }

    /// Starts the inputs from this workout's last set, else last time's matching set, else empty.
    private func fillInputs() {
        guard let session else { return }
        let line = session.lines[index]
        let done = logged.filter { $0.exerciseID == line.exerciseID }
        let source = done.last ?? previous[line.exerciseID]?[safe: done.count] ?? previous[line.exerciseID]?.last
        load = source.map { Self.number(units.loadValue($0.loadKg)) } ?? ""
        reps = source.map { "\($0.reps)" } ?? "\(line.repMax)"
    }

    private func log(_ line: SessionPreview.Line, position: Int) {
        guard let workout, let value = Double(load.replacingOccurrences(of: ",", with: ".")), let count = Int(reps), count > 0
        else { return }
        let set = LoggedSet(
            workoutID: workout.id, exerciseID: line.exerciseID, position: logged.count, loadKg: units.loadKg(value), reps: count,
            rir: nil)
        do {
            try store.logSet(set)
        } catch {
            return
        }
        logged.append(set)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        restLength = rest(for: line)
        restEnds = .now.addingTimeInterval(restLength)
        if logged.filter({ $0.exerciseID == line.exerciseID }).count >= line.sets, index < (session?.lines.count ?? 1) - 1 {
            index += 1
        }
        fillInputs()
        environment.changed()
    }

    private func move(_ delta: Int) {
        index = max(0, min((session?.lines.count ?? 1) - 1, index + delta))
        fillInputs()
    }

    private func finish(_ workout: Workout) {
        try? store.finishWorkout(workout.id)
        environment.changed()
        environment.reviewFinishedWorkouts()
        dismiss()
    }

    /// Heavy lifts (fatigue 3 and up) rest 2:30, the rest 1:30.
    private func rest(for line: SessionPreview.Line) -> TimeInterval {
        (Library.standard.exercise(line.exerciseID)?.fatigueCost ?? 3) >= 3 ? 150 : 90
    }

    // MARK: Rest timer

    private func restBar(_ ends: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = max(0, ends.timeIntervalSince(context.date))
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(left == 0 ? "Rest done" : "Rest").font(.az(13)).foregroundStyle(.white.opacity(0.62))
                    Text(Self.clock(left)).font(.az(24, .heavy)).monospacedDigit()
                }
                Spacer()
                Button("+15s") {
                    restEnds = ends.addingTimeInterval(15)
                    restLength += 15
                }
                .font(.az(14, .bold))
                .padding(.horizontal, 18).frame(height: 48)
                .background(AZColor.rest2, in: .rect(cornerRadius: 16, style: .continuous))
                Button(left == 0 ? "Close" : "Skip") { restEnds = nil }
                    .font(.az(14, .bold))
                    .foregroundStyle(AZColor.Camera.tagInk)
                    .padding(.horizontal, 20).frame(height: 48)
                    .background(.white, in: .rect(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .padding(.leading, 22)
            .padding(.trailing, 10)
            .frame(height: 72)
            .background(alignment: .topLeading) {
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        AZColor.rest
                        AZColor.accent.frame(width: geo.size.width * (1 - left / max(restLength, 1)), height: 4)
                    }
                }
            }
            .clipShape(.rect(cornerRadius: 24, style: .continuous))
            .environment(\.colorScheme, .light)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
    }

    // MARK: Formatting

    /// "1:34" or "1:02:05"
    static func clock(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.down))
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
    }

    /// "82.5" or "80"
    static func number(_ value: Double) -> String {
        let step = (value / 0.25).rounded() * 0.25
        return step.formatted(.number.precision(.fractionLength(0...2)))
    }
}

extension Array {
    fileprivate subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

/// One row of the set table: set number, last time, the target, weight, reps and the check.
private struct SetRow: View {
    enum State { case header, done, current, upcoming }

    var set: String
    var previous: String
    var target: String
    var kg = ""
    var reps = ""
    var load: Binding<String>?
    var repsText: Binding<String>?
    var unit = "kg"
    var state: State
    var missedReps = false
    var onLog: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            Text(set).fontWeight(state == .header ? .semibold : .bold).frame(width: 28, alignment: .leading)
            Text(previous).foregroundStyle(AZColor.faint).frame(maxWidth: .infinity, alignment: .leading).lineLimit(1)
            Text(target).foregroundStyle(state == .header ? AZColor.faint : AZColor.muted)
                .frame(maxWidth: .infinity, alignment: .leading).lineLimit(1)
            if state == .header {
                Text(unit).frame(width: 60)
                Text("Reps").frame(width: 50)
                Color.clear.frame(width: 36, height: 1)
            } else if state == .current, let load, let repsText {
                input(load, keyboard: .decimalPad, label: "Weight in \(unit)").frame(width: 60)
                input(repsText, keyboard: .numberPad, label: "Reps").frame(width: 50)
                Button(action: onLog) {
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy)).foregroundStyle(.white)
                        .frame(width: 34, height: 34).background(AZColor.accent, in: .rect(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Log set \(set)")
                .frame(width: 36)
            } else {
                field(kg).frame(width: 60)
                field(reps, color: missedReps ? AZColor.accent : AZColor.ink).frame(width: 50)
                check.frame(width: 36)
            }
        }
        .font(state == .header ? .az(13, .semibold) : .az(15.5))
        .foregroundStyle(state == .header ? AZColor.faint : AZColor.ink)
        .monospacedDigit()
        .padding(.horizontal, 10)
        .frame(height: state == .header ? 28 : 52)
        .background(state == .current ? AZColor.fill : .clear, in: .rect(cornerRadius: 16, style: .continuous))
    }

    private func input(_ text: Binding<String>, keyboard: UIKeyboardType, label: String) -> some View {
        TextField("", text: text)
            .keyboardType(keyboard)
            .multilineTextAlignment(.center)
            .fontWeight(.bold)
            .frame(height: 38)
            .background(AZColor.card, in: .rect(cornerRadius: 12, style: .continuous))
            .accessibilityLabel(label)
    }

    private func field(_ value: String, color: Color = AZColor.ink) -> some View {
        Text(value.isEmpty ? " " : value)
            .fontWeight(.bold)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(state == .upcoming ? Color.clear : AZColor.fill, in: .rect(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var check: some View {
        if state == .done {
            Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy)).foregroundStyle(.white)
                .frame(width: 34, height: 34).background(AZColor.accent, in: .rect(cornerRadius: 12, style: .continuous))
        } else {
            Color.clear.frame(width: 34, height: 34)
        }
    }
}

#Preview {
    NavigationStack { WorkoutView() }.environment(Router()).environment(AppEnvironment.preview())
}
