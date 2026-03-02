//
//  optimizeApp.swift
//  optimize
//
//  Created by Ali kemal Akpinar on 30.12.2025.
//
//  COMPOSITION ROOT
//  ================
//  This is the single place where all dependencies are created and wired together.
//  All services are instantiated here and injected into the coordinator.
//
//  Benefits:
//  - Single source of truth for dependency creation
//  - Easy to swap implementations for testing
//  - Clear visibility of all app dependencies
//  - Eliminates hidden dependencies via Singletons
//

import SwiftUI
import UIKit

/// App entry point - Composition Root for Dependency Injection
@main
struct optimizeApp: App {

    // MARK: - Coordinator (via Static Dependency Container)

    /// Coordinator is initialized exactly once via AppDependencies static lazy property.
    /// This avoids the re-initialization risk from SwiftUI re-creating the App struct,
    /// which would call init() repeatedly and create new coordinator instances each time.
    @StateObject private var coordinator = AppDependencies.coordinator

    // MARK: - App Body

    var body: some Scene {
        WindowGroup {
            // RootView now uses the coordinator passed from composition root
            RootViewWithCoordinator(coordinator: coordinator)
        }
    }
}

// MARK: - Dependency Container (Static Lazy Initialization)

/// All dependencies are created exactly once via Swift's static lazy guarantee.
/// This replaces the previous init()-based approach where the coordinator could be
/// re-created on every SwiftUI App struct re-render.
///
/// Benefits:
/// - Coordinator is guaranteed to be created exactly once (static let)
/// - Dependencies are explicitly wired (preserves Composition Root pattern)
/// - Easy to swap implementations for testing via AppCoordinator's optional init params
@MainActor
private enum AppDependencies {
    static let coordinator: AppCoordinator = {
        AppCoordinator(
            compressionService: UltimatePDFCompressionService.shared,
            historyManager: HistoryManager.shared,
            analytics: AnalyticsService.shared,
            subscriptionManager: SubscriptionManager.shared
        )
    }()
}

// MARK: - Root View with Injected Coordinator

