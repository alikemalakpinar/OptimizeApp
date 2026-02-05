//
//  AppCoordinator.swift
//  optimize
//
//  Main navigation coordinator with real file operations
//
//  REFACTORED (MVVM-C Architecture):
//  - Business logic extracted to dedicated ViewModels
//  - Coordinator now focuses on navigation and view coordination
//  - ViewModels handle: analysis, compression, result operations
//  - This reduces the "God Object" anti-pattern
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Combine

// MARK: - App State

/// Screens that can be pushed onto the navigation stack
/// ARCHITECTURE: Hashable conformance enables NavigationStack path management
enum AppScreen: Hashable {
    case splash
    case onboarding
    case commitment
    case ratingRequest
    case home
    case analyze(FileInfo)
    case preset(FileInfo, AnalysisResult)
    case progress(FileInfo, CompressionPreset)
    case result(CompressionResult)
    case history
    case settings
    case batchProcessing
    case converter
    case storageAnalysis

    // MARK: - Hashable Conformance (Required for NavigationPath)

    func hash(into hasher: inout Hasher) {
        switch self {
        case .splash: hasher.combine("splash")
        case .onboarding: hasher.combine("onboarding")
        case .commitment: hasher.combine("commitment")
        case .ratingRequest: hasher.combine("ratingRequest")
        case .home: hasher.combine("home")
        case .analyze(let file): hasher.combine("analyze"); hasher.combine(file.id)
        case .preset(let file, _): hasher.combine("preset"); hasher.combine(file.id)
        case .progress(let file, _): hasher.combine("progress"); hasher.combine(file.id)
        case .result(let result): hasher.combine("result"); hasher.combine(result.id)
        case .history: hasher.combine("history")
        case .settings: hasher.combine("settings")
        case .batchProcessing: hasher.combine("batchProcessing")
        case .converter: hasher.combine("converter")
        case .storageAnalysis: hasher.combine("storageAnalysis")
        }
    }

