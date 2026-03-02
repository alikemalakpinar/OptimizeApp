//
//  PaywallExperimentService.swift
//  optimize
//
//  Lightweight A/B testing infrastructure for paywall variants.
//  Assigns users to experiment groups deterministically and tracks conversion.
//
//  ARCHITECTURE:
//  - Each experiment has a unique ID and multiple variants
//  - User assignment is deterministic (based on UUID hash) — stable across sessions
//  - Conversion events are logged locally (can be forwarded to analytics)
//  - No external dependency — works entirely offline
//
//  USAGE:
//  let variant = PaywallExperimentService.shared.activeVariant
//  // Render paywall based on variant
//  PaywallExperimentService.shared.logConversion(variant: variant)
//

import Foundation

// MARK: - Paywall Variant

/// Different paywall presentations to test
enum PaywallVariant: String, Codable, CaseIterable {
    /// Current design — control group
    case control = "control"
    /// Minimal: fewer elements, focused CTA
    case minimal = "minimal"
    /// Aggressive: countdown timer prominent, urgency copy
    case aggressive = "aggressive"

    var displayName: String {
        switch self {
        case .control: return "Kontrol (Mevcut)"
        case .minimal: return "Minimal"
        case .aggressive: return "Agresif"
        }
    }
}

// MARK: - Experiment Event

struct ExperimentEvent: Codable {
    let experimentId: String
    let variant: PaywallVariant
    let event: EventType
    let timestamp: Date
    let metadata: [String: String]?

    enum EventType: String, Codable {
        case impression       // Paywall shown
        case ctaTap           // CTA button tapped
        case trialStarted     // Free trial started
        case purchased        // Purchase completed
        case dismissed        // Paywall dismissed without action
    }
}

// MARK: - Experiment Result

struct ExperimentResult: Codable {
    let variant: PaywallVariant
    var impressions: Int = 0
    var ctaTaps: Int = 0
    var conversions: Int = 0
    var dismissals: Int = 0

    var conversionRate: Double {
        guard impressions > 0 else { return 0 }
        return Double(conversions) / Double(impressions) * 100
    }

    var ctaRate: Double {
        guard impressions > 0 else { return 0 }
        return Double(ctaTaps) / Double(impressions) * 100
    }
}

// MARK: - Paywall Experiment Service

final class PaywallExperimentService: ObservableObject {
    static let shared = PaywallExperimentService()

    /// Current experiment identifier
    private let currentExperimentId = "paywall_v2_2026Q1"

    /// Active variant for this user
    @Published private(set) var activeVariant: PaywallVariant

