//
//  AppCoordinator.swift
//  optimize
//
//  Main navigation coordinator with real file operations
//

import SwiftUI
import UniformTypeIdentifiers
import Combine
import StoreKit

// MARK: - App State
enum AppScreen: Equatable {
    case splash
    case onboarding
    case home
    case analyze(FileInfo)
    case preset(FileInfo, AnalysisResult)
    case progress(FileInfo, CompressionPreset)
    case result(CompressionResult)
    case history
    case settings

    static func == (lhs: AppScreen, rhs: AppScreen) -> Bool {
        switch (lhs, rhs) {
        case (.splash, .splash),
             (.onboarding, .onboarding),
             (.home, .home),
             (.history, .history),
             (.settings, .settings):
            return true
        case (.analyze(let lFile), .analyze(let rFile)):
            return lFile.id == rFile.id
        case (.preset(let lFile, _), .preset(let rFile, _)):
            return lFile.id == rFile.id
        case (.progress(let lFile, _), .progress(let rFile, _)):
            return lFile.id == rFile.id
        case (.result(let lResult), .result(let rResult)):
            return lResult.id == rResult.id
        default:
            return false
        }
    }
}

// MARK: - App Coordinator
@MainActor
class AppCoordinator: ObservableObject {
    @Published var currentScreen: AppScreen = .splash
    @Published var showPaywall = false
    @Published var showDocumentPicker = false
    @Published var showShareSheet = false
    @Published var showFileSaver = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var paywallContext: PaywallContext?

    // Current processing data
    @Published var currentFile: FileInfo?
    @Published var currentAnalysis: AnalysisResult?
    @Published var currentResult: CompressionResult?
    @Published var selectedPreset: CompressionPreset?

    // Retry state
    @Published var showRetryAlert = false
    @Published var lastError: Error?
    private var retryCount = 0
    private let maxRetries = 2

    // Services
    let compressionService = UltimatePDFCompressionService.shared
    let historyManager = HistoryManager.shared
    let analytics = AnalyticsService.shared
    let subscriptionManager = SubscriptionManager.shared
    @Published var subscriptionStatus: SubscriptionStatus

    // User defaults keys
    private let hasSeenOnboardingKey = "hasSeenOnboarding"
    private let successCountKey = "successfulCompressionCount"

    private var cancellables = Set<AnyCancellable>()

