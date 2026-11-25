// AZSync: how the phone and the Mac bridge talk (docs/decisions.md D-006).
//
// - `PairingCode`: what the bridge shows as a QR code. It carries a random 32-byte key.
// - `Channel`: one connection over TLS with that key as a pre-shared key, so only a paired phone gets in and
//   nothing on the network can read the traffic. Frames are a 4-byte length and then JSON.
// - `Message`: what goes over a channel. The phone says hello, the bridge answers with its status, and the
//   phone sends requests (Div jobs) that the bridge answers.
//
// TODO: sync the database (rows after the last sequence each side saw) once AZStore exists.

/// Changes when a message changes in a way an older peer can't read.
public enum WireVersion {
    public static let current = 1
}

/// The Bonjour service the bridge advertises on the local network.
public enum BridgeService {
    public static let type = "_azfit-bridge._tcp"
    /// The port the bridge tries first, so a phone can also reach it by address (Tailscale) when Bonjour can't.
    public static let preferredPort: UInt16 = 47_820
    /// The TXT record key holding the bridge's ID, so a phone finds its own bridge among several.
    public static let idKey = "id"
}
