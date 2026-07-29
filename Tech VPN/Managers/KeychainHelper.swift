//
//  KeychainHelper.swift
//  Tech VPN
//
//  Created by Xylo on 20/03/26.
//

import Foundation
import Security

class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}
    
    private let serviceName = "com.techvpn.app"
    
    // MARK: - Save Data
    @discardableResult
    func save(data: Data, forKey key: String) -> Bool {
        delete(forKey: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Save Data for VPN (accessible by system VPN daemon)
    @discardableResult
    func saveForVPN(data: Data, forKey key: String) -> Bool {
        delete(forKey: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAlways
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Save String for VPN
    @discardableResult
    func saveForVPN(string: String, forKey key: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return saveForVPN(data: data, forKey: key)
    }
    
    // MARK: - Save String
    @discardableResult
    func save(string: String, forKey key: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return save(data: data, forKey: key)
    }
    
    // MARK: - Read Data
    func read(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
    
    // MARK: - Read String
    func readString(forKey key: String) -> String? {
        guard let data = read(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    // MARK: - Delete
    @discardableResult
    func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Get Persistent Reference (for NEVPNProtocol)
    func persistentReference(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnPersistentRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
}

// MARK: - Keychain Keys
extension KeychainHelper {
    static let tokenKey = "auth_token"
    static let vpnPasswordKey = "vpn_password"
    static let usernameKey = "vpn_username"
    static let vpnServerUsernameKey = "vpn_server_username"
    static let vpnServerPasswordKey = "vpn_server_password"
}