    /// Whether A/B testing is enabled
    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: storageKeys.enabled) }
    }

    /// Override variant for testing (DEBUG only)
    var debugOverrideVariant: PaywallVariant? {
        didSet { UserDefaults.standard.set(debugOverrideVariant?.rawValue, forKey: storageKeys.debugOverride) }
    }

    private let events = EventStore()
    private let storageKeys = StorageKeys()

    private struct StorageKeys {
        let enabled = "experiment.ab.enabled"
        let assignedVariant = "experiment.ab.variant"
        let userId = "experiment.ab.userId"
        let debugOverride = "experiment.ab.debugOverride"
        let eventsFile = "experiment_events.json"
    }

    private init() {
        self.isEnabled = UserDefaults.standard.object(forKey: storageKeys.enabled) as? Bool ?? true

        // Load debug override
        if let raw = UserDefaults.standard.string(forKey: storageKeys.debugOverride),
           let variant = PaywallVariant(rawValue: raw) {
            self.debugOverrideVariant = variant
            self.activeVariant = variant
        } else {
            self.activeVariant = .control
            self.activeVariant = assignVariant()
        }
    }

    // MARK: - Variant Assignment

    /// Deterministic assignment based on stable user ID
    private func assignVariant() -> PaywallVariant {
        // Check for stored assignment first (sticky)
        if let stored = UserDefaults.standard.string(forKey: storageKeys.assignedVariant),
           let variant = PaywallVariant(rawValue: stored) {
            return variant
        }

        // Generate or retrieve stable user ID
        let userId = getOrCreateUserId()

        // Deterministic hash-based assignment
        let hash = abs(userId.hashValue)
        let variants = PaywallVariant.allCases
        let index = hash % variants.count
        let assigned = variants[index]

        // Store for persistence
        UserDefaults.standard.set(assigned.rawValue, forKey: storageKeys.assignedVariant)
        return assigned
    }

    private func getOrCreateUserId() -> String {
        if let existing = UserDefaults.standard.string(forKey: storageKeys.userId) {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: storageKeys.userId)
        return newId
    }

    // MARK: - Event Logging

    /// Log a paywall impression
    func logImpression() {
        guard isEnabled else { return }
        let variant = debugOverrideVariant ?? activeVariant
        log(event: .impression, variant: variant)
    }

    /// Log CTA tap
    func logCTATap() {
        guard isEnabled else { return }
        let variant = debugOverrideVariant ?? activeVariant
        log(event: .ctaTap, variant: variant)
    }

    /// Log successful conversion (purchase or trial)
    func logConversion(isTrial: Bool = false) {
        guard isEnabled else { return }
        let variant = debugOverrideVariant ?? activeVariant
        log(event: isTrial ? .trialStarted : .purchased, variant: variant)
    }

    /// Log dismissal without conversion
    func logDismissal() {
        guard isEnabled else { return }
        let variant = debugOverrideVariant ?? activeVariant
        log(event: .dismissed, variant: variant)
    }

    private func log(event: ExperimentEvent.EventType, variant: PaywallVariant, metadata: [String: String]? = nil) {
        let entry = ExperimentEvent(
            experimentId: currentExperimentId,
            variant: variant,
            event: event,
            timestamp: Date(),
            metadata: metadata
        )
        events.append(entry)
    }

    // MARK: - Results

    /// Get aggregated results for the current experiment
    func getResults() -> [ExperimentResult] {
        let allEvents = events.loadAll().filter { $0.experimentId == currentExperimentId }

        var results: [PaywallVariant: ExperimentResult] = [:]
        for variant in PaywallVariant.allCases {
            results[variant] = ExperimentResult(variant: variant)
        }

        for event in allEvents {
            switch event.event {
            case .impression:
                results[event.variant]?.impressions += 1
            case .ctaTap:
                results[event.variant]?.ctaTaps += 1
            case .trialStarted, .purchased:
                results[event.variant]?.conversions += 1
            case .dismissed:
                results[event.variant]?.dismissals += 1
            }
        }

        return Array(results.values).sorted { $0.conversionRate > $1.conversionRate }
    }

    /// Reset experiment data (for testing)
    func resetExperiment() {
        UserDefaults.standard.removeObject(forKey: storageKeys.assignedVariant)
        events.clear()
        activeVariant = assignVariant()
    }
}

// MARK: - Event Store (JSON file persistence)

private final class EventStore {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "experiment.events", qos: .utility)

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = docs.appendingPathComponent("experiment_events.json")
    }

    func append(_ event: ExperimentEvent) {
        queue.async { [self] in
            var events = loadAllSync()
            events.append(event)
            // Keep max 1000 events
            if events.count > 1000 {
                events = Array(events.suffix(500))
            }
            save(events)
        }
    }

    func loadAll() -> [ExperimentEvent] {
        queue.sync { loadAllSync() }
    }

    private func loadAllSync() -> [ExperimentEvent] {
        guard let data = try? Data(contentsOf: fileURL),
              let events = try? JSONDecoder().decode([ExperimentEvent].self, from: data) else {
            return []
        }
        return events
    }

    private func save(_ events: [ExperimentEvent]) {
        if let data = try? JSONEncoder().encode(events) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func clear() {
        queue.async { [self] in
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}
