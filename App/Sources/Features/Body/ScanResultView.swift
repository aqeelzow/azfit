import SwiftUI

/// A finished scan: body fat range, measurements on the outline, and Div reading the trend.
/// Design: design/source/src/ScanResult.html
struct ScanResultView: View {
    @Environment(Router.self) private var router

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Scan · Nov 21") {
                BackButton()
            } trailing: {
                IconButton(systemImage: "square.and.arrow.up", label: "Share scan") {}
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 0) {
                            SectionLabel(text: "Body fat")
                            HStack(alignment: .firstTextBaseline, spacing: 0) {
                                Text("14-17").font(.az(52, .heavy)).tracking(-2)
                                Text("%").font(.az(26, .heavy))
                            }
                            .monospacedDigit()
                        }
                        Spacer()
                        Text("-1.5% since Oct 24")
                            .font(.az(14, .bold)).foregroundStyle(AZColor.divInk).monospacedDigit()
                            .padding(.horizontal, 12).frame(height: 30)
                            .background(AZColor.divTint, in: .capsule)
                            .padding(.bottom, 10)
                    }
                    .padding(.top, 14)

                    measurements.padding(.top, 10)

                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 0) {
                        GridRow {
                            total("Lean mass", "69.3", " kg")
                            total("Fat mass", "12.7", " kg")
                        }
                        GridRow {
                            total("Scale weight", "82.0", " kg").overlay(alignment: .top) { hairline }
                            total("Waist to height", "0.45", " healthy").overlay(alignment: .top) { hairline }
                        }
                    }
                    .padding(.top, 12)

                    DivNote(
                        title: "Waist down, arms holding", message: "That's fat coming off, not muscle. The 2,350 target is doing its job.",
                        mood: .proud
                    ) {
                        PillButton(title: "Why 2,350") { router.push(.calorieTarget) }
                    }
                    .padding(.top, 12)

                    HStack(spacing: 8) {
                        Image(systemName: "cube").font(.system(size: 14, weight: .medium))
                        Text("LiDAR is accurate to about ±3%. Div reads the trend.").font(.az(13))
                    }
                    .foregroundStyle(AZColor.muted)
                    .padding(.top, 20)
                }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .azScreen()
    }

    private var hairline: some View { Rectangle().fill(AZColor.hairline).frame(height: 1) }

    /// The outline with six measurements around it, each joined to the body by a dashed leader.
    private var measurements: some View {
        ZStack(alignment: .topLeading) {
            BodyFigure(side: .front, levels: "000000000").frame(width: 94, height: 244)
                .frame(maxWidth: .infinity)
                .padding(.top, 18)
                .accessibilityLabel("Body outline with measurements")
            measure("Chest", "104.2", nil, x: 18, y: 54)
            leader(x: 76, width: 70, y: 74)
            measure("Waist", "81.4", "-1.2", x: 18, y: 118)
            leader(x: 108, width: 44, y: 138)
            measure("Hips", "97.0", nil, x: 18, y: 182)
            leader(x: 66, width: 84, y: 202)
            Text("cm").font(.az(12, .semibold)).foregroundStyle(AZColor.faint).offset(x: 18, y: 268 - 14 - 16)
        }
        .overlay(alignment: .topTrailing) {
            ZStack(alignment: .topTrailing) {
                measure("Arm", "36.4", "+0.4", x: -18, y: 88, trailing: true)
                leader(x: -96, width: 44, y: 108)
                measure("Thigh", "58.8", nil, x: -18, y: 156, trailing: true)
                leader(x: -70, width: 76, y: 176)
                measure("Calf", "38.1", nil, x: -18, y: 220, trailing: true)
                leader(x: -66, width: 84, y: 240)
            }
        }
        .frame(height: 268, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(AZColor.fill, in: .rect(cornerRadius: 32, style: .continuous))
    }

    private func measure(_ name: String, _ value: String, _ change: String?, x: CGFloat, y: CGFloat, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 0) {
            Text(name).font(.az(12.5, .semibold)).foregroundStyle(AZColor.muted)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.az(17, .heavy)).tracking(-0.34)
                if let change { Text(change).font(.az(12.5, .bold)).foregroundStyle(AZColor.divInk) }
            }
            .monospacedDigit()
        }
        .offset(x: x, y: y)
    }

    private func leader(x: CGFloat, width: CGFloat, y: CGFloat) -> some View {
        Leader()
            .stroke(AZColor.ghost, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            .frame(width: width, height: 1.5)
            .offset(x: x, y: y)
    }

    private func total(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.az(13.5, .semibold)).foregroundStyle(AZColor.muted)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(value).font(.az(24, .heavy)).tracking(-0.72)
                Text(unit).font(.az(14, .semibold)).foregroundStyle(AZColor.muted)
            }
            .monospacedDigit()
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private struct Leader: Shape {
        func path(in rect: CGRect) -> Path {
            Path { p in
                p.move(to: CGPoint(x: rect.minX, y: rect.midY))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            }
        }
    }
}

#Preview {
    NavigationStack { ScanResultView() }.environment(Router())
}
