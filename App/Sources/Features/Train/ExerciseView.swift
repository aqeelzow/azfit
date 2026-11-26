import AZModel
import AZStore
import SwiftUI

/// One exercise: where it is in the plan, why it was swapped in (undoable), the muscles it works, and last time's sets.
/// Design: design/source/src/Exercise.html
struct ExerciseView: View {
    let exerciseID: String

    @Environment(Router.self) private var router
    @Environment(AppEnvironment.self) private var environment
    @State private var problem: String?

    private let library = Library.standard

    var body: some View {
        let store = environment.store
        let exercise = library.exercise(exerciseID)
        let uses = (try? store.plannedUses(of: exerciseID)) ?? []
        let divSwap = try? store.divSwap(into: exerciseID, library: library)
        let last = (try? store.previousSets(exerciseIDs: [exerciseID], before: Day.adding(1, to: environment.today)))?[exerciseID]
        VStack(spacing: 0) {
            TopBar {
                BackButton()
            } center: {
                EmptyView()
            } trailing: {
                if !uses.isEmpty {
                    IconButton(systemImage: "arrow.left.arrow.right", label: "Swap for another exercise") {
                        router.push(.swapExercise(exerciseID))
                    }
                }
            }
            ScrollView {
                if let exercise {
                    VStack(alignment: .leading, spacing: 0) {
                        header(exercise, uses: uses).padding(.top, 16)
                        note(divSwap: divSwap, uses: uses).padding(.top, 22)
                        if let problem {
                            Text(problem).font(.az(14)).foregroundStyle(AZColor.muted).padding(.top, 10)
                        }
                        SectionHeader(title: "Muscles worked").padding(.top, 26)
                        muscles(exercise).padding(.top, 10)
                        if let last, !last.isEmpty {
                            lastTime(last).padding(.top, 26)
                        }
                    }
                    .padding(.horizontal, AZSpacing.gutter)
                    .padding(.bottom, 24)
                } else {
                    Text("This exercise isn't in the library.").font(.az(15)).foregroundStyle(AZColor.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AZSpacing.gutter).padding(.top, 16)
                }
            }
            .scrollIndicators(.hidden)
        }
        .azScreen()
    }

    private func header(_ exercise: Exercise, uses: [PlannedUse]) -> some View {
        HStack(spacing: 16) {
            IconTile(systemImage: Self.icon(exercise), size: 88, foreground: AZColor.ink, background: AZColor.fill)
            VStack(alignment: .leading, spacing: 2) {
                SectionLabel(text: [library.group(of: exercise)?.name, exercise.equipmentName].compactMap { $0 }.joined(separator: " · "))
                Text(exercise.name).font(.az(28, .heavy)).tracking(-0.56).fixedSize(horizontal: false, vertical: true)
                Text(Self.plan(uses)).font(.az(14.5)).foregroundStyle(AZColor.muted).monospacedDigit()
            }
        }
    }

    /// Why it's here, when it replaced something, and the way back.
    @ViewBuilder
    private func note(divSwap: DivChange?, uses: [PlannedUse]) -> some View {
        let from = uses.lazy.compactMap(\.row.swappedFromID).first
        let fromName = from.flatMap { library.exercise($0)?.name }
        if let divSwap {
            DivNote(title: "Swapped in by Div", message: divSwap.proposal.reason) {
                if divSwap.canUndo(at: .now) {
                    PillButton(title: fromName.map { "Go back to \($0)" } ?? "Undo", systemImage: "arrow.uturn.backward") {
                        undo(divSwap)
                    }
                }
            }
        } else if let from, let fromName {
            DivNote(
                title: "You swapped this in", message: "It replaced \(fromName) in your plan.", tone: .settled, mood: .side
            ) {
                PillButton(title: "Go back to \(fromName)", systemImage: "arrow.uturn.backward", style: .fill) {
                    swapBack(to: from)
                }
            }
        }
    }

