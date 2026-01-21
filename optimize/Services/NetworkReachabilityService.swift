//
//  NetworkReachabilityService.swift
//  optimize
//
//  Network connectivity monitoring for offline-first behavior.
//  Ensures app works seamlessly without internet connection.
//
//  CRITICAL FOR APP STORE:
//  - App must work offline (all compression is local)
//  - Only StoreKit/IAP needs network
//  - User should never see "No Internet" for core features
//

import Foundation
import Network
import Combine

// MARK: - Network Status

enum NetworkStatus: Equatable {
    case connected(type: ConnectionType)
    case disconnected

    enum ConnectionType: String {
        case wifi = "WiFi"
        case cellular = "Cellular"
        case wired = "Wired"
        case unknown = "Unknown"
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var isWiFi: Bool {
        if case .connected(.wifi) = self { return true }
        return false
    }

    var isCellular: Bool {
        if case .connected(.cellular) = self { return true }
        return false
    }

    var displayName: String {
        switch self {
        case .connected(let type):
            return type.rawValue
        case .disconnected:
            return String(localized: "Çevrimdışı")
        }
    }
}

// MARK: - Network Reachability Service

@MainActor
final class NetworkReachabilityService: ObservableObject {

    // MARK: - Singleton

    static let shared = NetworkReachabilityService()

    // MARK: - Published State

    @Published private(set) var status: NetworkStatus = .disconnected
    @Published private(set) var isExpensive: Bool = false // Cellular data
    @Published private(set) var isConstrained: Bool = false // Low Data Mode

    // MARK: - Private

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.optimize.networkMonitor", qos: .utility)

    // MARK: - Initialization

    private init() {
        monitor = NWPathMonitor()
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.updateStatus(from: path)
            }
        }
        monitor.start(queue: queue)
    }

    private func stopMonitoring() {
        monitor.cancel()
    }

    private func updateStatus(from path: NWPath) {
        // Update connection status
        if path.status == .satisfied {
            let type: NetworkStatus.ConnectionType
            if path.usesInterfaceType(.wifi) {
                type = .wifi
            } else if path.usesInterfaceType(.cellular) {
                type = .cellular
            } else if path.usesInterfaceType(.wiredEthernet) {
                type = .wired
            } else {
                type = .unknown
            }
            status = .connected(type: type)
        } else {
            status = .disconnected
        }

        // Update constraints
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained

        #if DEBUG
        print("📶 [Network] Status: \(status.displayName), Expensive: \(isExpensive), Constrained: \(isConstrained)")
        #endif
    }

    // MARK: - Public API

    /// Check if network is available (for UI state)
    var isOnline: Bool {
        status.isConnected
    }

    /// Check if we should warn user about data usage
    var shouldWarnAboutDataUsage: Bool {
        isExpensive || isConstrained
    }

    /// Wait for network connection (with timeout)
    func waitForConnection(timeout: TimeInterval = 10) async -> Bool {
        if isOnline { return true }

        let startTime = Date()
        while !isOnline {
            if Date().timeIntervalSince(startTime) > timeout {
                return false
            }
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        }
        return true
    }

    /// Get user-friendly message for offline state
    func getOfflineMessage(for feature: String) -> String {
        String(localized: "\(feature) için internet bağlantısı gerekli. Lütfen bağlantınızı kontrol edin.")
    }
}

// MARK: - Offline-First Feature Check

extension NetworkReachabilityService {

    /// Features that work offline
    enum OfflineCapableFeature {
        case pdfCompression
        case imageCompression
        case videoCompression
        case fileConversion
        case history
        case settings

        var requiresNetwork: Bool {
            return false // All core features work offline!
        }
    }

    /// Features that require network
    enum OnlineRequiredFeature {
        case purchase
        case restore
        case analytics
        case remoteConfig

        var offlineMessage: String {
            switch self {
            case .purchase:
                return String(localized: "Satın alma için internet bağlantısı gerekli.")
            case .restore:
                return String(localized: "Satın alımları geri yüklemek için internet bağlantısı gerekli.")
            case .analytics:
                return String(localized: "Analitik verileri internet bağlantısında gönderilecek.")
            case .remoteConfig:
                return String(localized: "Güncellemeler internet bağlantısında kontrol edilecek.")
            }
        }
    }

    /// Check if feature can proceed
    func canProceed(with feature: OnlineRequiredFeature) -> (canProceed: Bool, message: String?) {
        if isOnline {
            return (true, nil)
        }
        return (false, feature.offlineMessage)
    }
}
