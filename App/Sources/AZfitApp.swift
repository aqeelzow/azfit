import SwiftUI

@main
struct AZfitApp: App {
    @State private var environment = AppEnvironment.live()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .tint(AZColor.accent)
                // A pairing code opened as a link (the Camera app scanned the bridge's QR code).
                .onOpenURL { url in try? environment.bridge.pair(text: url.absoluteString) }
        }
        // Talk to the Mac while the app is open. Away from the app, the bridge runs the Sunday review on its own.
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active:
                environment.bridge.connect()
                environment.syncHealth()
            case .background: environment.bridge.stop()
            default: break
            }
        }
    }
}
