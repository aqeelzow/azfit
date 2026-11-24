import SwiftUI

/// Body: this week's muscle map, Div's fix for a lagging muscle, and sets per muscle against target.
/// Design: design/source/src/Body.html
struct BodyView: View {
    @Environment(Router.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .bottom) {
                    LargeTitle(caption: "This week · Nov 16 to 21", title: "Body")
                    Spacer()
                    HStack(spacing: 10) {
                        IconButton(systemImage: "viewfinder", label: "Body scan") { router.present(.scan) }
                        IconButton(systemImage: "chart.line.uptrend.xyaxis", label: "Progress") { router.push(.progress) }
                    }
                }
                muscleMap.padding(.top, 16)
                DivNote(
                    title: "Rear delts only got 2 sets",
                    message: "All that pressing needs balance. I added 3 sets of face pulls to Pull B on Monday."
                ) {
                    PillButton(title: "Undo", systemImage: "arrow.uturn.backward") {}
                    PillButton(title: "See Pull B") { router.show(.train) }
                }
                .padding(.top, 14)
                SectionHeader(title: "Sets this week", note: "Line is your target").padding(.top, 24)
                VStack(spacing: 0) {
                    setsRow("Chest", 14, fill: 0.82, target: 0.70)
                    setsRow("Back", 13, fill: 0.76, target: 0.70)
                    setsRow("Legs", 11, fill: 0.64, target: 0.70)
                    setsRow("Rear delts", 2, fill: 0.12, target: 0.47, lagging: true)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, AZSpacing.gutter)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var muscleMap: some View {
        VStack(spacing: 0) {
            HStack {
                BodyFigure(side: .front, levels: "234211131").frame(width: 92, height: 238)
                    .accessibilityLabel("Front muscles by sets this week. Chest worked most")
                Spacer()
                BodyFigure(side: .back, levels: "3a4312321").frame(width: 92, height: 238)
                    .accessibilityLabel("Back muscles by sets this week. Rear delts lagging")
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

    private func setsRow(_ muscle: String, _ sets: Int, fill: Double, target: Double, lagging: Bool = false) -> some View {
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
            Text("\(sets)").fontWeight(.bold).frame(width: 44, alignment: .trailing)
        }
        .font(.az(15))
        .monospacedDigit()
        .frame(height: 34)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(muscle), \(sets) sets\(lagging ? ", lagging" : "")")
    }
}

#Preview {
    NavigationStack { BodyView() }.environment(Router())
}
