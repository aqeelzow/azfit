import SwiftUI

/// Div's face: the spiky body on a purple rounded square. This is the only place the mascot appears in the UI,
/// as the avatar and, at small sizes, as the change mark. Never as decoration.
struct DivAvatar: View {
    /// The five expressions from design/brand/brand.html.
    enum Mood: CaseIterable { case curious, side, wow, proud, rest }

    var size: CGFloat = 36
    var mood: Mood = .curious
    /// The avatar insets the body so it peeks in from the corner. The change mark draws it full size.
    var inset = true
    var cornerRatio: CGFloat = 0.3

    var body: some View {
        Canvas { ctx, canvasSize in
            let s = canvasSize.width / 100
            ctx.scaleBy(x: s, y: s)
            var body = ctx
            if inset {
                // Same as the design: translate(-4 20) scale(.84).
                body.translateBy(x: -4, y: 20)
                body.scaleBy(x: 0.84, y: 0.84)
            }
            let shape = DivBodyShape().path(in: CGRect(x: 0, y: 0, width: 100, height: 100))
            body.fill(shape, with: .color(Self.bodyColor))
            body.stroke(shape, with: .color(Self.bodyColor), style: StrokeStyle(lineWidth: 12, lineJoin: .round))
            Self.drawFace(in: &body, mood: mood)
        }
        .frame(width: size, height: size)
        .background(AZColor.accent)
        .clipShape(.rect(cornerRadius: size * cornerRatio, style: .continuous))
        .accessibilityHidden(true)
    }

    static let bodyColor = Color(red: 0x16 / 255, green: 0x14 / 255, blue: 0x1A / 255)

    private static func dot(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    private static func curve(from a: CGPoint, to b: CGPoint, control: CGPoint) -> Path {
        var p = Path()
        p.move(to: a)
        p.addQuadCurve(to: b, control: control)
        return p
    }

    private static func drawFace(in ctx: inout GraphicsContext, mood: Mood) {
        let eyes = [CGPoint(x: 40, y: 56), CGPoint(x: 60, y: 52)]
        let line = StrokeStyle(lineWidth: 4.5, lineCap: .round)
        switch mood {
        case .curious, .side:
            let offset = mood == .side ? CGSize(width: -3.4, height: 1) : CGSize(width: 2.8, height: -3)
            for e in eyes {
                ctx.fill(dot(e, 10), with: .color(.white))
                ctx.fill(dot(CGPoint(x: e.x + offset.width, y: e.y + offset.height), 5), with: .color(bodyColor))
            }
        case .wow:
            for e in eyes {
                ctx.fill(dot(e, 12), with: .color(.white))
                ctx.fill(dot(e, 3.6), with: .color(bodyColor))
            }
            // The mouth uses the line color so it shows on the dark body (the design drew it in the body color).
            ctx.fill(Path(ellipseIn: CGRect(x: 46, y: 72, width: 10, height: 12)), with: .color(.white))
        case .proud:
            for e in eyes {
                ctx.stroke(
                    curve(from: CGPoint(x: e.x - 8, y: e.y + 2), to: CGPoint(x: e.x + 8, y: e.y + 2), control: CGPoint(x: e.x, y: e.y - 8)),
                    with: .color(.white), style: line)
            }
            ctx.stroke(
                curve(from: CGPoint(x: 42, y: 72), to: CGPoint(x: 60, y: 70), control: CGPoint(x: 51, y: 82)), with: .color(.white),
                style: line)
        case .rest:
            for e in eyes {
                ctx.stroke(
                    curve(from: CGPoint(x: e.x - 8, y: e.y - 1), to: CGPoint(x: e.x + 8, y: e.y - 1), control: CGPoint(x: e.x, y: e.y + 6)),
                    with: .color(.white), style: line)
            }
        }
    }
}

/// The spiky outline, in a 100×100 box. Same path as the design's mascot.
struct DivBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let pts: [(CGFloat, CGFloat)] = [
            (-4, 112), (0, 58), (-8, 40), (14, 40), (22, 18), (38, 32), (56, 12), (62, 38), (84, 34), (76, 56), (96, 70), (80, 82),
            (84, 112),
        ]
        let sx = rect.width / 100
        let sy = rect.height / 100
        var p = Path()
        for (i, pt) in pts.enumerated() {
            let point = CGPoint(x: rect.minX + pt.0 * sx, y: rect.minY + pt.1 * sy)
            i == 0 ? p.move(to: point) : p.addLine(to: point)
        }
        p.closeSubpath()
        return p
    }
}

/// The small mark next to anything Div changed. Always paired with the lavender tint.
struct DivMark: View {
    var size: CGFloat = 18
    var body: some View {
        DivAvatar(size: size, inset: false, cornerRatio: 0.32)
            .accessibilityElement()
            .accessibilityLabel("Changed by Div")
    }
}

#Preview {
    HStack(spacing: 16) {
        ForEach(DivAvatar.Mood.allCases, id: \.self) { DivAvatar(size: 56, mood: $0) }
        DivMark()
    }
    .padding()
}
