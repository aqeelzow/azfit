import AZModel
import Foundation

/// What the bridge shows when you pair a phone: a QR code, or text to paste in the simulator.
/// Anyone holding it can talk to the bridge, so it is shown once and never sent over the network.
public struct PairingCode: Codable, Sendable, Equatable {
    public static let prefix = "azfit-pair:"

    public var version: Int
    /// Stays the same for the bridge's lifetime. The phone looks for it in the Bonjour TXT record.
    public var bridgeID: UUID
    public var bridgeName: String
    /// One per pairing. Sent as the TLS pre-shared key identity, so the bridge knows which key to use.
    public var pairingID: UUID
    /// 32 random bytes, the TLS pre-shared key.
    public var key: Data
    /// Addresses to try when Bonjour finds nothing (a Tailscale name or IP), with `port`.
    public var hosts: [String]
    public var port: UInt16

    public init(
        bridgeID: UUID, bridgeName: String, pairingID: UUID = UUID(), key: Data = PairingCode.newKey(), hosts: [String] = [],
        port: UInt16 = BridgeService.preferredPort
    ) {
        self.version = WireVersion.current
        self.bridgeID = bridgeID
        self.bridgeName = bridgeName
        self.pairingID = pairingID
        self.key = key
        self.hosts = hosts
        self.port = port
    }

    public static func newKey() -> Data {
        var generator = SystemRandomNumberGenerator()
        return Data((0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) })
    }

    public enum Failure: Error, Equatable, CustomStringConvertible {
        case notAPairingCode
        case unreadable
        case newerVersion(Int)
        case badKey

        public var description: String {
            switch self {
            case .notAPairingCode: "That isn't an AZfit pairing code."
            case .unreadable: "The pairing code is damaged. Copy it again from the bridge."
            case .newerVersion: "This pairing code is from a newer AZfit Bridge. Update the app."
            case .badKey: "The pairing code's key is the wrong length."
            }
        }
    }

    /// `azfit-pair:` and then the JSON, base64url-encoded, so it survives QR codes and copy and paste.
    public var text: String {
        let json = (try? DivJSON.encode(self, pretty: false)) ?? Data()
        return Self.prefix + json.base64URLEncoded
    }

    public init(text: String) throws(Failure) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(Self.prefix) else { throw .notAPairingCode }
        guard let data = Data(base64URLEncoded: String(trimmed.dropFirst(Self.prefix.count))),
            let code = try? DivJSON.decode(PairingCode.self, from: data)
        else { throw .unreadable }
        guard code.version <= WireVersion.current else { throw .newerVersion(code.version) }
        guard code.key.count == 32 else { throw .badKey }
        self = code
    }
}

extension Data {
    var base64URLEncoded: String {
        base64EncodedString().replacing("+", with: "-").replacing("/", with: "_").replacing("=", with: "")
    }

    init?(base64URLEncoded text: String) {
        var base64 = text.replacing("-", with: "+").replacing("_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        self.init(base64Encoded: base64)
    }
}
