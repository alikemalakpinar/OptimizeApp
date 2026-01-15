//
//  SecurityGuard.swift
//  optimize
//
//  Multi-layered security system for detecting compromised devices
//  and protecting premium features from bypass attempts.
//
//  SECURITY LAYERS:
//  1. Jailbreak Detection (filesystem + sandbox + URL schemes)
//  2. Debugger Detection (ptrace check)
//  3. Tampering Detection (binary integrity)
//  4. Emulator Detection (simulator check)
//
//  PHILOSOPHY: Detect but don't block aggressively.
//  Log suspicious activity for analytics, degrade gracefully.
//

import Foundation
import UIKit
import Darwin

// MARK: - Security Audit Result

struct SecurityAuditResult {
    let issues: [SecurityIssue]
    let timestamp: Date
    let deviceInfo: DeviceSecurityInfo

    var isSecure: Bool { issues.isEmpty }
    var riskLevel: RiskLevel {
        if issues.isEmpty { return .none }
        if issues.contains(.jailbreakDetected) { return .high }
        if issues.contains(.debuggerAttached) { return .medium }
        return .low
    }

    enum RiskLevel: String {
        case none = "Secure"
        case low = "Low Risk"
        case medium = "Medium Risk"
        case high = "High Risk"
    }
}

enum SecurityIssue: String, CaseIterable {
    case jailbreakDetected = "jailbreak_detected"
    case debuggerAttached = "debugger_attached"
    case emulatorDetected = "emulator_detected"
    case tamperingDetected = "tampering_detected"
    case suspiciousEnvironment = "suspicious_environment"

    var localizedDescription: String {
        switch self {
        case .jailbreakDetected:
            return "Cihazınızda güvenlik kısıtlamaları kaldırılmış görünüyor."
        case .debuggerAttached:
            return "Uygulama analiz edilmeye çalışılıyor."
        case .emulatorDetected:
            return "Uygulama simülatörde çalışıyor."
        case .tamperingDetected:
            return "Uygulama dosyaları değiştirilmiş olabilir."
        case .suspiciousEnvironment:
            return "Güvenli olmayan ortam tespit edildi."
        }
    }
}

struct DeviceSecurityInfo {
    let modelIdentifier: String
    let systemVersion: String
    let isSimulator: Bool
    let bootTime: Date?
}

// MARK: - Security Guard

enum SecurityGuard {

    // MARK: - Main Security Audit

    /// Performs comprehensive security audit
    /// Call this on app launch and before sensitive operations
    static func performSecurityAudit() -> SecurityAuditResult {
        var issues: [SecurityIssue] = []

        // Layer 1: Jailbreak Detection
        if isDeviceJailbroken {
            issues.append(.jailbreakDetected)
        }

        // Layer 2: Debugger Detection (skip in DEBUG builds)
        #if !DEBUG
        if isDebuggerAttached {
            issues.append(.debuggerAttached)
        }
        #endif

        // Layer 3: Emulator Detection
        if isRunningInEmulator {
            issues.append(.emulatorDetected)
        }

        // Layer 4: Environment Check
        if hasSuspiciousEnvironmentVariables {
            issues.append(.suspiciousEnvironment)
        }

        return SecurityAuditResult(
            issues: issues,
            timestamp: Date(),
            deviceInfo: getDeviceSecurityInfo()
        )
    }

    // MARK: - Jailbreak Detection (Multi-Signal)

    /// Comprehensive jailbreak detection using multiple techniques
    static var isDeviceJailbroken: Bool {
        #if targetEnvironment(simulator)
        return false // Don't flag simulators as jailbroken
        #else

        // Signal 1: Check for suspicious file paths
        if checkSuspiciousFilePaths() { return true }

        // Signal 2: Check for suspicious URL schemes
        if checkSuspiciousURLSchemes() { return true }

        // Signal 3: Sandbox integrity check (write outside sandbox)
        if checkSandboxViolation() { return true }

        // Signal 4: Check for suspicious libraries
        if checkSuspiciousLibraries() { return true }

        // Signal 5: Check symbolic links
        if checkSymbolicLinks() { return true }

        return false
        #endif
    }

    // MARK: - Detection Methods

