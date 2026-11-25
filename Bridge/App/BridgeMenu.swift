import AZSync
import BridgeKit
import SwiftUI

struct BridgeMenu: View {
    @Environment(BridgeModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AZfit Bridge").font(.headline)

            LabeledContent("Claude", value: model.claude.label)
            switch model.claude {
            case .signedOut:
                Button("Sign in to Claude…") { model.signIn() }
            case .notInstalled:
                Button("Install Claude Code…") { model.openInstallPage() }
            case .ready, .unknown:
                EmptyView()
            }

            LabeledContent("Phone", value: model.phoneSummary)
            if let problem = model.server.problem {
                Text(problem).font(.caption).foregroundStyle(.red)
            }

            let paired = model.pairings.filter { $0.phoneName != nil }
            if !paired.isEmpty {
                Divider()
                ForEach(paired) { pairing in
                    HStack {
                        Text(pairing.phoneName ?? "Phone")
                        Spacer()
                        Button("Forget") { model.forget(pairing) }.controlSize(.small)
                    }
                }
            }

            Divider()
            Button("Pair a phone…") {
                model.showNewCode()
                openWindow(id: PairView.windowID)
                NSApp.activate()
            }
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .padding(16)
        .frame(width: 280)
        .task { await model.refreshClaude() }
    }
}
