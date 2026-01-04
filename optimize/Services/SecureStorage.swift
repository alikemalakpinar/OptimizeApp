//
//  SecureStorage.swift
//  optimize
//
//  SECURITY ENHANCEMENT:
//  Provides secure storage for sensitive data using iOS Keychain
//
//  Why Keychain over UserDefaults?
//  1. Encrypted at rest with device-level encryption
//  2. Survives app reinstalls (prevents limit reset exploits)
//  3. Protected by Secure Enclave on supported devices
//  4. Resistant to jailbreak-based tampering
//
//  Use cases:
//  - Daily usage count (prevents limit bypass)
//  - First install date (prevents trial reset)
//  - Any anti-fraud counters
//

import Foundation
import Security

// MARK: - Secure Storage Protocol

/// Protocol for secure data storage - enables testability and swappable implementations
protocol SecureStorageProtocol {
    func set(_ value: Int, forKey key: String)
    func set(_ value: String, forKey key: String)
    func set(_ value: Date, forKey key: String)
    func set(_ value: Data, forKey key: String)

    func getInt(forKey key: String) -> Int?
    func getString(forKey key: String) -> String?
    func getDate(forKey key: String) -> Date?
    func getData(forKey key: String) -> Data?

    func remove(forKey key: String)
    func contains(key: String) -> Bool
}

// MARK: - Keychain Storage Implementation

/// Secure storage implementation using iOS Keychain
/// This is the recommended storage for sensitive data that must persist across reinstalls
///
/// SECURITY ENHANCEMENT: iCloud Keychain Sync
/// Usage limits are now synced across user's devices via iCloud Keychain.
/// This prevents the exploit where users use multiple devices to get more free usage.
final class KeychainStorage: SecureStorageProtocol {

    // MARK: - Singleton

    static let shared = KeychainStorage()

    // MARK: - Configuration

    /// Service identifier for keychain items (bundle ID recommended)
    private let service: String

    /// Access group for keychain sharing (nil = app only)
    private let accessGroup: String?

    /// Whether to sync keychain items across devices via iCloud
    /// SECURITY: Set to true to prevent multi-device limit bypass
    private let synchronizable: Bool

    // MARK: - Initialization

    init(service: String? = nil, accessGroup: String? = nil, synchronizable: Bool = true) {
        self.service = service ?? Bundle.main.bundleIdentifier ?? "com.optimize.app"
        self.accessGroup = accessGroup
        self.synchronizable = synchronizable
    }

    // MARK: - Public API

    func set(_ value: Int, forKey key: String) {
        let data = withUnsafeBytes(of: value) { Data($0) }
        set(data, forKey: key)
    }

    func set(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }
        set(data, forKey: key)
    }

    func set(_ value: Date, forKey key: String) {
        let timestamp = value.timeIntervalSince1970
        let data = withUnsafeBytes(of: timestamp) { Data($0) }
        set(data, forKey: key)
    }

    func set(_ value: Data, forKey key: String) {
        // Delete existing item first
        remove(forKey: key)

        // Create query for new item
        var query = baseQuery(forKey: key)
        query[kSecValueData as String] = value

        // SECURITY: Use appropriate accessibility based on sync setting
        // When synchronizable, use kSecAttrAccessibleAfterFirstUnlock which is compatible with iCloud sync
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            print("[KeychainStorage] Failed to save \(key): \(status)")
        }
    }

    func getInt(forKey key: String) -> Int? {
        guard let data = getData(forKey: key), data.count == MemoryLayout<Int>.size else {
            return nil
        }
        return data.withUnsafeBytes { $0.load(as: Int.self) }
    }

    func getString(forKey key: String) -> String? {
        guard let data = getData(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func getDate(forKey key: String) -> Date? {
        guard let data = getData(forKey: key), data.count == MemoryLayout<TimeInterval>.size else {
            return nil
        }
        let timestamp = data.withUnsafeBytes { $0.load(as: TimeInterval.self) }
        return Date(timeIntervalSince1970: timestamp)
    }

    func getData(forKey key: String) -> Data? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return data
    }

    func remove(forKey key: String) {
        let query = baseQuery(forKey: key)
        SecItemDelete(query as CFDictionary)
    }

    func contains(key: String) -> Bool {
        return getData(forKey: key) != nil
    }

    // MARK: - Migration Support

    /// Migrate a value from UserDefaults to Keychain
    /// - Parameters:
    ///   - key: The key to migrate
    ///   - userDefaults: The UserDefaults instance
    /// - Returns: True if migration occurred
    @discardableResult
    func migrateFromUserDefaults(_ key: String, userDefaults: UserDefaults = .standard) -> Bool {
        // Skip if already in keychain
        guard !contains(key: key) else { return false }

        // Try to get from UserDefaults
        if let intValue = userDefaults.object(forKey: key) as? Int {
            set(intValue, forKey: key)
            userDefaults.removeObject(forKey: key)
            return true
        }

        if let stringValue = userDefaults.string(forKey: key) {
            set(stringValue, forKey: key)
            userDefaults.removeObject(forKey: key)
            return true
        }

        if let dateValue = userDefaults.object(forKey: key) as? Date {
            set(dateValue, forKey: key)
            userDefaults.removeObject(forKey: key)
            return true
        }

        return false
    }

    // MARK: - Helpers

    private func baseQuery(forKey key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        // SECURITY: Enable iCloud Keychain sync to prevent multi-device limit bypass
        // When enabled, usage counts are synced across all user's devices
        // This means using 1 free compression on iPhone counts on iPad too
        if synchronizable {
            query[kSecAttrSynchronizable as String] = kCFBooleanTrue
        }

        return query
    }
}

// MARK: - Mock Implementation for Testing

/// Mock implementation for unit tests
final class MockSecureStorage: SecureStorageProtocol {

    private var storage: [String: Data] = [:]

    func set(_ value: Int, forKey key: String) {
        let data = withUnsafeBytes(of: value) { Data($0) }
        storage[key] = data
    }

    func set(_ value: String, forKey key: String) {
        storage[key] = value.data(using: .utf8)
    }

    func set(_ value: Date, forKey key: String) {
        let timestamp = value.timeIntervalSince1970
        let data = withUnsafeBytes(of: timestamp) { Data($0) }
        storage[key] = data
    }

    func set(_ value: Data, forKey key: String) {
        storage[key] = value
    }

    func getInt(forKey key: String) -> Int? {
        guard let data = storage[key], data.count == MemoryLayout<Int>.size else {
            return nil
        }
        return data.withUnsafeBytes { $0.load(as: Int.self) }
    }

    func getString(forKey key: String) -> String? {
        guard let data = storage[key] else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func getDate(forKey key: String) -> Date? {
        guard let data = storage[key], data.count == MemoryLayout<TimeInterval>.size else {
            return nil
        }
        let timestamp = data.withUnsafeBytes { $0.load(as: TimeInterval.self) }
        return Date(timeIntervalSince1970: timestamp)
    }

    func getData(forKey key: String) -> Data? {
        return storage[key]
    }

    func remove(forKey key: String) {
        storage.removeValue(forKey: key)
    }

    func contains(key: String) -> Bool {
        return storage[key] != nil
    }

    /// Reset all storage (for testing)
    func reset() {
        storage.removeAll()
    }
}