    static func == (lhs: AppScreen, rhs: AppScreen) -> Bool {
        switch (lhs, rhs) {
        case (.splash, .splash),
             (.onboarding, .onboarding),
             (.commitment, .commitment),
             (.ratingRequest, .ratingRequest),
             (.home, .home),
             (.history, .history),
             (.settings, .settings),
             (.batchProcessing, .batchProcessing),
             (.converter, .converter),
             (.storageAnalysis, .storageAnalysis):
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

    /// Whether this screen should use native navigation (NavigationStack)
    /// Some screens like splash, onboarding are full-screen and don't use navigation
    var usesNavigationStack: Bool {
        switch self {
        case .splash, .onboarding, .commitment, .ratingRequest:
            return false
        default:
            return true
        }
    }
}

// MARK: - Sheet State (Modular State Management)

/// Groups all sheet-related state to reduce @Published pollution in coordinator
/// ARCHITECTURE: This separation helps prevent unnecessary view re-renders
/// by isolating sheet state from navigation state
struct SheetState {
    var paywall = false
    var modernPaywall = false
    var documentPicker = false
    var shareSheet = false
    var fileSaver = false
    var paywallContext: PaywallContext?
}

/// Groups all alert-related state
struct AlertState {
    var showError = false
    var errorMessage = ""
    var errorTitle = ""
    var showRetryAlert = false
}

// MARK: - App Coordinator
/// Main navigation coordinator with dependency injection support
///
/// ARCHITECTURE (MVVM-C - Refactored):
/// ====================================
///
/// This coordinator follows a modular design that addresses the "God Object" anti-pattern:
///
/// 1. NAVIGATION (NavigationPath):
///    - Uses iOS 16+ NavigationStack for native navigation features
///    - Swipe-back gesture, native animations, proper memory management
///    - See: navigationPath, push(), popToRoot()
///
/// 2. BUSINESS LOGIC (Extracted to ViewModels):
///    - AnalyzeViewModel: File analysis operations
///    - CompressionViewModel: Compression workflow and retry logic
///    - ResultViewModel: Share/save operations
///
/// 3. SHEET/ALERT PRESENTATION (Grouped State):
///    - SheetState struct groups all sheet toggles
///    - AlertState struct groups all alert state
///    - This prevents cascade re-renders when unrelated state changes
///
/// 4. SERVICE INJECTION (Composition Root):
///    - All services injected via init for testability
///    - Protocol-based dependencies enable mocking
///
/// Benefits:
/// - Reduced re-render frequency (state is grouped)
/// - Clear separation of concerns
/// - Testable via dependency injection
/// - Native iOS navigation experience
@MainActor
class AppCoordinator: ObservableObject {
    // MARK: - Navigation State

    /// Current screen for ZStack-based navigation (splash, onboarding, etc.)
    @Published var currentScreen: AppScreen = .splash

    /// Navigation path for NavigationStack-based navigation
    /// ARCHITECTURE: This enables native iOS navigation features:
    /// - Swipe-to-go-back gesture
    /// - Native navigation bar animations
    /// - Proper memory management via view stack
    /// - Deep linking support
    @Published var navigationPath = NavigationPath()

    // MARK: - Sheet State (Grouped for performance)
    // NOTE: These are kept as individual @Published for SwiftUI binding compatibility
    // In a future refactor, consider using a single @Published SheetState with custom bindings

    @Published var showPaywall = false
    @Published var showModernPaywall = false
    @Published var showDocumentPicker = false
    @Published var showShareSheet = false
    @Published var showFileSaver = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var errorTitle = ""
    @Published var paywallContext: PaywallContext?

    // ARCHITECTURE FIX: Use sheets for Commitment/Rating to preserve navigation stack
    // Previously, setting currentScreen = .commitment would destroy NavigationStack
    // and cause users to lose their Result screen, breaking the back navigation.
    @Published var showCommitmentSheet = false
    @Published var showRatingSheet = false

    // MARK: - Processing State (Forwarded from ViewModels)

    @Published var currentFile: FileInfo?
    @Published var currentAnalysis: AnalysisResult?
    @Published var currentResult: CompressionResult?
    @Published var selectedPreset: CompressionPreset?

    // MARK: - Retry State

    @Published var showRetryAlert = false
    @Published var lastError: Error?
    private var retryCount = 0
    private let maxRetries = 2
    private var compressionTask: Task<Void, Never>?

    // MARK: - ViewModels (MVVM-C Architecture)

    /// ViewModel for file analysis operations
    private(set) lazy var analyzeViewModel: AnalyzeViewModel = {
        let vm = AnalyzeViewModel(
            compressionService: compressionService,
            analytics: analytics
        )
        setupAnalyzeViewModelCallbacks(vm)
        return vm
    }()

    /// ViewModel for compression operations
    private(set) lazy var compressionViewModel: CompressionViewModel = {
        let vm = CompressionViewModel(
            service: compressionService,
            historyManager: historyManager,
            subscriptionManager: subscriptionManager,
            analytics: analytics
        )
        setupCompressionViewModelCallbacks(vm)
        return vm
    }()

    /// ViewModel for result screen operations
    private(set) lazy var resultViewModel: ResultViewModel = {
        let vm = ResultViewModel(analytics: analytics)
        setupResultViewModelCallbacks(vm)
        return vm
    }()

    // MARK: - Injectable Services (Dependency Injection)

    /// Compression service - protocol-based for testability
    let compressionService: UltimatePDFCompressionService

    /// History manager
    let historyManager: HistoryManager

    /// Analytics service
    let analytics: AnalyticsService

    /// Subscription manager
    let subscriptionManager: SubscriptionManager

    @Published var subscriptionStatus: SubscriptionStatus

    // User defaults keys
    private let hasSeenOnboardingKey = "hasSeenOnboarding"
    private let hasSeenCommitmentKey = "hasSeenCommitment"
    private let hasSeenRatingRequestKey = "hasSeenRatingRequest"

    /// ONBOARDING FLOW IMPROVEMENT:
    /// Commitment and Rating screens are now shown AFTER first successful compression,
    /// not immediately after onboarding. This provides better UX by:
    /// 1. Letting users experience the app's value first
    /// 2. Building trust before asking for commitment
    /// 3. Reducing early churn from perceived "dark patterns"
    private let pendingCommitmentKey = "pendingCommitmentAfterFirstCompression"

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization (Dependency Injection)

    /// Initialize with injectable dependencies
    /// - Parameters:
    ///   - compressionService: Compression service (defaults to shared instance)
    ///   - historyManager: History manager (defaults to shared instance)
    ///   - analytics: Analytics service (defaults to shared instance)
    ///   - subscriptionManager: Subscription manager (defaults to shared instance)
    init(
        compressionService: UltimatePDFCompressionService? = nil,
        historyManager: HistoryManager? = nil,
        analytics: AnalyticsService? = nil,
        subscriptionManager: SubscriptionManager? = nil
    ) {
        // Use provided dependencies or fall back to shared instances
        self.compressionService = compressionService ?? UltimatePDFCompressionService.shared
        self.historyManager = historyManager ?? HistoryManager.shared
        self.analytics = analytics ?? AnalyticsService.shared
        self.subscriptionManager = subscriptionManager ?? SubscriptionManager.shared

        self.subscriptionStatus = self.subscriptionManager.status

        self.subscriptionManager.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.subscriptionStatus = status
            }
            .store(in: &cancellables)

        // MASTER ARCHITECTURE: Listen for feature-specific paywall requests
        setupPaywallNotificationListener()
    }

    // MARK: - Paywall Notification Listener

    /// Listen for premium feature access requests and show appropriate paywall
    private func setupPaywallNotificationListener() {
        NotificationCenter.default.publisher(for: .showPaywallForFeature)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let feature = notification.userInfo?["feature"] as? PremiumFeature else {
                    return
                }

                // Present paywall with feature-specific context
                self.presentPaywall(context: feature.paywallContext, useModernStyle: true)

                // Track analytics
                self.analytics.track(.paywallViewed)
            }
            .store(in: &cancellables)
    }

