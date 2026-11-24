import SwiftUI

/// The LiDAR body scan, mid-way: turning for the back view while Div talks you through it. Always dark.
/// The prototype shows a still frame; the real scan needs the camera. Design: design/source/src/Scan.html
struct BodyScanView: View {
    @Environment(Router.self) private var router
    @State private var voiceGuidance = true

    var body: some View {
        VStack(spacing: 0) {
            TopBar {
                IconButton(systemImage: "xmark", label: "Cancel scan") { router.dismissCover() }
            } center: {
                HStack(spacing: 7) {
                    Image(systemName: "cube").font(.system(size: 13, weight: .semibold))
                    Text("LiDAR · 2.1 m away").font(.az(14, .semibold)).monospacedDigit()
                }
                .padding(.leading, 12).padding(.trailing, 14)
                .frame(height: 36)
                .background(AZColor.fill, in: .capsule)
            } trailing: {
                Button {
                } label: {
                    Text("?").font(.az(17, .bold)).frame(width: 44, height: 44)
                        .background(AZColor.fill, in: .rect(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Help")
            }

            ZStack(alignment: .top) {
                Brackets().stroke(AZColor.divInk.opacity(0.55), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                BodyFigure(side: .back, levels: "000000000", base: AZColor.Camera.scanFigure)
                    .frame(width: 116, height: 296)
                    .mask { ScanLines() }
                    .opacity(0.9)
                    .padding(.top, 22)
                Capsule()
                    .fill(AZColor.accent)
                    .frame(height: 3)
                    .shadow(color: AZColor.accent.opacity(0.55), radius: 11)
                    .padding(.horizontal, 28)
                    .padding(.top, 168)
            }
            .frame(width: 260, height: 340)
            .padding(.top, 24)

            VStack(spacing: 8) {
                Text("Step 3 of 4 · back").font(.az(14, .bold)).foregroundStyle(AZColor.divInk)
                Text("Keep turning right").font(.az(30, .heavy)).tracking(-0.75)
                Text("Arms a little away from your sides. Div tells you when your back is done.")
                    .font(.az(15)).foregroundStyle(AZColor.muted).frame(maxWidth: 290)
            }
            .multilineTextAlignment(.center)
            .padding(.top, 30)

            HStack(spacing: 8) {
                angle("Front", progress: 1, state: .done)
                angle("Left", progress: 1, state: .done)
                angle("Back", progress: 0.6, state: .current)
                angle("Right", progress: 0, state: .todo)
            }
            .padding(.horizontal, 32)
            .padding(.top, 26)

            Spacer(minLength: 16)

            HStack(spacing: 12) {
                DivAvatar(size: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Div talks you through it").font(.az(15, .bold))
                    Text("Prop the phone at hip height").font(.az(13)).foregroundStyle(AZColor.muted)
                }
                Spacer(minLength: 0)
                SquareToggle(isOn: $voiceGuidance, label: "Voice guidance")
            }
            .padding(.horizontal, 14)
            .frame(height: 72)
            .background(AZColor.fill, in: .rect(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .azScreen()
        .background(AZColor.Camera.shade.ignoresSafeArea())
    }

    private enum AngleState { case done, current, todo }

    private func angle(_ name: String, progress: Double, state: AngleState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MeterBar(value: state == .done ? 1 : progress, color: state == .done ? AZColor.ink : AZColor.accent, height: 5)
            Text(name)
                .font(.az(12.5, .semibold))
                .foregroundStyle(state == .current ? AZColor.ink : (state == .done ? AZColor.muted : AZColor.faint))
        }
        .frame(maxWidth: .infinity)
    }

    /// Horizontal lines that turn the figure into a scan: 1.8 pt on, 2.2 pt off.
    private struct ScanLines: View {
        var body: some View {
            Canvas { context, size in
                var y: CGFloat = 0
                while y < size.height {
                    context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1.8)), with: .color(.black))
                    y += 4
                }
            }
        }
    }

    private nonisolated struct Brackets: Shape {
        func path(in rect: CGRect) -> Path {
            let arm: CGFloat = 30
            let r: CGFloat = 16
            var p = Path()
            for (x, y, sx, sy) in [
                (rect.minX, rect.minY, 1.0, 1.0), (rect.maxX, rect.minY, -1.0, 1.0), (rect.minX, rect.maxY, 1.0, -1.0),
                (rect.maxX, rect.maxY, -1.0, -1.0),
            ] {
                p.move(to: CGPoint(x: x, y: y + sy * arm))
                p.addLine(to: CGPoint(x: x, y: y + sy * r))
                p.addQuadCurve(to: CGPoint(x: x + sx * r, y: y), control: CGPoint(x: x, y: y))
                p.addLine(to: CGPoint(x: x + sx * arm, y: y))
            }
            return p
        }
    }
}

#Preview {
    BodyScanView().environment(Router()).preferredColorScheme(.dark)
}