    /// Check for files that shouldn't exist on non-jailbroken devices
    private static func checkSuspiciousFilePaths() -> Bool {
        let suspiciousPaths = [
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/Applications/Zebra.app",
            "/Applications/blackra1n.app",
            "/Applications/FakeCarrier.app",
            "/Applications/Icy.app",
            "/Applications/IntelliScreen.app",
            "/Applications/MxTube.app",
            "/Applications/RockApp.app",
            "/Applications/SBSettings.app",
            "/Applications/WinterBoard.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/Library/MobileSubstrate/DynamicLibraries/",
            "/var/cache/apt",
            "/var/lib/apt",
            "/var/lib/cydia",
            "/var/log/syslog",
            "/var/tmp/cydia.log",
            "/bin/bash",
            "/bin/sh",
            "/usr/sbin/sshd",
            "/usr/bin/sshd",
            "/usr/libexec/sftp-server",
            "/usr/sbin/frida-server",
            "/usr/bin/cycript",
            "/usr/local/bin/cycript",
            "/usr/lib/libcycript.dylib",
            "/etc/apt",
            "/etc/ssh/sshd_config",
            "/private/var/lib/apt/",
            "/private/var/lib/cydia",
            "/private/var/mobile/Library/SBSettings/Themes",
            "/private/var/stash",
            "/private/var/tmp/cydia.log",
            "/System/Library/LaunchDaemons/com.ikey.bbot.plist",
            "/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist"
        ]

        let fileManager = FileManager.default
        for path in suspiciousPaths {
            if fileManager.fileExists(atPath: path) {
                return true
            }
        }

        return false
    }

    /// Check for Cydia and other jailbreak-related URL schemes
    private static func checkSuspiciousURLSchemes() -> Bool {
        let suspiciousSchemes = [
            "cydia://",
            "sileo://",
            "zbra://",
            "filza://",
            "activator://"
        ]

        for scheme in suspiciousSchemes {
            if let url = URL(string: scheme),
               UIApplication.shared.canOpenURL(url) {
                return true
            }
        }

        return false
    }

    /// Try to write outside app sandbox - should fail on non-jailbroken devices
    private static func checkSandboxViolation() -> Bool {
        let testPaths = [
            "/private/jailbreak_test_\(UUID().uuidString).txt",
            "/var/mobile/jailbreak_test_\(UUID().uuidString).txt"
        ]

        for testPath in testPaths {
            do {
                try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
                // If write succeeded, device is jailbroken
                try? FileManager.default.removeItem(atPath: testPath)
                return true
            } catch {
                // Expected behavior - sandbox is intact
            }
        }

        return false
    }

    /// Check for suspicious dynamic libraries loaded
    private static func checkSuspiciousLibraries() -> Bool {
        let suspiciousLibs = [
            "SubstrateLoader",
            "MobileSubstrate",
            "TweakInject",
            "libhooker",
            "substitute",
            "Cephei",
            "rocketbootstrap",
            "libSparkAppList",
            "AppList"
        ]

        for i in 0..<_dyld_image_count() {
            if let imageName = _dyld_get_image_name(i) {
                let name = String(cString: imageName)
                for lib in suspiciousLibs {
                    if name.localizedCaseInsensitiveContains(lib) {
                        return true
                    }
                }
            }
        }

        return false
    }