    private func muscles(_ exercise: Exercise) -> some View {
        let worked = exercise.muscles.sorted { a, b in
            (-a.value, library.muscle(a.key)?.name ?? a.key) < (-b.value, library.muscle(b.key)?.name ?? b.key)
        }
        let front = Self.levels(BodyFigure.frontMuscles, exercise)
        let back = Self.levels(BodyFigure.backMuscles, exercise)
        let showsBack = Self.weight(back) > Self.weight(front)
        return HStack(alignment: .top, spacing: 22) {
            BodyFigure(side: showsBack ? .back : .front, levels: showsBack ? back : front).frame(width: 52, height: 134)
                .accessibilityLabel("\(showsBack ? "Back" : "Front") view with the muscles it works highlighted")
            HairlineStack {
                ForEach(worked, id: \.key) { muscle in
                    HStack {
                        Text(library.muscle(muscle.key)?.name ?? muscle.key).font(.az(15)).lineLimit(1)
                        Spacer()
                        Text(Self.role(muscle.value)).font(.az(13.5)).foregroundStyle(AZColor.muted)
                    }
                    .frame(height: 42)
                }
            }
        }
    }

    /// "Last time · Mon, Nov 23": each weight with its reps.
    private func lastTime(_ sets: [LoggedSet]) -> some View {
        let units = environment.units
        var groups: [(load: String, reps: [Int])] = []
        for set in sets {
            let load = set.loadKg > 0 ? units.load(set.loadKg) : "Bodyweight"
            if groups.last?.load == load { groups[groups.count - 1].reps.append(set.reps) } else { groups.append((load, [set.reps])) }
        }
        return VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                Text("\(group.load) × \(group.reps.map(String.init).joined(separator: ", "))").font(.az(15, .bold))
            }
            Text("Last time you did it").font(.az(13.5)).foregroundStyle(AZColor.muted)
        }
        .monospacedDigit()
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(AZColor.fill, in: .rect(cornerRadius: 18, style: .continuous))
    }

    private func undo(_ change: DivChange) {
        do {
            try environment.store.undo(change.id)
            environment.changed()
            router.pop()
        } catch {
            problem = "\(error)"
        }
    }

    private func swapBack(to from: String) {
        do {
            try environment.store.swapExercise(exerciseID, to: from)
            environment.changed()
            router.pop()
        } catch {
            problem = "\(error)"
        }
    }

    /// "3 × 10 in Push A", or every session it's in.
    static func plan(_ uses: [PlannedUse]) -> String {
        guard let first = uses.first else { return "Not in your plan" }
        let reps = first.row.repMin == first.row.repMax ? "\(first.row.repMin)" : "\(first.row.repMin)-\(first.row.repMax)"
        let sessions = uses.map(\.session.name).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        return "\(first.row.sets) × \(reps) in \(sessions.formatted(.list(type: .and)))"
    }

    /// A full set is the main mover; half is a helper.
    static func role(_ share: Double) -> String {
        share >= 1 ? "Primary" : share >= 0.5 ? "Secondary" : "A little"
    }

    /// The figure's levels for one exercise: 4 where it's the main mover, 2 for a helper, 1 for a little.
    static func levels(_ regions: [[String]], _ exercise: Exercise) -> String {
        String(
            regions.map { muscles -> Character in
                let share = muscles.map { exercise.muscles[$0] ?? 0 }.max() ?? 0
                return share >= 1 ? "4" : share >= 0.5 ? "2" : share > 0 ? "1" : "0"
            })
    }

    private static func weight(_ levels: String) -> Int { levels.compactMap(\.wholeNumberValue).reduce(0, +) }

    static func icon(_ exercise: Exercise) -> String {
        switch exercise.equipment {
        case "bodyweight": "figure.strengthtraining.functional"
        case "machine", "smith", "cable": "figure.strengthtraining.traditional"
        default: "dumbbell"
        }
    }
}

#Preview {
    NavigationStack { ExerciseView(exerciseID: "overhead_press") }.environment(Router()).environment(AppEnvironment.preview())
}
