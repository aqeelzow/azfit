import AZModel
import AZSync
import Foundation
import Observation

/// The conversation with Div: what you said, what Div answered, and the changes it made on the way.
@MainActor
@Observable
final class ChatSession {
    struct Entry: Identifiable, Equatable {
        enum Kind: Equatable {
            case mine(String)
            case div(ChatReply)
            /// Div couldn't answer (Mac asleep, Claude signed out). Shown quietly, not as Div talking.
            case problem(String)
        }

        let id = UUID()
        let kind: Kind
        let date: Date
    }

    private(set) var entries: [Entry] = []
    private(set) var isWaiting = false
    private let bridge: BridgeConnection
    /// Called when a reply saved changes on the Mac, so the app syncs them back and screens refresh.
    var onChange: () -> Void = {}

    init(bridge: BridgeConnection) {
        self.bridge = bridge
    }

    func send(_ text: String) async {
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, !isWaiting else { return }
        let request = ChatRequest(message: message, history: history)
        entries.append(Entry(kind: .mine(message), date: .now))
        isWaiting = true
        defer { isWaiting = false }
        do {
            switch try await bridge.ask(.chat(request)) {
            case .chat(let reply):
                entries.append(Entry(kind: .div(reply), date: .now))
                if reply.saved.contains(where: { $0 != nil }) || !reply.remember.isEmpty { onChange() }
            case .failed(let reason): entries.append(Entry(kind: .problem(reason), date: .now))
            case .synced: break
            }
        } catch {
            entries.append(Entry(kind: .problem("\(error)"), date: .now))
        }
    }

    /// What Div sees of the conversation so far. Problems are left out: Div never said them.
    var history: [ChatMessage] {
        entries.compactMap { entry in
            switch entry.kind {
            case .mine(let text): ChatMessage(role: .user, text: text)
            case .div(let reply): ChatMessage(role: .div, text: reply.reply)
            case .problem: nil
            }
        }
    }
}
