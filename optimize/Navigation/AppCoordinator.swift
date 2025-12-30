//
//  AppCoordinator.swift
//  optimize
//
//  Main navigation coordinator
//

import SwiftUI

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
}

// MARK: - App Coordinator
@MainActor
class AppCoordinator: ObservableObject {
    @Published var currentScreen: AppScreen = .splash
    @Published var showPaywall = false
    @Published var navigationPath: [AppScreen] = []

    // User defaults keys
    private let hasSeenOnboardingKey = "hasSeenOnboarding"

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
        withAnimation(AppAnimation.standard) {
            currentScreen = .home
        }
    }

    func selectFile(_ file: FileInfo) {
        withAnimation(AppAnimation.standard) {
            currentScreen = .analyze(file)
        }
    }

    func analyzeComplete(file: FileInfo, result: AnalysisResult) {
        withAnimation(AppAnimation.standard) {
            currentScreen = .preset(file, result)
        }
    }

    func startCompression(file: FileInfo, preset: CompressionPreset) {
        withAnimation(AppAnimation.standard) {
            currentScreen = .progress(file, preset)
        }
    }

    func compressionComplete(result: CompressionResult) {
        withAnimation(AppAnimation.standard) {
            currentScreen = .result(result)
        }
    }

    func openHistory() {
        withAnimation(AppAnimation.standard) {
            currentScreen = .history
        }
    }

    func openSettings() {
        withAnimation(AppAnimation.standard) {
            currentScreen = .settings
        }
    }

    func goBack() {
        withAnimation(AppAnimation.standard) {
            currentScreen = .home
        }
    }

    func goHome() {
        withAnimation(AppAnimation.standard) {
            currentScreen = .home
        }
    }

    func presentPaywall() {
        showPaywall = true
    }

    func dismissPaywall() {
        showPaywall = false
    }
}

// MARK: - Root View
struct RootView: View {
    @StateObject private var coordinator = AppCoordinator()

    var body: some View {
        ZStack {
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
                    onSelectFile: {
                        // Demo: Create sample file
                        let sampleFile = FileInfo(
                            name: "Rapor_2024.pdf",
                            url: URL(fileURLWithPath: "/sample.pdf"),
                            size: 300_000_000,
                            pageCount: 84,
                            fileType: .pdf
                        )
                        coordinator.selectFile(sampleFile)
                    },
                    onOpenHistory: {
                        coordinator.openHistory()
                    },
                    onOpenSettings: {
                        coordinator.openSettings()
                    }
                )
                .transition(.opacity)

            case .analyze(let file):
                AnalyzeScreen(
                    file: file,
                    analysisResult: AnalysisResult(
                        pageCount: file.pageCount ?? 84,
                        imageCount: 42,
                        imageDensity: .high,
                        estimatedSavings: .high,
                        isAlreadyOptimized: false,
                        originalDPI: 300
                    ),
                    onContinue: {
                        let result = AnalysisResult(
                            pageCount: file.pageCount ?? 84,
                            imageCount: 42,
                            imageDensity: .high,
                            estimatedSavings: .high,
                            isAlreadyOptimized: false,
                            originalDPI: 300
                        )
                        coordinator.analyzeComplete(file: file, result: result)
                    },
                    onBack: {
                        coordinator.goBack()
                    },
                    onReplace: {
                        coordinator.goBack()
                    }
                )
                .transition(.move(edge: .trailing))

            case .preset(let file, _):
                PresetScreen(
                    onCompress: { preset in
                        coordinator.startCompression(file: file, preset: preset)
                    },
                    onBack: {
                        coordinator.goBack()
                    },
                    onShowPaywall: {
                        coordinator.presentPaywall()
                    }
                )
                .transition(.move(edge: .trailing))

            case .progress(let file, _):
                ProgressScreen(
                    onCancel: {
                        coordinator.goBack()
                    }
                )
                .transition(.opacity)
                .onAppear {
                    // Simulate compression completion
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                        let result = CompressionResult(
                            originalFile: file,
                            compressedURL: URL(fileURLWithPath: "/compressed.pdf"),
                            compressedSize: 92_000_000
                        )
                        coordinator.compressionComplete(result: result)
                    }
                }

            case .result(let result):
                ResultScreen(
                    result: result,
                    onShare: {
                        // Share action
                    },
                    onSave: {
                        // Save action
                    },
                    onNewFile: {
                        coordinator.goHome()
                    }
                )
                .transition(.opacity)

            case .history:
                HistoryScreen(
                    onBack: {
                        coordinator.goBack()
                    }
                )
                .transition(.move(edge: .trailing))

            case .settings:
                SettingsScreen(
                    onBack: {
                        coordinator.goBack()
                    }
                )
                .transition(.move(edge: .trailing))
            }
        }
        .sheet(isPresented: $coordinator.showPaywall) {
            PaywallScreen(
                onSubscribe: { plan in
                    // Handle subscription
                    coordinator.dismissPaywall()
                },
                onRestore: {
                    // Handle restore
                },
                onDismiss: {
                    coordinator.dismissPaywall()
                },
                onPrivacy: {
                    // Open privacy policy
                },
                onTerms: {
                    // Open terms
                }
            )
        }
    }
}

#Preview {
    RootView()
}
