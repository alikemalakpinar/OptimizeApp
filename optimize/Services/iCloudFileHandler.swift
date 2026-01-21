//
//  iCloudFileHandler.swift
//  optimize
//
//  Handles iCloud placeholder files that haven't been downloaded yet.
//  Prevents confusing "file not found" errors when selecting iCloud files.
//
//  EDGE CASE:
//  User selects a file from iCloud Drive that shows in Files app but
//  is actually a placeholder (not downloaded). Without this handler,
//  the app would fail with a cryptic error.
//
//  FLOW:
//  1. Detect if file is iCloud placeholder
//  2. Show download progress UI
//  3. Wait for download to complete
//  4. Proceed with compression
//

import Foundation
import Combine

// MARK: - iCloud Download Status

enum iCloudDownloadStatus: Equatable {
    case notApplicable          // Not an iCloud file
    case downloaded             // Already on device
    case notDownloaded          // Placeholder, needs download
    case downloading(progress: Double)
    case failed(error: String)

    var needsDownload: Bool {
        if case .notDownloaded = self { return true }
        return false
    }

    var isDownloading: Bool {
        if case .downloading = self { return true }
        return false
    }

    var isReady: Bool {
        switch self {
        case .notApplicable, .downloaded:
            return true
        default:
            return false
        }
    }
}

// MARK: - iCloud File Handler

@MainActor
final class iCloudFileHandler: ObservableObject {

    // MARK: - Published State

    @Published private(set) var status: iCloudDownloadStatus = .notApplicable
    @Published private(set) var downloadProgress: Double = 0

    // MARK: - Private

    private var downloadQuery: NSMetadataQuery?
    private var progressObservation: NSKeyValueObservation?
    private var currentURL: URL?

    // MARK: - Lifecycle

    deinit {
        stopMonitoring()
    }

    // MARK: - Check Status

    /// Check if file is an iCloud placeholder
    func checkStatus(for url: URL) -> iCloudDownloadStatus {
        do {
            let resourceValues = try url.resourceValues(forKeys: [
                .ubiquitousItemDownloadingStatusKey,
                .ubiquitousItemIsDownloadingKey,
                .ubiquitousItemDownloadRequestedKey
            ])

            // Check if it's an iCloud file
            guard let downloadingStatus = resourceValues.ubiquitousItemDownloadingStatus else {
                return .notApplicable
            }

            switch downloadingStatus {
            case .current:
                return .downloaded
            case .downloaded:
                return .downloaded
            case .notDownloaded:
                if resourceValues.ubiquitousItemIsDownloading == true {
                    return .downloading(progress: downloadProgress)
                }
                return .notDownloaded
            @unknown default:
                return .notApplicable
            }
        } catch {
            // Not an iCloud file or error checking
            return .notApplicable
        }
    }

    /// Update status and store it
    func updateStatus(for url: URL) {
        currentURL = url
        status = checkStatus(for: url)
    }

    // MARK: - Download

    /// Start downloading iCloud file
    func startDownload(for url: URL) async throws {
        currentURL = url

        // Check current status
        let currentStatus = checkStatus(for: url)
        guard currentStatus.needsDownload else {
            status = currentStatus
            return
        }

        // Start download
        status = .downloading(progress: 0)

        do {
            try FileManager.default.startDownloadingUbiquitousItem(at: url)
            startMonitoring(url: url)
        } catch {
            status = .failed(error: error.localizedDescription)
            throw error
        }
    }

    /// Wait for download to complete
    func waitForDownload(timeout: TimeInterval = 300) async throws -> URL {
        guard let url = currentURL else {
            throw NSError(domain: "iCloudFileHandler", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "No file URL set"
            ])
        }

        let startTime = Date()

        while true {
            let currentStatus = checkStatus(for: url)

            switch currentStatus {
            case .downloaded, .notApplicable:
                status = .downloaded
                stopMonitoring()
                return url

            case .downloading(let progress):
                status = .downloading(progress: progress)

            case .notDownloaded:
                // Still waiting for download to start
                break

            case .failed(let error):
                stopMonitoring()
                throw NSError(domain: "iCloudFileHandler", code: -2, userInfo: [
                    NSLocalizedDescriptionKey: error
                ])
            }

            // Check timeout
            if Date().timeIntervalSince(startTime) > timeout {
                stopMonitoring()
                throw NSError(domain: "iCloudFileHandler", code: -3, userInfo: [
                    NSLocalizedDescriptionKey: String(localized: "iCloud indirme zaman aşımına uğradı")
                ])
            }

            // Wait before checking again
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        }
    }

    // MARK: - Monitoring

    private func startMonitoring(url: URL) {
        stopMonitoring()

        // Use NSMetadataQuery to monitor download progress
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(format: "%K == %@", NSMetadataItemURLKey, url as NSURL)
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope, NSMetadataQueryUbiquitousDataScope]

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidUpdate(_:)),
            name: .NSMetadataQueryDidUpdate,
            object: query
        )

        query.start()
        downloadQuery = query
    }

    private func stopMonitoring() {
        downloadQuery?.stop()
        downloadQuery = nil
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidUpdate, object: nil)
    }

    @objc private func queryDidUpdate(_ notification: Notification) {
        guard let query = notification.object as? NSMetadataQuery,
              let item = query.results.first as? NSMetadataItem,
              let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else {
            return
        }

        // Get download progress
        if let percentDownloaded = item.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? Double {
            let progress = percentDownloaded / 100.0
            downloadProgress = progress
            status = .downloading(progress: progress)

            if progress >= 1.0 {
                status = .downloaded
                stopMonitoring()
            }
        }
    }

    // MARK: - Convenience

    /// Check and download if needed, returning when ready
    func ensureDownloaded(url: URL, timeout: TimeInterval = 300) async throws -> URL {
        let currentStatus = checkStatus(for: url)

        switch currentStatus {
        case .notApplicable, .downloaded:
            return url

        case .notDownloaded, .downloading:
            try await startDownload(for: url)
            return try await waitForDownload(timeout: timeout)

        case .failed(let error):
            throw NSError(domain: "iCloudFileHandler", code: -4, userInfo: [
                NSLocalizedDescriptionKey: error
            ])
        }
    }
}

// MARK: - SwiftUI View for Download Progress

struct iCloudDownloadProgressView: View {
    @ObservedObject var handler: iCloudFileHandler

    var body: some View {
        if case .downloading(let progress) = handler.status {
            VStack(spacing: 12) {
                ProgressView(value: progress) {
                    HStack {
                        Image(systemName: "icloud.and.arrow.down")
                            .foregroundStyle(.blue)
                        Text("iCloud'dan indiriliyor...")
                            .font(.callout)
                    }
                }
                .progressViewStyle(.linear)

                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
