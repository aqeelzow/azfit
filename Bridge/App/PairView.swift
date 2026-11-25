import AZSync
import AppKit
import BridgeKit
import CoreImage.CIFilterBuiltins
import SwiftUI

/// "Pair a phone": a QR code to scan with AZfit, and the same code as text for the simulator.
struct PairView: View {
    static let windowID = "pair"

    @Environment(BridgeModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        VStack(spacing: 16) {
            if let code = model.code {
                Text("Scan with AZfit").font(.title2.bold())
                Text("Point your iPhone's camera at the code, or in AZfit tap Scan code.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                if let image = Self.qrImage(code.text) {
                    Image(nsImage: image)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 220, height: 220)
                        .accessibilityLabel("Pairing QR code")
                }
                Button(copied ? "Copied" : "Copy code for the simulator") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code.text, forType: .string)
                    copied = true
                }
                Text("The code works once and expires in 15 minutes. Anyone with it can use Div on this Mac.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "checkmark.circle").font(.system(size: 40)).foregroundStyle(.green)
                Text(model.server.phones.last.map { "\($0.name) is paired" } ?? "No code showing").font(.title3.bold())
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 320)
        .onDisappear {
            model.closeCode()
            copied = false
        }
    }

    static func qrImage(_ text: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let rep = NSCIImageRep(ciImage: scaled)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }
}
