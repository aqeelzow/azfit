import AZSync
import Foundation
import Security

/// Keeps the pairing code in the Keychain: it holds the key that lets this phone use Div on the Mac.
/// This device only, and readable after the first unlock so a reconnect in the background works.
nonisolated struct KeychainPairingStorage: PairingStorage {
    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.azfit.bridge-pairing",
            kSecAttrAccount as String: "bridge",
        ]
    }

    func load() -> PairingCode? {
        var search = query
        search[kSecReturnData as String] = true
        search[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(search as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? PairingCode(text: String(decoding: data, as: UTF8.self))
    }

    func save(_ code: PairingCode?) {
        SecItemDelete(query as CFDictionary)
        guard let code else { return }
        var item = query
        item[kSecValueData as String] = Data(code.text.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }
}
