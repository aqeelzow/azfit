import SwiftUI

/// Progress: trend weight with the day Div raised the target, weekly loss against goal, and strength trends.
/// Named BodyProgressView so it does not clash with SwiftUI's ProgressView. Design: design/source/src/Progress.html
struct BodyProgressView: View {
    @Environment(Router.self) private var router
    @State private var range = "3M"

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Progress") {
                BackButton()
            } trailing: {
                IconButton(systemImage: "viewfinder", label: "Latest scan") { router.push(.scanResult) }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        ForEach(["1M", "3M", "6M", "1Y", "All"], id: \.self) { name in
                            Chip(title: name, isOn: range == name) { range = name }
                        }
                    }
                    .padding(.top, 16)

                    trend.padding(.top, 20)
                    weeklyLoss.padding(.top, 28)

                    SectionHeader(title: "Strength", note: "Estimated 1 rep max").padding(.top, 28)
                    HairlineStack {
                        lift("Bench press", "82.5 kg × 8 today", "104", "+11 kg", points: [20, 18, 17, 13, 11, 7, 4])
                        lift("Deadlift", "140 kg × 5 · Tue", "163", "+16 kg", points: [20, 16, 17, 12, 9, 8, 5])
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .azScreen()
    }

    private var trend: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel(text: "Trend weight")
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("82.2").font(.az(34, .heavy)).tracking(-1)
                        Text(" kg").font(.az(15, .semibold)).foregroundStyle(AZColor.muted)
                    }
                }
                Spacer()
                Text("-2.1 kg in 3 weeks").font(.az(14, .semibold)).foregroundStyle(AZColor.muted).padding(.bottom, 6)
            }
            .monospacedDigit()

            ZStack(alignment: .topTrailing) {
                let box = CGRect(x: 0, y: 0, width: 342, height: 130)
                ZStack {
                    SVGShape(data: "M0 40H342M0 80H342M0 120H342", viewBox: box).stroke(AZColor.hairline, lineWidth: 1)
                    SVGShape(data: "M323.4 4V128", viewBox: box).stroke(AZColor.accent, style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))
                    SVGShape(
                        data:
                            "M0 19.4 C40 24 80 29 111.5 33 S165 40 185.9 44.5 S245 54 264 58.2 S283 68 290 74 S309 88 316 92.4 S320 95 323.4 97 S336 103 342 106",
                        viewBox: box
                    )
                    .stroke(AZColor.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }
                .frame(height: 130)
                .padding(.top, 20)

                HStack(spacing: 0) {
                    Text("Target 2,200 → 2,350").font(.az(12.5, .bold)).foregroundStyle(AZColor.divInk).monospacedDigit()
                    DivMark(size: 16).padding(.leading, 5)
                }
                .padding(.leading, 10).padding(.trailing, 4)
                .frame(height: 26)
                .background(AZColor.divTint, in: .rect(cornerRadius: 9, style: .continuous))
            }
            .frame(height: 150)
            .padding(.top, 10)
            .accessibilityElement()
            .accessibilityLabel(
                "Trend weight falling from 86.0 kg in August to 82.2 kg today, faster since late October. Div raised the calorie target on November 16."
            )

            HStack {
                Text("Aug 21")
                Spacer()
                Text("Sep 21")
                Spacer()
                Text("Oct 21")
                Spacer()
                Text("Today").foregroundStyle(AZColor.ink)
            }
            .font(.az(12, .semibold))
            .foregroundStyle(AZColor.faint)
            .monospacedDigit()
            .padding(.top, 4)
        }
    }

    private var weeklyLoss: some View {
        let weeks: [(label: String, height: CGFloat, style: Int)] = [
            ("Oct 5", 32, 0), ("12", 42, 0), ("19", 42, 0), ("26", 74, 1), ("Nov 2", 74, 1), ("9", 74, 1), ("16", 52, 2),
        ]
        return VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Weekly loss", note: "Goal 0.4 kg")
            ZStack(alignment: .bottom) {
                DashedRule().stroke(AZColor.ghost, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])).frame(height: 1.5)
                    .padding(.bottom, 64)
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(weeks.indices, id: \.self) { i in
                        let week = weeks[i]
                        VStack(spacing: 6) {
                            if week.style == 2 { DivMark(size: 18) }
                            UnevenRoundedRectangle(
                                topLeadingRadius: 8, bottomLeadingRadius: 4, bottomTrailingRadius: 4, topTrailingRadius: 8,
                                style: .continuous
                            )
                            .fill(week.style == 1 ? AZColor.accent : (week.style == 2 ? AZColor.ramp[1] : AZColor.ramp[2]))
                            .frame(width: 30, height: week.height)
                            Text(week.label)
                                .font(.az(12, .semibold))
                                .foregroundStyle(week.style == 2 ? AZColor.ink : AZColor.faint)
                                .fixedSize()
                                .frame(height: 16)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 112, alignment: .bottom)
            .monospacedDigit()
            .padding(.top, 10)
            Text("Three weeks at 0.7 kg, so Div raised your target.").font(.az(13.5)).foregroundStyle(AZColor.muted).padding(.top, 10)
        }
    }

    private func lift(_ name: String, _ detail: String, _ max: String, _ gain: String, points: [CGFloat]) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.az(16, .bold))
                Text(detail).font(.az(13.5)).foregroundStyle(AZColor.muted)
            }
            Spacer(minLength: 0)
            Sparkline(points: points)
                .stroke(AZColor.accent, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                .frame(width: 64, height: 24)
            VStack(alignment: .trailing, spacing: 0) {
                Text(max).font(.az(16, .heavy))
                Text(gain).font(.az(12.5, .bold)).foregroundStyle(AZColor.divInk)
            }
            .frame(width: 52, alignment: .trailing)
        }
        .monospacedDigit()
        .frame(height: 56)
    }

    private struct DashedRule: Shape {
        func path(in rect: CGRect) -> Path {
            Path { p in
                p.move(to: CGPoint(x: rect.minX, y: rect.midY))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            }
        }
    }

    /// Seven points in a 64 by 24 box, as in the design's polyline.
    private struct Sparkline: Shape {
        var points: [CGFloat]

        func path(in rect: CGRect) -> Path {
            Path { p in
                for (i, y) in points.enumerated() {
                    let point = CGPoint(x: rect.minX + (2 + CGFloat(i) * 10) / 64 * rect.width, y: rect.minY + y / 24 * rect.height)
                    i == 0 ? p.move(to: point) : p.addLine(to: point)
                }
            }
        }
    }
}

#Preview {
    NavigationStack { BodyProgressView() }.environment(Router())
}
