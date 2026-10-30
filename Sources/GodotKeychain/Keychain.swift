//
//  Keychain.swift
//  GodotApplePlugins
//

import Foundation
import Security
import SwiftGodotRuntime

@Godot
class Keychain: RefCounted, @unchecked Sendable {
    private var service: String {
        Bundle.main.bundleIdentifier ?? "GodotApplePluginsKeychain"
    }

    private func query(for key: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
    }

    @Callable
    func get_value(_ key: String) -> String {
        var query = query(for: key)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return ""
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    @Callable
    func set_value(_ key: String, _ value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let attributes: [CFString: Any] = [kSecValueData: data]
        let existingQuery = query(for: key)
        let updateStatus = SecItemUpdate(existingQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }

        var addQuery = query(for: key)
        addQuery[kSecValueData] = data
        addQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        return addStatus == errSecSuccess
    }

    @Callable
    func delete_value(_ key: String) -> Bool {
        let status = SecItemDelete(query(for: key) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