    init() {
        subscriptionStatus = subscriptionManager.status

        subscriptionManager.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.subscriptionStatus = status
            }
            .store(in: &cancellables)
    }

    var hasSeenOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: hasSeenOnboardingKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasSeenOnboardingKey) }
    }

    // MARK: - Navigation Actions
    func splashComplete() {
        withAnimation(AppAnimation.standard) {
            if hasSeenOnboarding {
                currentScreen = .home
            } else {
                currentScreen = .onboarding
            }
        }
    }

    func onboardingComplete() {
        hasSeenOnboarding = true
        analytics.track(.onboardingCompleted)
        withAnimation(AppAnimation.standard) {
            currentScreen = .home
        }
    }

    func requestFilePicker() {
        showDocumentPicker = true
    }

    func handlePickedFile(_ url: URL) {
        showDocumentPicker = false

        Task {
            do {
                let fileInfo = try FileInfo.from(url: url)
                currentFile = fileInfo

                if let paywall = subscriptionManager.paywallContext(for: fileInfo) {
                    presentPaywall(context: paywall)
                    analytics.track(.paywallViewed)
                    return
                }

                // Track file selection
                analytics.trackFileSelected(fileName: fileInfo.name, fileSize: fileInfo.size)

                withAnimation(AppAnimation.standard) {
                    currentScreen = .analyze(fileInfo)
                }

                // Start analysis
                analytics.track(.fileAnalysisStarted)
                await performAnalysis(for: fileInfo)
                analytics.track(.fileAnalysisCompleted)
            } catch {
                analytics.trackError(error, context: "file_selection")
                showError(message: "Unable to read file: \(error.localizedDescription)")
            }
        }
    }

    func performAnalysis(for file: FileInfo) async {
        do {
            let result = try await compressionService.analyze(file: file)
            currentAnalysis = result
        } catch {
            // Use default analysis on error
            currentAnalysis = AnalysisResult(
                pageCount: file.pageCount ?? 1,
                imageCount: 0,
                imageDensity: .medium,
                estimatedSavings: .medium,
                isAlreadyOptimized: false,
                originalDPI: nil
            )
        }
    }

    func analyzeComplete() {
        guard let file = currentFile, let result = currentAnalysis else { return }
        withAnimation(AppAnimation.standard) {
            currentScreen = .preset(file, result)
        }
    }

    func startCompression(preset: CompressionPreset) {
        guard let file = currentFile else { return }
        selectedPreset = preset

        if let paywall = subscriptionManager.paywallContext(for: file, preset: preset) {
            presentPaywall(context: paywall)
            return
        }

        // Track preset selection and compression start
        analytics.trackPresetSelected(presetId: preset.id, isCustom: preset.quality == .custom)
        analytics.track(.compressionStarted, parameters: [
            "preset_id": preset.id,
            "file_size_mb": file.sizeMB
        ])

        // Reset observable progress state so the progress screen is accurate immediately
        compressionService.prepareForNewTask()

        withAnimation(AppAnimation.standard) {
            currentScreen = .progress(file, preset)
        }

        // Start actual compression
        Task {
            await performCompression(file: file, preset: preset)
        }
    }

    func performCompression(file: FileInfo, preset: CompressionPreset) async {
        // Check for extremely large files (500+ pages)
        if let pageCount = file.pageCount, pageCount > 500 {
            let error = CompressionError.fileTooLarge
            lastError = error
            analytics.trackCompressionFailed(error: error, presetId: preset.id)
            showError(message: error.errorDescription ?? "File too large")
            goHome()
            return
        }

        do {
            let outputURL = try await compressionService.compressFile(
                at: file.url,
                preset: preset
            ) { stage, progress in
                // Progress updates handled by service
            }

            // Get compressed file size
            let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
            let compressedSize = attributes[.size] as? Int64 ?? 0

            let result = CompressionResult(
                originalFile: file,
                compressedURL: outputURL,
                compressedSize: compressedSize
            )

            currentResult = result
            retryCount = 0 // Reset retry count on success

            // Track compression success
            analytics.trackCompressionCompleted(
                originalSize: file.size,
                compressedSize: result.compressedSize,
                savingsPercent: result.savingsPercent,
                presetId: preset.id,
                duration: 0 // Could track actual duration if needed
            )

            // Add to history
            historyManager.addFromResult(result, presetId: preset.id)
            subscriptionManager.recordSuccessfulCompression()

            // Smart Review Prompt: Ask for review at optimal moments
            requestReviewIfAppropriate(savingsPercent: result.savingsPercent)

            withAnimation(AppAnimation.standard) {
                currentScreen = .result(result)
            }
        } catch let compressionError as CompressionError {
            lastError = compressionError
            analytics.trackCompressionFailed(error: compressionError, presetId: preset.id)

            // Build error message with recovery suggestion
            var message = compressionError.errorDescription ?? "Compression failed"
            if let suggestion = compressionError.recoverySuggestion {
                message += "\n\n\(suggestion)"
            }

            if retryCount < maxRetries && shouldAllowRetry(for: compressionError) {
                showRetryAlert = true
            } else {
                retryCount = 0
                showError(message: message)
                goHome()
            }
        } catch {
            lastError = error
            analytics.trackCompressionFailed(error: error, presetId: preset.id)

            if retryCount < maxRetries {
                showRetryAlert = true
            } else {
                retryCount = 0
                showError(message: "Compression failed: \(error.localizedDescription)")
                goHome()
            }
        }
    }

    /// Determines if retry should be allowed for specific error types
    private func shouldAllowRetry(for error: CompressionError) -> Bool {
        switch error {
        case .accessDenied, .invalidPDF, .invalidFile, .emptyPDF, .encryptedPDF, .fileTooLarge, .unsupportedType:
            // These errors won't be fixed by retry
            return false
        case .contextCreationFailed, .saveFailed, .memoryPressure, .timeout, .pageProcessingFailed, .unknown, .cancelled, .exportFailed:
            // These might be fixed by retry
            return true
        }
    }

    func retryCompression() {
        guard let file = currentFile, let preset = selectedPreset else { return }
        retryCount += 1
        showRetryAlert = false

        analytics.track(.compressionRetried, parameters: ["retry_count": retryCount])

        compressionService.prepareForNewTask()

        withAnimation(AppAnimation.standard) {
            currentScreen = .progress(file, preset)
        }

        Task {
            await performCompression(file: file, preset: preset)
        }
    }

    func cancelRetry() {
        showRetryAlert = false
        retryCount = 0
        goHome()
    }

    func shareResult() {
        guard currentResult != nil else { return }
        analytics.track(.fileShared)
        showShareSheet = true
    }

    func saveResult() {
        guard currentResult != nil else { return }
        analytics.track(.fileSaved)
        showFileSaver = true
    }

    func openHistory() {
        withAnimation(AppAnimation.standard) {
            currentScreen = .history
        }
    }

    func openSettings() {
        analytics.track(.settingsOpened)
        withAnimation(AppAnimation.standard) {
            currentScreen = .settings
        }
    }

    func goBack() {
        withAnimation(AppAnimation.standard) {
            // Navigate back based on current screen
            switch currentScreen {
            case .analyze:
                currentScreen = .home
            case .preset:
                if let file = currentFile {
                    currentScreen = .analyze(file)
                } else {
                    currentScreen = .home
                }
            case .history, .settings:
                currentScreen = .home
            default:
                currentScreen = .home
            }
        }
    }

    func goHome() {
        currentFile = nil
        currentAnalysis = nil
        currentResult = nil
        selectedPreset = nil

        withAnimation(AppAnimation.standard) {
            currentScreen = .home
        }
    }

    func presentPaywall(context: PaywallContext? = nil) {
        analytics.track(.paywallViewed)
        paywallContext = context ?? PaywallContext.proRequired
        showPaywall = true
    }

    func dismissPaywall() {
        showPaywall = false
        paywallContext = nil
    }

    // MARK: - Smart Review Prompt
    /// Requests App Store review at optimal moments (3rd, 10th, 50th successful compression)
    /// Only triggers when savings are meaningful (>20%)
    private func requestReviewIfAppropriate(savingsPercent: Int) {
        // Only ask for review if user had a good experience (>20% savings)
        guard savingsPercent > 20 else { return }

        // Increment and get success count
        let successCount = UserDefaults.standard.integer(forKey: successCountKey) + 1
        UserDefaults.standard.set(successCount, forKey: successCountKey)

        // Request review at milestone counts: 3rd, 10th, 50th successful compression
        let reviewMilestones = [3, 10, 50]
        guard reviewMilestones.contains(successCount) else { return }

        // Delay to let the result screen render first
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                SKStoreReviewController.requestReview(in: windowScene)
            }
        }
    }

    // MARK: - Error Handling
    func showError(message: String) {
        errorMessage = message
        showError = true
    }

    func dismissError() {
        showError = false
        errorMessage = ""
    }
}