    // MARK: - ViewModel Callback Setup

    private func setupAnalyzeViewModelCallbacks(_ vm: AnalyzeViewModel) {
        vm.onAnalysisCompleted = { [weak self] file, result in
            self?.currentAnalysis = result
        }

        vm.onAnalysisFailed = { [weak self] error in
            self?.analytics.trackError(error, context: "file_analysis")
        }
    }

    private func setupCompressionViewModelCallbacks(_ vm: CompressionViewModel) {
        vm.onCompressionCompleted = { [weak self] result in
            guard let self = self else { return }
            self.currentResult = result
            self.retryCount = 0

            // ARCHITECTURE: Use NavigationStack for native navigation
            self.push(.result(result))

            // ARCHITECTURE FIX: Show commitment as sheet instead of replacing screen
            // This preserves the NavigationStack so users can see their Result
            // and navigate back naturally using swipe gestures
            if self.shouldShowCommitmentAfterCompression {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    guard self.currentResult?.id == result.id,
                          self.navigationPath.isEmpty == false else {
                        return
                    }
                    self.showCommitmentSheet = true
                }
            }
        }

        vm.onRetryAvailable = { [weak self] error in
            self?.lastError = error
            self?.showRetryAlert = true
        }

        vm.onCompressionFailed = { [weak self] error in
            guard let self = self else { return }
            self.retryCount = 0
            let userError = UserFriendlyError(error)
            self.showError(title: userError.title, message: userError.fullMessage)
            self.goHome()
        }

