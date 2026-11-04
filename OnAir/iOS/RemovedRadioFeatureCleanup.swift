import Foundation
import Security

enum RemovedRadioFeatureCleanup {
    static func run() {
        SharedStore.defaults.removeObject(forKey: "quick-slots")
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "removed-music-recognition-cleanup") else { return }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "kr.davidkang.onair.audd", kSecAttrAccount as String: "personal-api-token"]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { return }
        for key in ["auto-song-recognition", "audd-migration-complete", "song-recognition-probe-status", "song-recognition-probe-match", "song-recognition-probe-error", "dial-click-sound"] { defaults.removeObject(forKey: key) }
        defaults.set(true, forKey: "removed-music-recognition-cleanup")
    }
}