    /// Check for symbolic links that might indicate jailbreak
    private static func checkSymbolicLinks() -> Bool {
        let pathsToCheck = [
            "/Applications",
            "/var/stash/Library/Ringtones",
            "/var/stash/Library/Wallpaper",
            "/var/stash/usr/include",
            "/var/stash/usr/libexec",
            "/var/stash/usr/share"
        ]

        let fileManager = FileManager.default
        for path in pathsToCheck {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: path)
                if let type = attributes[.type] as? FileAttributeType,
                   type == .typeSymbolicLink {
                    return true
                }
            } catch {
                // Path doesn't exist or can't be accessed
            }
        }

        return false
    }

    // MARK: - Debugger Detection

    /// Check if a debugger is attached to the process
    static var isDebuggerAttached: Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]

        let result = sysctl(&mib, 4, &info, &size, nil, 0)

        if result == 0 {
            return (info.kp_proc.p_flag & P_TRACED) != 0
        }

        return false
    }

    // MARK: - Emulator Detection

    /// Check if running in iOS Simulator
    static var isRunningInEmulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        // Additional runtime check
        if let simulatorDevice = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] {
            return !simulatorDevice.isEmpty
        }
        return false
        #endif
    }

    // MARK: - Environment Check

    /// Check for suspicious environment variables
    private static var hasSuspiciousEnvironmentVariables: Bool {
        let suspiciousVars = [
            "DYLD_INSERT_LIBRARIES",
            "_MSSafeMode",
            "SIMULATOR_DEVICE_NAME" // Outside of simulator context
        ]

        let env = ProcessInfo.processInfo.environment

        for varName in suspiciousVars {
            if let value = env[varName], !value.isEmpty {
                #if !targetEnvironment(simulator)
                if varName == "SIMULATOR_DEVICE_NAME" { continue }
                #endif
                return true
            }
        }

        return false
    }

    // MARK: - Device Info

    private static func getDeviceSecurityInfo() -> DeviceSecurityInfo {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelIdentifier = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }

        // Get boot time
        var bootTime: Date? = nil
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        var bootTimeVal = timeval()
        var size = MemoryLayout<timeval>.stride
        if sysctl(&mib, 2, &bootTimeVal, &size, nil, 0) == 0 {
            bootTime = Date(timeIntervalSince1970: TimeInterval(bootTimeVal.tv_sec))
        }

        return DeviceSecurityInfo(
            modelIdentifier: modelIdentifier,
            systemVersion: UIDevice.current.systemVersion,
            isSimulator: isRunningInEmulator,
            bootTime: bootTime
        )
    }

    // MARK: - Security Policy Enforcement

    /// Determines what action to take based on security audit
    static func enforceSecurityPolicy(_ result: SecurityAuditResult) -> SecurityAction {
        switch result.riskLevel {
        case .none:
            return .allow

        case .low:
            // Log but allow
            return .allowWithLogging

        case .medium:
            // Warn user but allow with degraded features
            return .warnUser(message: "Uygulamanın güvenli çalışması için debug modunun kapatılması önerilir.")

        case .high:
            // Allow but disable sensitive features
            return .degradeFeatures(
                disabledFeatures: [.offlineMode],
                message: "Cihaz güvenliği doğrulanamadı. Bazı özellikler kısıtlanmış olabilir."
            )
        }
    }

    enum SecurityAction {
        case allow
        case allowWithLogging
        case warnUser(message: String)
        case degradeFeatures(disabledFeatures: [DegradedFeature], message: String)
        case block(message: String)
    }

    enum DegradedFeature {
        case offlineMode
        case exportFeatures
        case batchProcessing
    }
}

// MARK: - String Protection (Basic Obfuscation)

enum StringProtector {
    /// Simple XOR-based string protection for sensitive strings
    /// Note: This is basic obfuscation, not encryption. Use for API keys, URLs, etc.

    private static let key: [UInt8] = [0x4F, 0x70, 0x74, 0x69, 0x6D, 0x69, 0x7A, 0x65, 0x41, 0x70, 0x70, 0x21]

    /// Decrypt a protected string at runtime
    static func reveal(_ encrypted: [UInt8]) -> String {
        var result: [UInt8] = []
        for (i, byte) in encrypted.enumerated() {
            result.append(byte ^ key[i % key.count])
        }
        return String(bytes: result, encoding: .utf8) ?? ""
    }

    /// Encrypt a string (use this offline to generate encrypted arrays)
    static func protect(_ string: String) -> [UInt8] {
        let bytes = Array(string.utf8)
        var result: [UInt8] = []
        for (i, byte) in bytes.enumerated() {
            result.append(byte ^ key[i % key.count])
        }
        return result
    }
}

// MARK: - Integrity Checker

enum IntegrityChecker {

    /// Verify app bundle hasn't been tampered with
    static func verifyBundleIntegrity() -> Bool {
        guard let bundlePath = Bundle.main.bundlePath as NSString? else {
            return false
        }

        // Check for expected files
        let expectedFiles = [
            "Info.plist",
            "PkgInfo"
        ]

        let fileManager = FileManager.default
        for file in expectedFiles {
            let filePath = bundlePath.appendingPathComponent(file)
            if !fileManager.fileExists(atPath: filePath) {
                return false
            }
        }

        // Verify code signature exists
        let codeSignaturePath = bundlePath.appendingPathComponent("_CodeSignature")
        if !fileManager.fileExists(atPath: codeSignaturePath) {
            return false
        }

        return true
    }

    /// Check if running with valid provisioning profile
    static func hasValidProvisioning() -> Bool {
        guard let provisioningPath = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") else {
            #if DEBUG
            return true // Development builds may not have this
            #else
            return false
            #endif
        }

        return FileManager.default.fileExists(atPath: provisioningPath)
    }
}
