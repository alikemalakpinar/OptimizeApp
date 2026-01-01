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
import UniformTypeIdentifiers
import Combine
import StoreKit

// MARK: - App State
enum AppScreen: Equatable {
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

    static func == (lhs: AppScreen, rhs: AppScreen) -> Bool {
        switch (lhs, rhs) {
        case (.splash, .splash),
             (.onboarding, .onboarding),
             (.commitment, .commitment),
             (.ratingRequest, .ratingRequest),
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
/// Main navigation coordinator with dependency injection support
///
/// REFACTORED (MVVM-C Architecture):
/// - Business logic extracted to AnalyzeViewModel, CompressionViewModel, ResultViewModel
/// - Coordinator now focuses on navigation and sheet/alert coordination
/// - This reduces the "God Object" anti-pattern identified in code review
///
/// Coordinator Responsibilities:
/// 1. Screen navigation (currentScreen state)
/// 2. Sheet/alert presentation (paywall, document picker, share, etc.)
/// 3. Coordinating ViewModels and connecting their callbacks to navigation
/// 4. Providing services to views
@MainActor
class AppCoordinator: ObservableObject {
    // MARK: - Navigation State

    @Published var currentScreen: AppScreen = .splash
    @Published var showPaywall = false
    @Published var showModernPaywall = false
    @Published var showDocumentPicker = false
    @Published var showShareSheet = false
    @Published var showFileSaver = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var errorTitle = ""
    @Published var paywallContext: PaywallContext?

    // Current processing data (forwarded from ViewModels)
    @Published var currentFile: FileInfo?
    @Published var currentAnalysis: AnalysisResult?
    @Published var currentResult: CompressionResult?
    @Published var selectedPreset: CompressionPreset?

    // Retry state
    @Published var showRetryAlert = false
    @Published var lastError: Error?
    private var retryCount = 0
    private let maxRetries = 2

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
    private let successCountKey = "successfulCompressionCount"

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

            // Check if commitment screen should be shown
            if self.shouldShowCommitmentAfterCompression {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(AppAnimation.standard) {
                        self.currentScreen = .commitment
                    }
                }
            }

            withAnimation(AppAnimation.standard) {
                self.currentScreen = .result(result)
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
            withAnimation(AppAnimation.standard) {
                self.currentScreen = .commitment
            }
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
        withAnimation(AppAnimation.standard) {
            // Navigate to rating request after commitment
            currentScreen = .ratingRequest
        }
    }

    func ratingRequestComplete() {
        hasSeenRatingRequest = true
        analytics.track(.ratingRequested)
        // Clear the pending flag
        UserDefaults.standard.set(false, forKey: pendingCommitmentKey)
        withAnimation(AppAnimation.standard) {
            // Navigate to home
            currentScreen = .home
        }
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

        // Reset observable progress state so the progress screen is accurate immediately
        compressionService.prepareForNewTask()

        withAnimation(AppAnimation.standard) {
            currentScreen = .progress(file, preset)
        }

        // REFACTORED: Delegate compression to CompressionViewModel
        Task {
            await compressionViewModel.compress(file: file, preset: preset)
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

        withAnimation(AppAnimation.standard) {
            currentScreen = .progress(file, preset)
        }

        // REFACTORED: Delegate retry to CompressionViewModel
        Task {
            await compressionViewModel.retry()
        }
    }

    func cancelRetry() {
        showRetryAlert = false
        retryCount = 0
        goHome()
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

    func presentPaywall(context: PaywallContext? = nil, useModernStyle: Bool = false) {
        analytics.track(.paywallViewed)
        paywallContext = context ?? PaywallContext.proRequired
        if useModernStyle {
            showModernPaywall = true
        } else {
            showPaywall = true
        }
    }

    func dismissPaywall() {
        showPaywall = false
        showModernPaywall = false
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
        .sheet(isPresented: $coordinator.showModernPaywall) {
            ModernPaywallScreen(
                onSubscribe: { plan in
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
                    if let url = URL(string: "https://optimize-app.com/privacy") {
                        UIApplication.shared.open(url)
                    }
                },
                onTerms: {
                    if let url = URL(string: "https://optimize-app.com/terms") {
                        UIApplication.shared.open(url)
                    }
                }
            )
        }
        .alert(coordinator.errorTitle.isEmpty ? "Hata" : coordinator.errorTitle, isPresented: $coordinator.showError) {
            Button("Tamam", role: .cancel) {
                coordinator.dismissError()
            }
        } message: {
            Text(coordinator.errorMessage)
        }
        .alert(String(localized: "İşlem Başarısız", comment: "Retry alert title"), isPresented: $coordinator.showRetryAlert) {
            Button(String(localized: "Tekrar Dene", comment: "Retry button")) {
                coordinator.retryCompression()
            }
            Button(String(localized: "İptal", comment: "Cancel button"), role: .cancel) {
                coordinator.cancelRetry()
            }
        } message: {
            Text(String(localized: "İşlem başarısız oldu. Tekrar denemek ister misiniz?", comment: "Retry message"))
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

        case .commitment:
            CommitmentSigningView {
                coordinator.commitmentComplete()
            }
            .transition(.opacity)

        case .ratingRequest:
            RatingRequestView {
                coordinator.ratingRequestComplete()
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
