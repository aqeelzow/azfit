import BridgeKit
import SwiftUI

/// AZfit Bridge: a menu bar app. Pairs with the phone, keeps a copy of the data, and runs Div jobs through `claude -p`.
/// Keep this file thin. Logic belongs in BridgeKit where it is tested.
@main
struct BridgeApp: App {
    var body: some Scene {
        MenuBarExtra("AZfit Bridge", systemImage: "figure.strengthtraining.traditional") {
            BridgeMenu()
        }
        .menuBarExtraStyle(.window)
    }
}

struct BridgeMenu: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AZfit Bridge").font(.headline)
            LabeledContent("Phone", value: "Not paired")
            LabeledContent("Claude", value: "Checking…")
            LabeledContent("Queue", value: "0 jobs")
            Divider()
            Button("Pair a phone…") {}
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .padding(16)
        .frame(width: 260)
    }
}
