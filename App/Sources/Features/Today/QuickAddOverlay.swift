import SwiftUI

/// The panel behind the purple plus: Div's suggested log on top, then six ways to log.
/// Design: design/source/src/QuickAdd.html
struct QuickAddOverlay: View {
    @Bindable var router: Router

    var body: some View {
        ZStack(alignment: .bottom) {
            if router.isQuickAddOpen {
                AZColor.Camera.scrim
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .transition(.opacity)
                panel.transition(.move(edge: .bottom))
            }
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule().fill(AZColor.track).frame(width: 40, height: 5).frame(maxWidth: .infinity).padding(.top, 8)
            Text("What are we logging?")
                .font(.az(24, .heavy)).tracking(-0.48)
                .padding(.top, 19).padding(.horizontal, 4)
            Button {
                router.present(.snap)
            } label: {
                DivNote(title: "Log Thursday's dinner?", message: "You logged about half your usual.", actionsOnRight: true) {
                    Image(systemName: "chevron.right").font(.system(size: 15, weight: .semibold)).foregroundStyle(AZColor.divMuted)
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 22)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                option("Snap a meal", "camera", isDiv: true) { router.present(.snap) }
                option("Describe food", "text.alignleft") { router.push(.meal) }
                option("Say it", "mic") { router.present(.voice) }
                option("Start Push A", "dumbbell") { router.push(.workout) }
                option("Weigh in", "scalemass") { router.push(.progress) }
                Button {
                    router.push(.chat)
                } label: {
                    row(title: "Ask Div", tint: false) { DivAvatar(size: 38, cornerRatio: 0.32) }
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 14)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .frame(height: 544, alignment: .top)
        .background(AZColor.background, in: UnevenRoundedRectangle(topLeadingRadius: 36, topTrailingRadius: 36, style: .continuous))
        .ignoresSafeArea(edges: .bottom)
    }

    private func option(_ title: String, _ systemImage: String, isDiv: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            row(title: title, tint: isDiv) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .foregroundStyle(isDiv ? Color.white : AZColor.ink)
                    .background(isDiv ? AZColor.accent : AZColor.card, in: .rect(cornerRadius: 12, style: .continuous))
            }
        }
        .buttonStyle(.plain)
    }

    private func row<Icon: View>(title: String, tint: Bool, @ViewBuilder icon: () -> Icon) -> some View {
        HStack(spacing: 12) {
            icon()
            Text(title).font(.az(15, .bold)).lineLimit(1).minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 64)
        .background(tint ? AZColor.divTint : AZColor.fill, in: .rect(cornerRadius: 20, style: .continuous))
        .contentShape(.rect)
    }

    private func close() {
        withAnimation(.snappy(duration: 0.28)) { router.isQuickAddOpen = false }
    }
}