/// Root view that accepts an externally created coordinator
/// This allows the coordinator to be created at the composition root
/// and enables dependency injection for the entire view hierarchy
///
/// ARCHITECTURE (iOS 16+ NavigationStack):
/// - Uses NavigationStack for main app flow (home -> analyze -> preset -> result)
/// - Keeps ZStack for full-screen overlays (splash, onboarding, commitment, rating)
/// - Enables native iOS navigation features:
///   * Swipe-to-go-back gesture
///   * Native navigation bar animations
///   * Proper memory management
///   * Deep linking support
struct RootViewWithCoordinator: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        ZStack {
            // Full-screen flows (onboarding, splash, etc.) are handled via ZStack
            // Main app flow uses NavigationStack for native navigation
            if coordinator.currentScreen.usesNavigationStack {
                navigationContent
            } else {
                fullScreenContent
            }
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
        // Paywall is always fullScreenCover for maximum conversion
        // See: AppCoordinator.presentPaywall() which sets showModernPaywall = true
        .fullScreenCover(isPresented: $coordinator.showModernPaywall) {
            ModernPaywallScreen(
                subscriptionManager: coordinator.subscriptionManager,
                context: coordinator.paywallContext,  // MASTER: Pass feature-specific context
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
                                let userError = UserFriendlyError(error)
                                coordinator.showError(title: userError.title, message: userError.fullMessage)
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
        // ARCHITECTURE FIX: Commitment and Rating screens shown as fullScreenCovers
        // This preserves the NavigationStack so users don't lose their Result screen
        .fullScreenCover(isPresented: $coordinator.showCommitmentSheet) {
            CommitmentSigningView {
                coordinator.commitmentComplete()
            }
        }
        .fullScreenCover(isPresented: $coordinator.showRatingSheet) {
            RatingRequestView {
                coordinator.ratingRequestComplete()
            }
        }
        .fullScreenCover(isPresented: $coordinator.showFileViewer) {
            if let url = coordinator.fileViewerURL {
                UniversalFileViewer(
                    fileURL: url,
                    fileName: coordinator.fileViewerName,
                    fileSize: coordinator.fileViewerSize,
                    fileType: coordinator.fileViewerType,
                    onShare: { coordinator.shareFileViewerFile() },
                    onSave: { coordinator.saveFileViewerFile() },
                    onDismiss: { coordinator.dismissFileViewer() }
                )
            }
        }
    }

    // MARK: - Navigation Stack Content (iOS 16+ Native Navigation)

    /// Main app content with NavigationStack for native navigation features
    @ViewBuilder
    private var navigationContent: some View {
        ZStack(alignment: .bottom) {
            NavigationStack(path: $coordinator.navigationPath) {
                // Root: HomeScreen
                HomeScreen(
                    coordinator: coordinator,
                    subscriptionStatus: coordinator.subscriptionStatus,
                    onSelectFile: { coordinator.requestFilePicker() },
                    onOpenHistory: { coordinator.openHistory() },
                    onOpenSettings: { coordinator.openSettings() },
                    onUpgrade: { coordinator.presentPaywall() },
                    onBatchProcessing: { coordinator.openBatchProcessing() },
                    onConverter: { coordinator.openConverter() },
                    onStorageAnalysis: { coordinator.openStorageAnalysis() }
                )
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 90) // Tab bar boşluğu
                }
                .toolbar(.hidden, for: .navigationBar) // [FIX] Home'da native barı gizle - Double Header önleme
                .navigationDestination(for: AppScreen.self) { screen in
                    destinationView(for: screen)
                }
            }

            // Floating Tab Bar (Sadece ana sayfada görünür)
            if coordinator.navigationPath.isEmpty {
                FloatingTabBar(
                    selectedTab: .constant(.home),
                    onAddTap: { coordinator.requestFilePicker() },
                    onHistoryTap: { coordinator.openHistory() },
                    onSettingsTap: { coordinator.openSettings() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(AppAnimation.spring, value: coordinator.navigationPath.isEmpty)
    }

    /// Builds the destination view for each screen type
    /// [FIX] Double Header sorunu çözüldü - her ekranda native bar gizleniyor
    @ViewBuilder
    private func destinationView(for screen: AppScreen) -> some View {
        switch screen {
        case .analyze(let file):
            AnalyzeScreen(
                file: file,
                analysisResult: coordinator.currentAnalysis,
                analysisState: coordinator.analyzeViewModel.state,
                subscriptionStatus: coordinator.subscriptionStatus,
                paywallContext: coordinator.paywallContext,
                onContinue: { coordinator.analyzeComplete() },
                onBack: { coordinator.goBack() },
                onReplace: { coordinator.requestFilePicker() },
                onRetry: {
                    Task { await coordinator.performAnalysis(for: file) }
                },
                onUpgrade: { coordinator.presentPaywall(context: coordinator.paywallContext) }
            )
            .toolbar(.hidden, for: .navigationBar) // Özel başlık var, native gizle

        case .preset(let file, let analysis):
            PresetScreen(
                file: file,
                analysisResult: analysis,
                isProUser: coordinator.subscriptionStatus.isPro,
                onCompress: { preset in coordinator.startCompression(preset: preset) },
                onBack: { coordinator.goBack() },
                onShowPaywall: { coordinator.presentPaywall() }
            )
            .toolbar(.hidden, for: .navigationBar) // Özel başlık var, native gizle

        case .progress(let file, let preset):
            ProgressScreen(
                file: file,
                preset: preset,
                compressionService: coordinator.compressionService,
                onCancel: { coordinator.cancelCompression() }
            )
            .toolbar(.hidden, for: .navigationBar) // Özel başlık var, native gizle

        case .result(let result):
            ResultScreen(
                result: result,
                onShare: { coordinator.shareResult() },
                onSave: { coordinator.saveResult() },
                onNewFile: { coordinator.goHome() }
            )
            .toolbar(.hidden, for: .navigationBar) // Özel başlık var, native gizle

        case .history:
            HistoryScreen(
                historyManager: coordinator.historyManager,
                onBack: { coordinator.goBack() }
            )
            .toolbar(.hidden, for: .navigationBar) // Özel başlık var, native gizle

        case .settings:
            // SettingsScreen native List kullandığı için özel handling
            SettingsScreen(
                subscriptionStatus: coordinator.subscriptionStatus,
                onUpgrade: { coordinator.presentPaywall() },
                onBack: { coordinator.goBack() }
            )
            .navigationBarBackButtonHidden(true) // Coordinator'ın yönettiği özel back butonu için

        case .batchProcessing:
            BatchProcessingScreen(
                onBack: { coordinator.goBack() }
            )
            .toolbar(.hidden, for: .navigationBar)

        case .converter:
            ConverterScreen(
                onBack: { coordinator.goBack() }
            )
            .toolbar(.hidden, for: .navigationBar)

        case .storageAnalysis:
            StorageAnalysisScreen(
                onBack: { coordinator.goBack() }
            )
            .toolbar(.hidden, for: .navigationBar)

        default:
            EmptyView()
        }
    }

    // MARK: - Full Screen Content (Splash, Onboarding, etc.)

    /// Full-screen overlays that don't use navigation stack
    @ViewBuilder
    private var fullScreenContent: some View {
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

        default:
            EmptyView()
        }
    }
}