// MARK: - Root View
struct RootView: View {
    @StateObject private var coordinator = AppCoordinator()

    var body: some View {
        ZStack {
            screenContent
        }
        .sheet(isPresented: $coordinator.showDocumentPicker) {
            DocumentPicker(
                allowedTypes: [.pdf, .image, .movie, .text, .data],
                onPick: { url in
                    coordinator.handlePickedFile(url)
                },
                onCancel: {
                    coordinator.showDocumentPicker = false
                }
            )
        }
        .sheet(isPresented: $coordinator.showShareSheet) {
            if let result = coordinator.currentResult {
                ShareSheet(items: [result.compressedURL]) {
                    coordinator.showShareSheet = false
                }
            }
        }
        .sheet(isPresented: $coordinator.showFileSaver) {
            if let result = coordinator.currentResult {
                FileExporter(url: result.compressedURL) { success in
                    coordinator.showFileSaver = false
                    if success {
                        Haptics.success()
                    }
                }
            }
        }
        .sheet(isPresented: $coordinator.showPaywall) {
            PaywallScreen(
                context: coordinator.paywallContext,
                onSubscribe: { plan in
                    // Use StoreKit 2 purchase
                    Task {
                        do {
                            try await coordinator.subscriptionManager.purchase(plan: plan)
                            await MainActor.run {
                                coordinator.dismissPaywall()
                                Haptics.success()
                            }
                        } catch SubscriptionError.userCancelled {
                            // User cancelled - do nothing
                        } catch {
                            await MainActor.run {
                                coordinator.showError(message: error.localizedDescription)
                            }
                        }
                    }
                },
                onRestore: {
                    Task {
                        await coordinator.subscriptionManager.restore()
                        await MainActor.run {
                            if coordinator.subscriptionManager.status.isPro {
                                coordinator.dismissPaywall()
                                Haptics.success()
                            }
                        }
                    }
                },
                onDismiss: {
                    coordinator.dismissPaywall()
                },
                onPrivacy: {
                    // Open privacy policy - Replace with your actual URL
                    if let url = URL(string: "https://optimize-app.com/privacy") {
                        UIApplication.shared.open(url)
                    }
                },
                onTerms: {
                    // Open terms of service - Replace with your actual URL
                    if let url = URL(string: "https://optimize-app.com/terms") {
                        UIApplication.shared.open(url)
                    }
                }
            )
        }
        .alert("Error", isPresented: $coordinator.showError) {
            Button("OK", role: .cancel) {
                coordinator.dismissError()
            }
        } message: {
            Text(coordinator.errorMessage)
        }
        .alert("Compression Failed", isPresented: $coordinator.showRetryAlert) {
            Button("Retry") {
                coordinator.retryCompression()
            }
            Button("Cancel", role: .cancel) {
                coordinator.cancelRetry()
            }
        } message: {
            Text("Compression failed. Would you like to try again?")
        }
    }

