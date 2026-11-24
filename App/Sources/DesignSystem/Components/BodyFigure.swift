import SwiftUI

/// The muscle map figure from the design (design/source/build.py, FRONT and BACK). The paths draw the left half;
/// the right half is the same paths mirrored. Each muscle gets a level: 0 to 5 sets (the purple ramp) or lagging.
struct BodyFigure: View {
    enum Side { case front, back }
    enum Level: Equatable {
        case sets(Int)
        case lagging
    }

    var side: Side
    /// One level per muscle, in the order of the design's paths. Front: traps, delts, chest, biceps, forearms, abs,
    /// obliques, quads, calves. Back: traps, delts, lats, triceps, forearms, lower back, glutes, hamstrings, calves.
    var levels: [Level]
    /// The color of muscles with no sets, and of the head, hands and feet.
    var base: Color = AZColor.ramp[0]

    /// Parses the design's level string: "234211131", "3a4312321" ("a" is lagging).
    init(side: Side, levels: String, base: Color? = nil) {
        self.side = side
        self.levels = levels.map { $0 == "a" ? .lagging : .sets(Int(String($0)) ?? 0) }
        let untouched = !levels.contains { $0 != "0" }
        self.base = base ?? (untouched ? AZColor.figure : AZColor.ramp[0])
    }

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / Self.viewBox.width, size.height / Self.viewBox.height)
            context.translateBy(x: (size.width - Self.viewBox.width * scale) / 2, y: (size.height - Self.viewBox.height * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -Self.viewBox.minX, y: -Self.viewBox.minY)
            var mirrored = context
            mirrored.translateBy(x: 200, y: 0)
            mirrored.scaleBy(x: -1, y: 1)
            for half in [context, mirrored] {
                half.fill(Self.neutral, with: .color(base))
                for (path, level) in zip(side == .front ? Self.front : Self.back, levels) {
                    half.fill(path, with: .color(color(for: level)))
                }
            }
        }
        .aspectRatio(Self.viewBox.width / Self.viewBox.height, contentMode: .fit)
    }

    private func color(for level: Level) -> Color {
        switch level {
        case .lagging: AZColor.lagging
        case .sets(0): base
        case .sets(let n): AZColor.ramp[min(n, AZColor.ramp.count - 1)]
        }
    }

    private static let viewBox = CGRect(x: 30, y: 4, width: 140, height: 362)

    /// Head, hands and feet.
    private static let neutral = SVGPath.parse(
        "M96 11 h8 a13 13 0 0 1 13 13 v12 a13 13 0 0 1 -13 13 h-8 a13 13 0 0 1 -13 -13 v-12 a13 13 0 0 1 13 -13 Z M42 183 h2 a5 5 0 0 1 5 5 v8 a5 5 0 0 1 -5 5 h-2 a5 5 0 0 1 -5 -5 v-8 a5 5 0 0 1 5 -5 Z M156 183 h2 a5 5 0 0 1 5 5 v8 a5 5 0 0 1 -5 5 h-2 a5 5 0 0 1 -5 -5 v-8 a5 5 0 0 1 5 -5 Z M75 350 h6 a5 5 0 0 1 5 5 v2 a5 5 0 0 1 -5 5 h-6 a5 5 0 0 1 -5 -5 v-2 a5 5 0 0 1 5 -5 Z M119 350 h6 a5 5 0 0 1 5 5 v2 a5 5 0 0 1 -5 5 h-6 a5 5 0 0 1 -5 -5 v-2 a5 5 0 0 1 5 -5 Z"
    )

    private static let front: [Path] = [
        "M90 48 C85 54 77 57 67 60 C77 62 86 62 93 60 Z",
        "M64 62 C53 63 45 72 45 86 C45 92 46 96 49 99 C53 88 59 80 68 74 C69 69 67 64 64 62 Z",
        "M72 66 C84 63 94 63 98 66 L98 95 C90 100 79 99 71 94 C65 90 64 82 67 74 Z",
        "M49 104 C53 100 58 100 60 106 C62 117 60 128 56 135 C52 137 48 136 46 132 C44 121 45 111 49 104 Z",
        "M45 141 C49 139 54 139 56 143 C56 158 52 175 48 187 C45 189 42 188 41 185 C39 170 40 155 45 141 Z",
        "M86 101 h10 a2 2 0 0 1 2 2 v12 h-12 a3 3 0 0 1 -3 -3 v-8 a3 3 0 0 1 3 -3 Z M86 119 h12 v14 h-12 a3 3 0 0 1 -3 -3 v-8 a3 3 0 0 1 3 -3 Z M86 137 h12 v14 h-12 a3 3 0 0 1 -3 -3 v-8 a3 3 0 0 1 3 -3 Z M87 155 h11 v18 c-5 0 -11 -3 -12 -8 v-7 a3 3 0 0 1 1 -3 Z",
        "M70 101 C75 104 79 106 80 110 L80 160 C78 166 75 168 72 166 C67 150 66 121 70 101 Z",
        "M71 181 C79 176 92 178 96 186 C98 211 94 240 88 258 C82 262 76 262 72 258 C64 236 63 205 71 181 Z",
        "M72 276 C78 272 86 274 88 280 C88 300 84 330 80 349 C77 351 74 351 72 347 C68 326 68 296 72 276 Z",
    ].map(SVGPath.parse)

    private static let back: [Path] = [
        "M100 45 C94 52 82 58 67 62 C80 66 92 76 100 102 Z",
        "M64 62 C53 63 45 72 45 86 C45 92 46 96 49 99 C53 88 59 80 68 74 C69 69 67 64 64 62 Z",
        "M71 78 C80 84 91 97 98 106 L98 132 C92 140 84 146 78 148 C72 130 67 101 71 78 Z",
        "M49 104 C53 100 58 100 61 106 C63 117 61 128 57 135 C53 137 48 136 46 132 C44 121 45 111 49 104 Z",
        "M45 141 C49 139 54 139 56 143 C56 158 52 175 48 187 C45 189 42 188 41 185 C39 170 40 155 45 141 Z",
        "M85 138 C90 139 95 140 98 142 L98 166 C92 167 86 165 83 161 C83 152 83 145 85 138 Z",
        "M72 170 C82 166 94 169 98 173 L98 205 C90 211 78 209 72 203 C68 193 68 180 72 170 Z",
        "M72 213 C80 211 92 213 95 217 C96 237 92 254 86 262 C80 264 76 263 73 260 C67 244 67 227 72 213 Z",
        "M72 276 C80 270 88 274 90 282 C90 300 86 320 80 342 C76 344 73 343 72 340 C66 318 66 294 72 276 Z",
    ].map(SVGPath.parse)
}

#Preview {
    HStack(spacing: 40) {
        BodyFigure(side: .front, levels: "234211131").frame(height: 238)
        BodyFigure(side: .back, levels: "3a4312321").frame(height: 238)
    }
    .padding()
}
