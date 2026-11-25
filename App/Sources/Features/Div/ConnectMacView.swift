import AZSync
import SwiftUI
import VisionKit

/// "Your Mac": pair with AZfit Bridge, see whether Div can run, or forget the Mac.
struct ConnectMacView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TopBar(title: "Your Mac") {
                BackButton()
            } trailing: {
                Color.clear.frame(width: 44, height: 44)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Div runs on your Claude plan through AZfit Bridge, a free app on your Mac.")
                        .font(.az(15.5)).foregroundStyle(AZColor.muted).fixedSize(horizontal: false, vertical: true)
                    MacPairingPanel()
                    if environment.bridge.code != nil {
                        Button("Forget this Mac") { environment.bridge.forget() }
                            .font(.az(15, .semibold)).foregroundStyle(AZColor.muted).buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.top, 16)
            }
        }
        .azScreen()
    }
}

/// The pairing steps and the live connection card. Used in onboarding and on "Your Mac".
struct MacPairingPanel: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var isScanning = false
    @State private var problem: String?

    private var bridge: BridgeConnection { environment.bridge }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if bridge.code == nil {
                HairlineStack {
                    step(1, "Install AZfit Bridge on your Mac")
                    step(2, "Sign in to Claude from its menu")
                    step(3, "Choose Pair a phone, then scan the code")
                }
                HStack(spacing: 10) {
                    if Self.canScan {
                        PrimaryButton(title: "Scan code", trailingImage: "qrcode.viewfinder", style: .accent) { isScanning = true }
                    }
                    // PasteButton reads the clipboard without iOS's "Allow Paste" prompt, which returns nothing when denied.
                    PasteButton(payloadType: String.self) { strings in
                        guard let text = strings.first else {
                            problem = "Nothing to paste. In AZfit Bridge, choose Pair a phone, then Copy code."
                            return
                        }
                        pair(text)
                    }
                    .labelStyle(.titleOnly)
                    .buttonBorderShape(.capsule)
                    .controlSize(.extraLarge)
                    .tint(AZColor.accent)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Paste code")
                }
                if let problem {
                    Text(problem).font(.az(13.5)).foregroundStyle(AZColor.muted).fixedSize(horizontal: false, vertical: true)
                }
            } else {
                BridgeStatusCard()
            }
        }
        .sheet(isPresented: $isScanning) {
            QRScannerView { text in
                isScanning = false
                pair(text)
            }
            .ignoresSafeArea()
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.az(13, .heavy))
                .foregroundStyle(AZColor.divInk)
                .frame(width: 26, height: 26)
                .background(AZColor.divTint, in: .rect(cornerRadius: 9, style: .continuous))
            Text(text).font(.az(15, .semibold))
            Spacer(minLength: 0)
        }
        .frame(height: 54)
    }

    private func pair(_ text: String) {
        do {
            try bridge.pair(text: text)
            problem = nil
        } catch {
            problem = error.description
        }
    }

    /// The camera scanner needs a real iPhone; the simulator pastes instead.
    static var canScan: Bool { DataScannerViewController.isSupported }
}

/// Connected, connecting, or why not. Lavender only when Div can answer.
struct BridgeStatusCard: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        let bridge = environment.bridge
        let name = bridge.bridgeName ?? "your Mac"
        let (title, detail, icon, ready) = Self.describe(bridge.state, name: name)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ready ? .white : AZColor.muted)
                    .frame(width: 36, height: 36)
                    .background(ready ? AZColor.accent : AZColor.track, in: .rect(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.az(15, .bold))
                    Text(detail).font(.az(13.5)).foregroundStyle(ready ? AZColor.divMuted : AZColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            if case .offline = bridge.state {
                PillButton(title: "Try again", style: .card) { bridge.connect() }
            }
        }
        .padding(EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 16))
        .background(ready ? AZColor.divTint : AZColor.fill, in: .rect(cornerRadius: 22, style: .continuous))
    }

    static func describe(_ state: BridgeConnection.State, name: String) -> (String, String, String, Bool) {
        switch state {
        case .unpaired:
            ("Not paired", "Pair with AZfit Bridge on your Mac.", "laptopcomputer", false)
        case .connecting:
            ("Connecting to \(name)", "Looking on this network.", "wifi", false)
        case .connected(let status):
            switch status.claude {
            case .ready: ("Connected · \(status.bridgeName)", "Claude is signed in. Div is ready.", "wifi", true)
            case .signedOut:
                ("Connected · \(status.bridgeName)", "Claude is signed out. Sign in from the AZfit Bridge menu.", "wifi", false)
            case .notInstalled: ("Connected · \(status.bridgeName)", "Install Claude Code on your Mac, then sign in.", "wifi", false)
            case .unknown: ("Connected · \(status.bridgeName)", "Checking Claude on your Mac.", "wifi", false)
            }
        case .offline(let reason):
            ("\(name) isn't reachable", reason, "wifi.slash", false)
        }
    }
}

/// The camera, looking for the bridge's QR code.
struct QRScannerView: UIViewControllerRepresentable {
    var onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])], qualityLevel: .fast, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        private var done = false

        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func dataScanner(_ scanner: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in items {
                if case .barcode(let code) = item, let text = code.payloadStringValue, text.hasPrefix(PairingCode.prefix), !done {
                    done = true
                    scanner.stopScanning()
                    onCode(text)
                }
            }
        }
    }
}

#Preview {
    NavigationStack { ConnectMacView() }.environment(AppEnvironment.preview()).environment(Router())
}
