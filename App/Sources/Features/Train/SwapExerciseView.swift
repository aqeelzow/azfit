import AZModel
import AZStore
import SwiftUI

/// The exercise library. Opened from an exercise in the plan, it swaps that exercise for the one you pick, with the
/// closest matches on top; opened from Train, it browses. Design: design/source/src/Library.html
struct SwapExerciseView: View {
    /// The planned exercise being swapped, or nil to browse.
    let replacing: String?

    @Environment(Router.self) private var router
    @Environment(AppEnvironment.self) private var environment
    @State private var query = ""
    @State private var group: String?
    @State private var problem: String?

    private let library = Library.standard

    var body: some View {
        let current = replacing.flatMap { library.exercise($0) }
        let inPlan = Set(((try? environment.store.plan()) ?? []).flatMap { $0.exercises.map(\.exerciseID) })
        let closest = current.map { Array(library.alternatives(to: $0).prefix(4)) } ?? []
        let listed = matches(excluding: current)
        VStack(spacing: 0) {
            TopBar(title: current.map { "Swap \($0.name)" } ?? "Exercises") {
                BackButton()
            } trailing: {
                Color.clear.frame(width: 44, height: 44)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    search
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            Chip(title: "All", isOn: group == nil) { group = nil }
                            ForEach(library.muscleGroups) { muscleGroup in
                                Chip(title: muscleGroup.name, isOn: group == muscleGroup.id) { group = muscleGroup.id }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .padding(.top, 12)

                    if let problem {
                        Text(problem).font(.az(14)).foregroundStyle(AZColor.muted).padding(.top, 12)
                    }

                    if !closest.isEmpty, query.isEmpty {
                        SectionHeader(title: "Same muscles", note: "Closest first").padding(.top, 26)
                        HairlineStack {
                            ForEach(closest) { row($0, inPlan: inPlan.contains($0.id)) }
                        }
                        .padding(.top, 6)
                    }

                    SectionHeader(title: listTitle, note: "\(listed.count)").padding(.top, 22)
                    if listed.isEmpty {
                        Text("Nothing matches \"\(query)\".").font(.az(15)).foregroundStyle(AZColor.muted).padding(.top, 8)
                    }
                    LazyVStack(spacing: 0) {
                        ForEach(Array(listed.enumerated()), id: \.element.id) { index, exercise in
                            if index > 0 { Rectangle().fill(AZColor.hairline).frame(height: 1) }
                            row(exercise, inPlan: inPlan.contains(exercise.id))
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .azScreen()
        .onAppear {
            if group == nil, let current { group = library.group(of: current)?.id }
        }
    }

    private var search: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 16, weight: .semibold)).foregroundStyle(AZColor.muted)
            TextField("", text: $query, prompt: Text("Search \(library.exercises.count) exercises").foregroundStyle(AZColor.muted))
                .font(.az(15.5))
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(AZColor.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(AZColor.fill, in: .rect(cornerRadius: 16, style: .continuous))
    }

    private var listTitle: String {
        if !query.isEmpty { return "Results" }
        return group.flatMap { library.group($0)?.name } ?? "All exercises"
    }

    /// The group's exercises, or every one, narrowed by the search (name or equipment).
    private func matches(excluding current: Exercise?) -> [Exercise] {
        let words = query.lowercased().split(separator: " ").map(String.init)
        return library.exercises.filter { exercise in
            guard exercise.id != current?.id else { return false }
            if let group, query.isEmpty, library.group(of: exercise)?.id != group { return false }
            let text = "\(exercise.name) \(exercise.equipmentName)".lowercased()
            return words.allSatisfy { text.contains($0) }
        }
        .sorted { $0.name < $1.name }
    }

    private func row(_ exercise: Exercise, inPlan: Bool) -> some View {
        Button {
            pick(exercise)
        } label: {
            HStack(spacing: 14) {
                IconTile(systemImage: ExerciseView.icon(exercise), size: 48, foreground: AZColor.muted, background: AZColor.fill)
                VStack(alignment: .leading, spacing: 1) {
                    Text(exercise.name).font(.az(16, .bold)).lineLimit(1)
                    Text(detail(exercise)).font(.az(14)).foregroundStyle(AZColor.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
                if inPlan {
                    Text("In your plan").font(.az(13, .bold)).foregroundStyle(AZColor.muted)
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background(AZColor.fill, in: .rect(cornerRadius: 8, style: .continuous))
                        .fixedSize()
                } else if replacing == nil {
                    Image(systemName: "chevron.right").font(.system(size: 15, weight: .semibold)).foregroundStyle(AZColor.faint)
                }
            }
            .frame(minHeight: 64)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint(replacing == nil ? "Opens the exercise" : "Swaps it into your plan")
    }

    /// "Barbell · Front delts, Triceps"
    private func detail(_ exercise: Exercise) -> String {
        let main = exercise.primaryMuscles.compactMap { library.muscle($0)?.name }
        return ([exercise.equipmentName] + [main.joined(separator: ", ")].filter { !$0.isEmpty }).joined(separator: " · ")
    }

    private func pick(_ exercise: Exercise) {
        guard let replacing else { return router.push(.exercise(exercise.id)) }
        do {
            try environment.store.swapExercise(replacing, to: exercise.id)
            environment.changed()
            // Back past the old exercise's screen to where the swap started, then show the new one.
            router.pop()
            if case .exercise(replacing)? = router.path.last { router.pop() }
            router.push(.exercise(exercise.id))
        } catch {
            problem = "Couldn't swap it: \(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack { SwapExerciseView(replacing: "overhead_press") }.environment(Router()).environment(AppEnvironment.preview())
}
