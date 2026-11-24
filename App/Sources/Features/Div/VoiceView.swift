import SwiftUI

/// Talk to Div: live transcript and Div's spoken answer, shown as a note. Always dark.
/// Design: design/source/src/Voice.html
struct VoiceView: View {
    @Environment(Router.self) private var router
    @State private var isListening = true

    private let bars: [(CGFloat, Double)] = [
        (14, 0.5), (26, 0.7), (42, 1), (58, 1), (36, 1), (50, 1), (64, 1), (40, 1), (28, 1), (46, 1), (22, 0.7), (12, 0.5),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TopBar {
                IconButton(systemImage: "chevron.down", label: "Back to chat") { router.dismissCover() }
            } center: {
                TopBarTitle(title: "Div", subtitle: isListening ? "Listening" : "Paused")
            } trailing: {
                IconButton(systemImage: "slider.horizontal.3", label: "Voice settings") { router.dismissCover(thenPush: .memory) }
            }

            VStack(spacing: 22) {
                DivAvatar(size: 120)
                HStack(spacing: 5) {
                    ForEach(bars.indices, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AZColor.accent.opacity(bars[i].1))
                            .frame(width: 6, height: isListening ? bars[i].0 : 6)
                    }
                }
                .frame(height: 64)
                .accessibilityHidden(true)
            }
            .padding(.top, 44)

            VStack(alignment: .leading, spacing: 22) {
                Text("Can I go heavier\non squats \(Text("today?").foregroundStyle(AZColor.faint))")
                    .font(.az(26, .bold)).tracking(-0.52).lineSpacing(4)
                DivNote(
                    title: "Keep 100 kg, add a back-off set",
                    message: "Your legs did 14 hard sets on Thursday. One more set at 90 kg gets the extra work without the risk.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AZSpacing.gutter)
            .padding(.top, 40)

            Spacer(minLength: 16)

            HStack(spacing: 28) {
                roundButton("text.alignleft", "Type instead") { router.dismissCover(thenPush: .chat) }
                Button {
                    withAnimation(.snappy(duration: 0.25)) { isListening.toggle() }
                } label: {
                    Image(systemName: isListening ? "mic" : "mic.slash")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 84, height: 84)
                        .background(AZColor.accent, in: .rect(cornerRadius: 28, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isListening ? "Pause listening" : "Resume listening")
                roundButton("xmark", "End") { router.dismissCover() }
            }
            .padding(.bottom, 22)
        }
        .azScreen()
    }

    private func roundButton(_ systemImage: String, _ label: String, action: @escaping () -> Void) -> some View {
        IconButton(systemImage: systemImage, label: label, size: 64, action: action)
    }
}

#Preview {
    VoiceView().environment(Router()).preferredColorScheme(.dark)
}