    @ViewBuilder
    private var screenContent: some View {
        switch coordinator.currentScreen {
        case .splash:
            SplashScreen {
                coordinator.splashComplete()
            }
            .transition(.opacity)

        case .onboarding:
            OnboardingScreen {
                coordinator.onboardingComplete()
            }
            .transition(.opacity)

        case .home:
            HomeScreen(
                coordinator: coordinator,
                subscriptionStatus: coordinator.subscriptionStatus,
                onSelectFile: {
                    coordinator.requestFilePicker()
                },
                onOpenHistory: {
                    coordinator.openHistory()
                },
                onOpenSettings: {
                    coordinator.openSettings()
                },
                onUpgrade: {
                    coordinator.presentPaywall()
                }
            )
            .transition(.opacity)

        case .analyze(let file):
            AnalyzeScreen(
                file: file,
                analysisResult: coordinator.currentAnalysis,
                subscriptionStatus: coordinator.subscriptionStatus,
                paywallContext: coordinator.paywallContext,
                onContinue: {
                    coordinator.analyzeComplete()
                },
                onBack: {
                    coordinator.goBack()
                },
                onReplace: {
                    coordinator.requestFilePicker()
                },
                onUpgrade: {
                    coordinator.presentPaywall(context: coordinator.paywallContext)
                }
            )
            .transition(.move(edge: .trailing))

        case .preset(let file, let analysis):
            PresetScreen(
                file: file,
                analysisResult: analysis,
                isProUser: coordinator.subscriptionStatus.isPro,
                onCompress: { preset in
                    coordinator.startCompression(preset: preset)
                },
                onBack: {
                    coordinator.goBack()
                },
                onShowPaywall: {
                    coordinator.presentPaywall()
                }
            )
            .transition(.move(edge: .trailing))

        case .progress(let file, let preset):
            ProgressScreen(
                file: file,
                preset: preset,
                compressionService: coordinator.compressionService,
                onCancel: {
                    coordinator.goHome()
                }
            )
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                removal: .opacity
            ))

        case .result(let result):
            ResultScreen(
                result: result,
                onShare: {
                    coordinator.shareResult()
                },
                onSave: {
                    coordinator.saveResult()
                },
                onNewFile: {
                    coordinator.goHome()
                }
            )
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                removal: .opacity
            ))

        case .history:
            HistoryScreen(
                historyManager: coordinator.historyManager,
                onBack: {
                    coordinator.goBack()
                }
            )
            .transition(.move(edge: .trailing))

        case .settings:
            SettingsScreen(
                subscriptionStatus: coordinator.subscriptionStatus,
                onUpgrade: {
                    coordinator.presentPaywall()
                },
                onBack: {
                    coordinator.goBack()
                }
            )
            .transition(.move(edge: .trailing))
        }
    }
}

#Preview {
    RootView()
}
