import SwiftUI
import VisionKit

/// Scans a food barcode with the camera, or takes it typed in where the camera can't scan (the simulator, or a
/// smudged label).
struct BarcodeScannerSheet: View {
    var onCode: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var typed = ""
    @State private var typing = false

    private var canScan: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Scan a barcode").font(.az(17, .heavy))
                Spacer()
                PillButton(title: "Cancel", style: .fill) { dismiss() }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            if canScan && !typing {
                BarcodeCamera { onCode($0) }
                    .clipShape(.rect(cornerRadius: 24, style: .continuous))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                Text("Point the camera at the barcode on the package.")
                    .font(.az(14.5)).foregroundStyle(AZColor.muted).padding(.top, 12)
                PillButton(title: "Type the numbers instead", style: .fill) { typing = true }.padding(.vertical, 12)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if !canScan {
                        Text("This device can't scan with its camera. Type the numbers under the barcode.")
                            .font(.az(14.5)).foregroundStyle(AZColor.muted)
                    }
                    TextField("", text: $typed, prompt: Text("Barcode numbers").foregroundStyle(AZColor.faint))
                        .keyboardType(.numberPad)
                        .font(.az(20, .heavy))
                        .monospacedDigit()
                        .padding(.horizontal, 16)
                        .frame(height: 56)
                        .background(AZColor.fill, in: .rect(cornerRadius: 16, style: .continuous))
                    PrimaryButton(title: "Look it up") { onCode(digits) }
                        .disabled(digits.count < 6)
                        .opacity(digits.count < 6 ? 0.4 : 1)
                        .padding(.top, 8)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .azScreen()
    }

    private var digits: String { typed.filter(\.isNumber) }
}

/// VisionKit's live scanner, reporting the first product barcode it sees.
private struct BarcodeCamera: UIViewControllerRepresentable {
    var onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128, .code39, .itf14])],
            qualityLevel: .balanced, recognizesMultipleItems: false, isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        private var reported = false

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
        }

        func dataScanner(_ scanner: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !reported else { return }
            for item in items {
                if case .barcode(let barcode) = item, let code = barcode.payloadStringValue?.filter(\.isNumber), code.count >= 6 {
                    reported = true
                    onCode(code)
                    return
                }
            }
        }
    }
}
