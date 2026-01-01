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

/// App entry point - Composition Root for Dependency Injection
@main
struct optimizeApp: App {

    // MARK: - Service Container (Composition Root)

    /// Shared services created at app launch
    /// These are the ONLY place Singletons should be accessed directly
    private let compressionService: UltimatePDFCompressionService
    private let subscriptionManager: SubscriptionManager
    private let historyManager: HistoryManager
    private let analyticsService: AnalyticsService

    /// Main coordinator with injected dependencies
    @StateObject private var coordinator: AppCoordinator

    // MARK: - Initialization

    init() {
        // Create all services at the composition root
        // This is the ONLY place we use .shared singletons directly
        let compression = UltimatePDFCompressionService.shared
        let subscription = SubscriptionManager.shared
        let history = HistoryManager.shared
        let analytics = AnalyticsService.shared

        self.compressionService = compression
        self.subscriptionManager = subscription
        self.historyManager = history
        self.analyticsService = analytics

        // Create coordinator with injected dependencies
        // This enables testing by allowing mock services to be injected
        let coordinator = AppCoordinator(
            compressionService: compression,
            historyManager: history,
            analytics: analytics,
            subscriptionManager: subscription
        )

        // Use _coordinator to initialize @StateObject
        _coordinator = StateObject(wrappedValue: coordinator)
    }

    // MARK: - App Body

    var body: some Scene {
        WindowGroup {
            // RootView now uses the coordinator passed from composition root
            RootViewWithCoordinator(coordinator: coordinator)
        }
    }
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
        .sheet(isPresented: $coordinator.showPaywall) {
            PaywallScreen(
                context: coordinator.paywallContext,
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
    }

    // MARK: - Navigation Stack Content (iOS 16+ Native Navigation)

    /// Main app content with NavigationStack for native navigation features
    @ViewBuilder
    private var navigationContent: some View {
        ZStack(alignment: .bottom) {
            NavigationStack(path: $coordinator.navigationPath) {
                // Root of navigation stack is HomeScreen
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
                .safeAreaInset(edge: .bottom) {
                    // Reserve space for floating tab bar only on home
                    Color.clear
                        .frame(height: 90)
                }
                .navigationDestination(for: AppScreen.self) { screen in
                    destinationView(for: screen)
                }
            }

            // Floating Tab Bar - only visible when navigation stack is empty (on Home)
            if coordinator.navigationPath.isEmpty {
                FloatingTabBar(
                    selectedTab: .constant(.home),
                    onAddTap: {
                        coordinator.requestFilePicker()
                    },
                    onHistoryTap: {
                        coordinator.openHistory()
                    },
                    onSettingsTap: {
                        coordinator.openSettings()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(AppAnimation.spring, value: coordinator.navigationPath.isEmpty)
    }

    /// Builds the destination view for each screen type
    @ViewBuilder
    private func destinationView(for screen: AppScreen) -> some View {
        switch screen {
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

        case .progress(let file, let preset):
            ProgressScreen(
                file: file,
                preset: preset,
                compressionService: coordinator.compressionService,
                onCancel: {
                    coordinator.goHome()
                }
            )

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

        case .history:
            HistoryScreen(
                historyManager: coordinator.historyManager,
                onBack: {
                    coordinator.goBack()
                }
            )

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

        default:
            // Fallback for screens that shouldn't be in NavigationStack
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
