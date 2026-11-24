import SwiftUI

/// Chat with Div. When Div changes the plan from a message, the change shows as a tool card you can undo right there.
/// Design: design/source/src/Coach.html
struct DivChatView: View {
    @Environment(Router.self) private var router
    @State private var isUndone = false
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            TopBar {
                BackButton()
            } center: {
                Button {
                    router.push(.memory)
                } label: {
                    TopBarTitle(title: "Div", subtitle: "Opus · on your MacBook")
                }
                .buttonStyle(.plain)
            } trailing: {
                IconButton(systemImage: "mic", label: "Talk to Div") { router.present(.voice) }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    day("Tuesday")
                    mine("Shoulder felt tight on overhead press today.")
                    divHeader(time: "8:12 PM")
                    divText("Thanks for telling me. I'll take overhead pressing out for two weeks.")
                    toolCard
                    divText("Same movement pattern, less strain. Tell me how it feels Saturday.")
                    day("Today").padding(.top, 4)
                    mine("Why did my calories go up?")
                    divHeader(time: "9:40 AM")
                    divText("You've lost 0.7 kg a week for 3 weeks. Faster than that starts to cost muscle, so I added 150 kcal.")
                    PillButton(title: "See the math", trailingImage: "chevron.right", style: .fill) { router.push(.calorieTarget) }
                }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.top, 22)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.bottom)

            composer
        }
        .azScreen()
    }

    private func day(_ text: String) -> some View {
        Text(text).font(.az(12.5, .semibold)).foregroundStyle(AZColor.faint).frame(maxWidth: .infinity)
    }

    private func mine(_ text: String) -> some View {
        Text(text)
            .font(.az(15.5))
            .foregroundStyle(AZColor.buttonInk)
            .padding(.vertical, 11)
            .padding(.horizontal, 16)
            .background(
                AZColor.button,
                in: UnevenRoundedRectangle(
                    topLeadingRadius: 22, bottomLeadingRadius: 22, bottomTrailingRadius: 6, topTrailingRadius: 22, style: .continuous)
            )
            .frame(maxWidth: 262, alignment: .trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func divHeader(time: String) -> some View {
        HStack(spacing: 8) {
            DivAvatar(size: 26)
            Text("Div").font(.az(14, .bold))
            Text(time).font(.az(13, .medium)).foregroundStyle(AZColor.faint)
        }
    }

    private func divText(_ text: String) -> some View {
        Text(text).font(.az(15.5)).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
    }

    /// The change Div made from this conversation, undoable in place. Lavender while it stands, neutral once undone.
    private var toolCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(isUndone ? AZColor.faint : .white)
                .frame(width: 36, height: 36)
                .background(isUndone ? AZColor.track : AZColor.accent, in: .rect(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(isUndone ? "Overhead press is back" : "Swapped in landmine press").font(.az(14.5, .bold))
                Text(isUndone ? "Plan restored · you undid this" : "For overhead press · 2 weeks")
                    .font(.az(13)).foregroundStyle(isUndone ? AZColor.muted : AZColor.divMuted)
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            PillButton(title: isUndone ? "Redo" : "Undo") {
                withAnimation(.snappy(duration: 0.2)) { isUndone.toggle() }
            }
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 12))
        .background(isUndone ? AZColor.fill : AZColor.divTint, in: .rect(cornerRadius: 20, style: .continuous))
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Chip(title: "Plan my dinner") { router.show(.eat) }
                    Chip(title: "What did you change?") { router.push(.divLog) }
                }
                .padding(.horizontal, AZSpacing.gutter)
            }
            .scrollIndicators(.hidden)

            HStack(spacing: 8) {
                IconButton(systemImage: "plus", label: "Attach photo", size: 52) { router.present(.snap) }
                HStack(spacing: 8) {
                    TextField("Message Div", text: $draft)
                        .font(.az(15.5))
                        .textFieldStyle(.plain)
                    Button {
                        router.present(.voice)
                    } label: {
                        Image(systemName: "mic").font(.system(size: 18, weight: .medium)).foregroundStyle(AZColor.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Talk")
                }
                .padding(.leading, 16)
                .padding(.trailing, 14)
                .frame(height: 52)
                .background(AZColor.fill, in: .rect(cornerRadius: 18, style: .continuous))
                Button {
                    draft = ""
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(AZColor.accent, in: .rect(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Send")
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

#Preview {
    NavigationStack { DivChatView() }.environment(Router())
}
