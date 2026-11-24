import SwiftUI

/// Why the daily target is 2,350: the change Div made, the evidence it used, and a one-tap way back.
/// Design: design/source/src/Calibrate.html
///
/// The numbers are hard-coded samples. In the real app the target comes from AZMath, and Div only explains it (D-010).
struct CalorieTargetView: View {
    @Environment(Router.self) private var router
    @State private var reverted = false

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Daily target") {
                BackButton()
            } trailing: {
                Button {
                    router.push(.chat)
                } label: {
                    DivAvatar(size: 26)
                        .frame(width: 44, height: 44)
                        .background(AZColor.fill, in: .rect(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ask Div")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            if !reverted { DivMark() }
                            SectionLabel(text: reverted ? "You set this · Sat, Nov 21" : "Raised by Div · Mon, Nov 16")
                        }
                        HStack(alignment: .bottom, spacing: 14) {
                            Text(reverted ? "2,200" : "2,350")
                                .font(.az(64, .heavy)).tracking(-2.9).monospacedDigit()
                                .contentTransition(.numericText(value: reverted ? 2200 : 2350))
                            VStack(alignment: .leading, spacing: 2) {
                                if !reverted { WasValue(value: "2,200").font(.az(17)).monospacedDigit() }
                                SectionLabel(text: "kcal a day")
                            }
                            .padding(.bottom, 6)
                        }
                    }
                    .padding(.top, 16)

                    note.padding(.top, 20)

                    SectionHeader(title: "Weekly loss", note: "kg").padding(.top, 26)
                    WeeklyLossChart().padding(.top, 6)

                    SectionLabel(text: "What I looked at").padding(.top, 26)
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                        GridRow {
                            fact("-2.1 kg", "weight trend, 3 weeks")
                            fact("2,060", "average logged a day")
                        }
                        GridRow {
                            fact("6 of 7", "days fully logged")
                            fact("~2,800", "your maintenance")
                        }
                    }
                    .padding(.top, 12)
                }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    if reverted {
                        PrimaryButton(title: "Use 2,350", style: .soft) { setReverted(false) }
                        PrimaryButton(title: "Done") { router.show(.eat) }
                    } else {
                        PrimaryButton(title: "Go back to 2,200", style: .soft) { setReverted(true) }
                        PrimaryButton(title: "Keep 2,350") { router.show(.eat) }
                    }
                }
                HStack(spacing: 4) {
                    Text("Div can move it 200 kcal without asking.").foregroundStyle(AZColor.faint)
                    Button("Settings") { router.push(.memory) }.fontWeight(.semibold).foregroundStyle(AZColor.muted).buttonStyle(.plain)
                }
                .font(.az(12.5))
            }
            .padding(.horizontal, AZSpacing.gutter)
            .padding(.bottom, 8)
        }
        .azScreen()
    }

    private func setReverted(_ value: Bool) {
        withAnimation(.snappy(duration: 0.25)) { reverted = value }
    }

    @ViewBuilder
    private var note: some View {
        if reverted {
            DivNote(
                title: "Back to 2,200. Your call.", message: "I'll look again Monday. If the pace holds, I'll ask first.", tone: .settled,
                mood: .side
            )
            .transition(.opacity)
        } else {
            DivNote(
                title: "You're losing faster than planned",
                message: "0.7 kg a week for 3 weeks, against your 0.4 goal. That pace starts to cost muscle, so I added 150 kcal."
            )
            .transition(.opacity)
        }
    }

    private func fact(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.az(18, .heavy)).tracking(-0.36).monospacedDigit()
            Text(label).font(.az(13.5)).foregroundStyle(AZColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Five weeks of loss as rounded bars against the dashed goal line. The last three are over the goal.
private struct WeeklyLossChart: View {
    private let weeks: [(label: String, kg: Double)] = [("Oct 19", 0.3), ("Oct 26", 0.4), ("Nov 2", 0.7), ("Nov 9", 0.8), ("Nov 16", 0.6)]
    private let goal = 0.4
    private let scale: CGFloat = 90  // points per kg, from the design (0.4 kg = 36 pt)

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let barWidth = (geo.size.width - 4 * 18) / 5
                ZStack(alignment: .bottomLeading) {
                    ForEach(weeks.indices, id: \.self) { i in
                        let week = weeks[i]
                        let height = week.kg * scale
                        let over = week.kg > goal
                        VStack(spacing: 4) {
                            if over { Text(week.kg.formatted()).font(.az(13, .bold)) }
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(over ? AZColor.accent : AZColor.accentSoft)
                                .frame(width: barWidth, height: height)
                        }
                        .offset(x: CGFloat(i) * (barWidth + 18))
                    }
                    DashedLine()
                        .stroke(AZColor.ink.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .frame(height: 1)
                        .offset(y: -goal * scale)
                    Text("Goal 0.4").font(.az(12, .semibold)).foregroundStyle(AZColor.muted)
                        .offset(y: -goal * scale - 8)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .bottomLeading)
            }
            .frame(height: 112)
            .monospacedDigit()

            HStack(spacing: 18) {
                ForEach(weeks, id: \.label) { week in
                    Text(week.label).font(.az(12.5, .semibold)).foregroundStyle(AZColor.faint).frame(maxWidth: .infinity)
                }
            }
            .monospacedDigit()
        }
        .accessibilityElement()
        .accessibilityLabel("Weekly loss: 0.3, 0.4, 0.7, 0.8 and 0.6 kg against a 0.4 kg goal")
    }

    private struct DashedLine: Shape {
        func path(in rect: CGRect) -> Path {
            Path { p in
                p.move(to: CGPoint(x: rect.minX, y: rect.midY))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            }
        }
    }
}

#Preview {
    NavigationStack { CalorieTargetView() }.environment(Router())
}
