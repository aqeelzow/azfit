import AZModel
import AZStore
import AZSync
import SwiftUI

/// Chat with Div, through AZfit Bridge on the Mac. When Div changes the plan from a message, the change shows
/// as a card under its reply.
/// Design: design/source/src/Coach.html
struct DivChatView: View {
    @Environment(Router.self) private var router
    @Environment(AppEnvironment.self) private var environment
    @State private var draft = ""
    @State private var chatProblem: String?
    @FocusState private var isTyping: Bool

    private var chat: ChatSession { environment.chat }
    private var bridge: BridgeConnection { environment.bridge }

    var body: some View {
        VStack(spacing: 0) {
            TopBar {
                BackButton()
            } center: {
                Button {
                    router.push(.connectMac)
                } label: {
                    TopBarTitle(title: "Div", subtitle: subtitle)
                }
                .buttonStyle(.plain)
            } trailing: {
                IconButton(systemImage: "mic", label: "Talk to Div") { router.present(.voice) }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !bridge.isReady {
                        BridgeStatusCard()
                        if bridge.code == nil {
                            PillButton(title: "Connect your Mac", trailingImage: "chevron.right", style: .fill) { router.push(.connectMac) }
                        }
                    }
                    if chat.entries.isEmpty {
                        divHeader(time: nil)
                        divText("Ask me why anything changed, tell me what hurts, or ask for a change to your plan.")
                    }
                    ForEach(chat.entries) { entry in
                        switch entry.kind {
                        case .mine(let text):
                            mine(text)
                        case .div(let reply):
                            divHeader(time: entry.date)
                            divText(reply.reply)
                            ForEach(Array(reply.changes.enumerated()), id: \.offset) { i, checked in
                                if checked.verdict != .refuse {
                                    changeCard(checked, id: i < reply.saved.count ? reply.saved[i] : nil)
                                }
                            }
                        case .problem(let text):
                            Text(text).font(.az(13.5)).foregroundStyle(AZColor.muted).frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                        }
                    }
                    if let chatProblem {
                        Text(chatProblem).font(.az(13.5)).foregroundStyle(AZColor.muted).frame(maxWidth: .infinity)
                    }
                    if chat.isWaiting {
                        HStack(spacing: 8) {
                            DivAvatar(size: 26, mood: .side)
                            Text("Thinking…").font(.az(14, .medium)).foregroundStyle(AZColor.faint)
                        }
                    }
                }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.top, 22)
                .padding(.bottom, 16)
                .animation(.snappy(duration: 0.2), value: chat.entries)
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)

            composer
        }
        .azScreen()
    }

    private var subtitle: String {
        switch bridge.state {
        case .connected(let status): status.claude == .ready ? "on \(status.bridgeName)" : "Claude signed out"
        case .connecting: "Connecting…"
        case .offline: "Mac offline"
        case .unpaired: "Not connected"
        }
    }

    private func send() {
        let text = draft
        draft = ""
        Task { await chat.send(text) }
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

    private func divHeader(time: Date?) -> some View {
        HStack(spacing: 8) {
            DivAvatar(size: 26)
            Text("Div").font(.az(14, .bold))
            if let time { Text(time, format: .dateTime.hour().minute()).font(.az(13, .medium)).foregroundStyle(AZColor.faint) }
        }
    }

    private func divText(_ text: String) -> some View {
        Text(text).font(.az(15.5)).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
    }

    /// A change Div made (lavender, with Undo) or suggests (neutral, with Approve). The buttons act on the saved
    /// change, which syncs back from the Mac after the reply.
    private func changeCard(_ checked: Checked<Proposal>, id: UUID?) -> some View {
        let status = id.flatMap(changeStatus) ?? (checked.verdict == .apply ? .applied : .proposed)
        let applied = status == .applied || status == .approved
        let summary = checked.item.change.summary
        return HStack(spacing: 12) {
            Image(systemName: Self.icon(checked.item.change))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(applied ? .white : AZColor.muted)
                .frame(width: 36, height: 36)
                .background(applied ? AZColor.accent : AZColor.track, in: .rect(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(summary.title).font(.az(14.5, .bold))
                Text(Self.detail(summary.detail, status)).font(.az(13)).foregroundStyle(applied ? AZColor.divMuted : AZColor.muted)
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            if let id {
                switch status {
                case .applied, .approved:
                    Button("Undo") { act(id) { try environment.store.undo(id) } }
                        .font(.az(13.5, .bold)).foregroundStyle(AZColor.divInk).buttonStyle(.plain)
                case .proposed:
                    Button("Approve") { act(id) { try environment.store.approve(id, today: Day.string(.now)) } }
                        .font(.az(13.5, .bold)).foregroundStyle(AZColor.ink).buttonStyle(.plain)
                case .declined, .undone:
                    EmptyView()
                }
            }
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .background(applied ? AZColor.divTint : AZColor.fill, in: .rect(cornerRadius: 20, style: .continuous))
    }

    private func changeStatus(_ id: UUID) -> DivChange.Status? {
        _ = environment.revision  // read so the card updates after Undo, Approve or a sync
        return try? environment.store.divChange(id)?.status
    }

    private static func detail(_ detail: String, _ status: DivChange.Status) -> String {
        switch status {
        case .applied, .approved: detail
        case .proposed: "Suggested · \(detail)"
        case .undone: "Undone · \(detail)"
        case .declined: "Not now · \(detail)"
        }
    }

    /// Fetches the change from the Mac if it hasn't arrived yet, then acts on it.
    private func act(_ id: UUID, _ action: @escaping () throws -> Void) {
        Task {
            if (try? environment.store.divChange(id)) == nil { try? await environment.bridge.sync() }
            do {
                try action()
            } catch {
                chatProblem = "Couldn't do that: \(error)"
            }
            environment.changed()
        }
    }

    private static func icon(_ change: PlanChange) -> String {
        switch change {
        case .swapExercise: "arrow.left.arrow.right"
        case .moveSession: "calendar"
        case .setLoad: "scalemass"
        case .changeVolume: "chart.bar"
        case .scheduleDeload: "arrow.down.right"
        case .setCalorieTarget, .setProteinTarget: "fork.knife"
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Chip(title: "Why did my calories change?") { draft = "Why did my calories change?" }
                    Chip(title: "What did you change?") { router.push(.divLog) }
                }
                .padding(.horizontal, AZSpacing.gutter)
            }
            .scrollIndicators(.hidden)

            HStack(spacing: 8) {
                IconButton(systemImage: "plus", label: "Attach photo", size: 52) { router.present(.snap) }
                HStack(spacing: 8) {
                    TextField("Message Div", text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .font(.az(15.5))
                        .textFieldStyle(.plain)
                        .focused($isTyping)
                        .submitLabel(.send)
                        .onSubmit(send)
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
                .frame(minHeight: 52)
                .background(AZColor.fill, in: .rect(cornerRadius: 18, style: .continuous))
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(canSend ? AZColor.accent : AZColor.accentSoft, in: .rect(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityLabel("Send")
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var canSend: Bool {
        bridge.isReady && !chat.isWaiting && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#Preview {
    NavigationStack { DivChatView() }.environment(Router()).environment(AppEnvironment.preview())
}
