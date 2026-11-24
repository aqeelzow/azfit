import SwiftUI

/// The meal camera: detected foods tagged on the photo, and Div's suggestion of a matching photo from your library
/// for the meal you forgot to log. The prototype shows a still photo instead of the live camera.
/// Design: design/source/src/Snap.html
struct SnapMealView: View {
    @Environment(Router.self) private var router
    @State private var mode = "Photo"

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Image("chicken")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom)
                    .clipped()
                    .accessibilityLabel("Grilled chicken breast with roasted zucchini, peppers and lemon")
                LinearGradient(
                    colors: [AZColor.Camera.shade.opacity(0.55), AZColor.Camera.shade.opacity(0)], startPoint: .top, endPoint: .bottom
                )
                .frame(height: 170)
                VStack {
                    Spacer()
                    LinearGradient(
                        stops: [
                            .init(color: AZColor.Camera.shade.opacity(0), location: 0),
                            .init(color: AZColor.Camera.shade.opacity(0.9), location: 0.5),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 330)
                }
            }
            .ignoresSafeArea()
        }
        .overlay { content }
        .environment(\.colorScheme, .dark)
        .background(AZColor.Camera.shade)
    }

    private var content: some View {
        VStack(spacing: 0) {
            TopBar {
                glassButton("xmark", "Close camera") { router.dismissCover() }
            } center: {
                HStack(spacing: 7) {
                    Image(systemName: "calendar").font(.system(size: 13, weight: .semibold))
                    Text("Adding to Thu, Nov 19 · dinner").font(.az(14, .semibold))
                }
                .foregroundStyle(.white)
                .padding(.leading, 12).padding(.trailing, 14)
                .frame(height: 36)
                .background(AZColor.Camera.scrim, in: .capsule)
                .fixedSize()
            } trailing: {
                glassButton("bolt", "Flash") {}
            }

            viewfinder.padding(.top, 34)

            Spacer(minLength: 12)

            HStack(spacing: 12) {
                PhotoTile(name: "wrap", size: 44, radius: 12)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Photo from Thu, 7:42 PM").font(.az(14.5, .bold)).foregroundStyle(.white)
                    Text("Found in your library. Use this?").font(.az(13)).foregroundStyle(AZColor.Camera.muted)
                }
                Spacer(minLength: 0)
                Button("Use it") { router.dismissCover(thenPush: .meal) }
                    .font(.az(14, .bold))
                    .foregroundStyle(AZColor.Camera.tagInk)
                    .padding(.horizontal, 14).frame(height: 34)
                    .background(.white, in: .capsule)
                    .buttonStyle(.plain)
            }
            .padding(10)
            .background(AZColor.Camera.card, in: .rect(cornerRadius: 22, style: .continuous))
            .padding(.horizontal, 16)

            HStack(spacing: 4) {
                ForEach(["Barcode", "Photo", "Describe"], id: \.self) { name in
                    Button(name) { mode = name }
                        .font(.az(14, .semibold))
                        .foregroundStyle(mode == name ? AZColor.Camera.tagInk : .white.opacity(0.62))
                        .padding(.horizontal, 14).frame(height: 34)
                        .background(mode == name ? Color.white : .clear, in: .capsule)
                        .buttonStyle(.plain)
                }
            }
            .padding(.top, 16)

            HStack {
                glassButton("photo", "Choose from photos", size: 52) { router.dismissCover(thenPush: .meal) }
                Spacer()
                Button {
                    router.dismissCover(thenPush: .meal)
                } label: {
                    RoundedRectangle(cornerRadius: 21, style: .continuous).fill(.white).frame(width: 62, height: 62)
                        .frame(width: 80, height: 80)
                        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(.white, lineWidth: 4))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Take photo")
                Spacer()
                glassButton("text.alignleft", "Describe instead", size: 52) { router.dismissCover(thenPush: .meal) }
            }
            .padding(.horizontal, 36)
            .padding(.top, 34)
            .padding(.bottom, 12)
        }
    }

    /// The four corner brackets and the food tags the camera found.
    private var viewfinder: some View {
        ZStack(alignment: .topLeading) {
            Brackets().stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            tag("Peppers, carrots").offset(x: 68, y: 40)
            tag("Grilled chicken").offset(x: 148, y: 90)
            tag("Zucchini").offset(x: 18, y: 154)
        }
        .frame(height: 364)
        .padding(.horizontal, 28)
    }

    private func tag(_ text: String) -> some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 1.5).fill(AZColor.accent).frame(width: 3, height: 14)
            Text(text).font(.az(13, .bold))
        }
        .foregroundStyle(AZColor.Camera.tagInk)
        .padding(.leading, 9).padding(.trailing, 11)
        .frame(height: 30)
        .background(AZColor.Camera.tag, in: .rect(cornerRadius: 10, style: .continuous))
        .fixedSize()
    }

    private func glassButton(_ systemImage: String, _ label: String, size: CGFloat = 44, action: @escaping () -> Void) -> some View {
        IconButton(
            systemImage: systemImage, label: label, size: size,
            background: size > 44 ? AZColor.Camera.glass : AZColor.Camera.scrim, foreground: .white, action: action)
    }

    private struct Brackets: Shape {
        func path(in rect: CGRect) -> Path {
            let arm: CGFloat = 34
            let r: CGFloat = 18
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
    SnapMealView().environment(Router())
}
