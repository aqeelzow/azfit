import AZModel
import AZStore
import SwiftUI

/// Body: this week's muscle map, a nudge for a lagging muscle, and sets per muscle group against target.
/// Design: design/source/src/Body.html
struct BodyView: View {
    @Environment(Router.self) private var router
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        let today = environment.today
        let volume = (try? environment.store.volume(today: today)) ?? []
        let sets = Dictionary(uniqueKeysWithValues: volume.map { ($0.muscle.id, $0.sets) })
        // Early in the week every muscle is under its minimum, so only call one lagging from Friday.
        let lateInWeek = (Day.weekday(today) ?? 1) >= 5
        let lagging =
            lateInWeek
            ? volume.filter(\.lagging).min { $0.sets / Double($0.muscle.minSetsPerWeek) < $1.sets / Double($1.muscle.minSetsPerWeek) } : nil
        let monday = AZStore.monday(of: today)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .bottom) {
                    LargeTitle(caption: "This week · \(Self.short(monday)) to \(Self.short(today))", title: "Body")
                    Spacer()
                    HStack(spacing: 10) {
                        IconButton(systemImage: "viewfinder", label: "Body scan") { router.present(.scan) }
                        IconButton(systemImage: "chart.line.uptrend.xyaxis", label: "Progress") { router.push(.progress) }
                    }
                }
                muscleMap(sets: sets, lagging: lagging?.muscle.id).padding(.top, 16)
                if let lagging {
                    DivNote(
                        title: "\(lagging.muscle.name.components(separatedBy: " (")[0]) only got \(Self.count(lagging.sets)) sets",
                        message: "Most people need at least \(lagging.muscle.minSetsPerWeek) a week to grow. Ask Div to fit more in."
                    ) {
                        PillButton(title: "Ask Div") { router.push(.chat) }
                    }
                    .padding(.top, 14)
                }
                SectionHeader(title: "Sets this week", note: "Line is your target").padding(.top, 24)
                VStack(spacing: 0) {
                    ForEach(Library.standard.muscleGroups) { group in
                        let muscles = volume.filter { $0.muscle.group == group.id }
                        let done = muscles.reduce(0) { $0 + $1.sets }
                        let minimum = Double(muscles.reduce(0) { $0 + $1.muscle.minSetsPerWeek })
                        let maximum = Double(max(1, muscles.reduce(0) { $0 + $1.muscle.maxRecoverableSetsPerWeek }))
                        setsRow(
                            group.name, done, fill: min(1, done / maximum), target: minimum / maximum,
                            lagging: lateInWeek && done < minimum)
                    }
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, AZSpacing.gutter)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    /// "Nov 23"
    private static func short(_ day: String) -> String {
        Day.date(day)?.formatted(.dateTime.month(.abbreviated).day()) ?? day
    }

    /// "2" or "2.5"
    private static func count(_ sets: Double) -> String {
        sets.formatted(.number.precision(.fractionLength(0...1)))
    }

    /// The figures' regions, in BodyFigure's order, each as the library muscles it shows.
    /// One digit per region, 0 (no sets) to 5 (14 or more), or "a" for the lagging muscle.
    private static func levels(_ regions: [[String]], sets: [String: Double], lagging: String?) -> String {
        String(
            regions.map { muscles -> Character in
                if let lagging, muscles.contains(lagging) { return "a" }
                let total = muscles.reduce(0) { $0 + (sets[$1] ?? 0) } / Double(muscles.count)
                let level = total == 0 ? 0 : total < 3 ? 1 : total < 6 ? 2 : total < 10 ? 3 : total < 14 ? 4 : 5
                return Character(String(level))
            })
    }

    private func muscleMap(sets: [String: Double], lagging: String?) -> some View {
        VStack(spacing: 0) {
            HStack {
                BodyFigure(side: .front, levels: Self.levels(BodyFigure.frontMuscles, sets: sets, lagging: lagging)).frame(
                    width: 92, height: 238
                )
                .accessibilityLabel("Front muscles by sets this week")
                Spacer()
                BodyFigure(side: .back, levels: Self.levels(BodyFigure.backMuscles, sets: sets, lagging: lagging)).frame(
                    width: 92, height: 238
                )
                .accessibilityLabel("Back muscles by sets this week")
            }
            .padding(.horizontal, 40)
            .padding(.top, 16)
            Spacer(minLength: 0)
            HStack {
                HStack(spacing: 7) {
                    Text("Fewer")
                    HStack(spacing: 3) {
                        ForEach(1..<6) { level in swatch(AZColor.ramp[level]) }
                    }
                    Text("More sets")
                }
                Spacer()
                HStack(spacing: 6) {
                    swatch(AZColor.lagging)
                    Text("Lagging")
                }
            }
            .font(.az(12.5, .semibold))
            .foregroundStyle(AZColor.muted)
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .frame(height: 270)
        .background(AZColor.fill, in: .rect(cornerRadius: 32, style: .continuous))
    }

    private func swatch(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 14, height: 8)
    }

    private func setsRow(_ muscle: String, _ sets: Double, fill: Double, target: Double, lagging: Bool = false) -> some View {
        HStack(spacing: 12) {
            Text(muscle).frame(width: 96, alignment: .leading)
            GeometryReader { geo in
                Capsule().fill(AZColor.track)
                    .overlay(alignment: .leading) {
                        Capsule().fill(lagging ? AZColor.lagging : AZColor.accent).frame(width: geo.size.width * fill)
                    }
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1).fill(AZColor.ink.opacity(0.35)).frame(width: 2, height: 16)
                            .offset(x: geo.size.width * target)
                    }
            }
            .frame(height: 8)
            Text(Self.count(sets)).fontWeight(.bold).frame(width: 44, alignment: .trailing)
        }
        .font(.az(15))
        .monospacedDigit()
        .frame(height: 34)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(muscle), \(Self.count(sets)) sets\(lagging ? ", lagging" : "")")
    }
}

#Preview {
    NavigationStack { BodyView() }.environment(Router()).environment(AppEnvironment.preview())
}