        vm.onCancelled = { [weak self] in
            self?.goHome()
        }
    }

    private func setupResultViewModelCallbacks(_ vm: ResultViewModel) {
        vm.onShouldShowCommitment = { [weak self] in
            guard let self = self else { return }
            // ARCHITECTURE FIX: Use sheet to preserve navigation
            self.showCommitmentSheet = true
        }

        vm.onShare = { [weak self] _ in
            self?.showShareSheet = true
        }

        vm.onSave = { [weak self] _ in
            self?.showFileSaver = true
        }
    }

    var hasSeenOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: hasSeenOnboardingKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasSeenOnboardingKey) }
    }

    var hasSeenCommitment: Bool {
        get { UserDefaults.standard.bool(forKey: hasSeenCommitmentKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasSeenCommitmentKey) }
    }

    var hasSeenRatingRequest: Bool {
        get { UserDefaults.standard.bool(forKey: hasSeenRatingRequestKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasSeenRatingRequestKey) }
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

        // UX IMPROVEMENT: Skip commitment and rating on first launch
        // Show them AFTER first successful compression to build trust first
        UserDefaults.standard.set(true, forKey: pendingCommitmentKey)

        withAnimation(AppAnimation.standard) {
            // Go directly to home - let user experience the value first
            currentScreen = .home
        }
    }

    func commitmentComplete() {
        hasSeenCommitment = true
        analytics.track(.commitmentSigned)

        // ARCHITECTURE FIX: Dismiss sheet and show rating sheet
        showCommitmentSheet = false

        // Short delay before showing rating sheet
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showRatingSheet = true
        }
    }

    func ratingRequestComplete() {
        hasSeenRatingRequest = true
        analytics.track(.ratingRequested)
        // Clear the pending flag
        UserDefaults.standard.set(false, forKey: pendingCommitmentKey)

        // ARCHITECTURE FIX: Dismiss sheet - user stays on Result screen
        showRatingSheet = false
    }

    /// Check if we should show commitment screen after successful compression
    private var shouldShowCommitmentAfterCompression: Bool {
        let isPending = UserDefaults.standard.bool(forKey: pendingCommitmentKey)
        return isPending && !hasSeenCommitment
    }

    func requestFilePicker() {
        showDocumentPicker = true
    }

    func handlePickedFile(_ url: URL) {
        showDocumentPicker = false

        Task {
            do {
                if FileValidationService.shared.needsICloudDownload(url) {
                    try FileValidationService.shared.startICloudDownload(url)
                    showError(
                        title: String(localized: "iCloud İndiriliyor", comment: "iCloud download title"),
                        message: String(localized: "Dosya iCloud'dan indiriliyor. İndirme tamamlandığında tekrar deneyin.", comment: "iCloud download message")
                    )
                    return
                }

                let validation = try await SecurityScopedResource.accessAsync(url) { accessibleURL in
                    await FileValidationService.shared.validate(url: accessibleURL)
                }

                if case .invalid(let error) = validation {
                    let messageParts = [error.errorDescription, error.recoverySuggestion].compactMap { $0 }
                    let message = messageParts.joined(separator: "\n\n")
                    showError(title: String(localized: "Dosya Hatası", comment: "File validation error title"), message: message)
                    return
                }

                let fileInfo = try FileInfo.from(url: url)
                currentFile = fileInfo

                if let paywall = subscriptionManager.paywallContext(for: fileInfo) {
                    presentPaywall(context: paywall)
                    analytics.track(.paywallViewed)
                    return
                }

                // Track file selection
                analytics.trackFileSelected(fileName: fileInfo.name, fileSize: fileInfo.size)

                // ARCHITECTURE: Use NavigationStack for native navigation
                push(.analyze(fileInfo))

                // REFACTORED: Delegate analysis to AnalyzeViewModel
                await analyzeViewModel.analyze(file: fileInfo)
            } catch {
                analytics.trackError(error, context: "file_selection")
                let userError = UserFriendlyError(error)
                showError(title: userError.title, message: userError.fullMessage)
            }
        }
    }

    /// Legacy method - kept for backward compatibility
    /// New code should use analyzeViewModel.analyze() directly
    func performAnalysis(for file: FileInfo) async {
        await analyzeViewModel.analyze(file: file)
    }

    func analyzeComplete() {
        guard let file = currentFile, let result = currentAnalysis else { return }
        // ARCHITECTURE: Use NavigationStack for native navigation
        push(.preset(file, result))
    }

    func startCompression(preset: CompressionPreset) {
        guard let file = currentFile else { return }
        selectedPreset = preset

        Task {
            let canProceed = await subscriptionManager.canPerformOperation(file: file, preset: preset)
            if !canProceed {
                if let paywall = subscriptionManager.paywallContext(for: file, preset: preset) {
                    presentPaywall(context: paywall)
                } else {
                    presentPaywall()
                }
                return
            }

            // Reset observable progress state so the progress screen is accurate immediately
            compressionService.prepareForNewTask()

            // ARCHITECTURE: Use NavigationStack for native navigation
            push(.progress(file, preset))

            // REFACTORED: Delegate compression to CompressionViewModel
            compressionTask?.cancel()
            compressionTask = Task {
                await compressionViewModel.compress(file: file, preset: preset)
            }
        }
    }

    /// Legacy method - kept for backward compatibility
    /// New code should use compressionViewModel.compress() directly
    func performCompression(file: FileInfo, preset: CompressionPreset) async {
        await compressionViewModel.compress(file: file, preset: preset)
    }

    func retryCompression() {
        guard let file = currentFile, let preset = selectedPreset else { return }
        showRetryAlert = false

        compressionService.prepareForNewTask()

        // ARCHITECTURE: Use NavigationStack for native navigation
        push(.progress(file, preset))

        // REFACTORED: Delegate retry to CompressionViewModel
        compressionTask?.cancel()
        compressionTask = Task {
            await compressionViewModel.retry()
        }
    }

    func cancelRetry() {
        showRetryAlert = false
        retryCount = 0
        goHome()
    }

    func cancelCompression() {
        compressionTask?.cancel()
        compressionTask = nil
        compressionViewModel.cancel()
    }

    func shareResult() {
        guard let result = currentResult else { return }
        // REFACTORED: Use ResultViewModel for share logic
        resultViewModel.setResult(result)
        resultViewModel.share()
    }

    func saveResult() {
        guard let result = currentResult else { return }
        // REFACTORED: Use ResultViewModel for save logic
        resultViewModel.setResult(result)
        resultViewModel.save()
    }

    func openHistory() {
        // ARCHITECTURE: Use NavigationStack for native navigation
        push(.history)
    }

    func openSettings() {
        analytics.track(.settingsOpened)
        // ARCHITECTURE: Use NavigationStack for native navigation
        push(.settings)
    }

    /// Open batch processing screen with premium gate
    func openBatchProcessing() {
        // Check if user is Pro, otherwise show paywall
        if !subscriptionStatus.isPro {
            presentPaywall(context: .batchProcessing, useModernStyle: true)
            analytics.track(.paywallViewed)
            return
        }

        analytics.track(.batchProcessingOpened)
        push(.batchProcessing)
    }

    /// Open file converter screen with premium gate
    func openConverter() {
        // Check if user is Pro, otherwise show paywall
        if !subscriptionStatus.isPro {
            presentPaywall(context: .converter, useModernStyle: true)
            analytics.track(.paywallViewed)
            return
        }

        analytics.track(.converterOpened)
        push(.converter)
    }

    /// Open storage analysis screen
    func openStorageAnalysis() {
        analytics.track(.settingsOpened) // Reuse existing event or add dedicated one
        push(.storageAnalysis)
    }

    func goBack() {
        withAnimation(AppAnimation.standard) {
            // ARCHITECTURE: Use NavigationPath for native back navigation
            if !navigationPath.isEmpty {
                navigationPath.removeLast()
                return
            }

            // Fallback for ZStack-based screens
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

    /// Push a screen onto the navigation stack
    /// ARCHITECTURE: Uses NavigationPath for native iOS navigation
    func push(_ screen: AppScreen) {
        navigationPath.append(screen)
    }

    /// Pop to the root of the navigation stack
    func popToRoot() {
        navigationPath = NavigationPath()
    }

    func goHome() {
        compressionTask?.cancel()
        compressionTask = nil
        currentFile = nil
        currentAnalysis = nil
        currentResult = nil
        selectedPreset = nil
        analyzeViewModel.reset()
        compressionViewModel.reset()
        resultViewModel.reset()

        withAnimation(AppAnimation.standard) {
            // ARCHITECTURE: Clear navigation stack for clean return to home
            navigationPath = NavigationPath()
            currentScreen = .home
        }
    }

    /// Present the paywall screen
    /// - Parameter context: Optional context describing why paywall is shown
    ///
    /// DESIGN DECISION: ModernPaywallScreen is the ONLY paywall.
    /// The legacy PaywallScreen is deprecated and should not be used.
    /// This ensures consistent premium UX across all entry points.
    func presentPaywall(context: PaywallContext? = nil, useModernStyle: Bool = true) {
        analytics.track(.paywallViewed)
        paywallContext = context ?? PaywallContext.proRequired

        // STANDARDIZED: Always use ModernPaywallScreen
        // The useModernStyle parameter is kept for API compatibility but ignored
        showModernPaywall = true
    }

    func dismissPaywall() {
        showPaywall = false
        showModernPaywall = false
        paywallContext = nil
    }

    // MARK: - Error Handling

    /// Show error with user-friendly title and message
    func showError(title: String = String(localized: "Hata", comment: "Error title"), message: String) {
        errorTitle = title
        errorMessage = message
        showError = true
    }

    func dismissError() {
        showError = false
        errorTitle = ""
        errorMessage = ""
    }
}

// MARK: - Preview Support
// NOTE: The main RootView is now in optimizeApp.swift as RootViewWithCoordinator
// This preview is kept for development convenience

#Preview("AppCoordinator") {
    // Use the coordinator directly for preview
    let coordinator = AppCoordinator()
    return NavigationStack {
        HomeScreen(
            coordinator: coordinator,
            subscriptionStatus: coordinator.subscriptionStatus,
            onSelectFile: { coordinator.requestFilePicker() },
            onOpenHistory: { coordinator.openHistory() },
            onOpenSettings: { coordinator.openSettings() },
            onUpgrade: { coordinator.presentPaywall() }
        )
    }
}
