//
//  EmptyStateViews.swift
//  optimize
//
//  Beautiful empty state views for when there's no content to display.
//  Following Apple HIG: "Always provide guidance, never leave users stranded."
//
//  USAGE:
//  - History screen with no compression history
//  - File selection with no files
//  - Search with no results
//  - Error recovery states
//

import SwiftUI

// MARK: - Empty State Types

enum EmptyStateType: Equatable {
    case noHistory
    case noFiles
    case noResults
    case error(message: String)
    case offline
    case premium

    var icon: String {
        switch self {
        case .noHistory: return "clock.badge.questionmark"
        case .noFiles: return "doc.badge.plus"
        case .noResults: return "magnifyingglass"
        case .error: return "exclamationmark.triangle"
        case .offline: return "wifi.slash"
        case .premium: return "crown"
        }
    }

    var title: String {
        switch self {
        case .noHistory: return "Henüz İşlem Yok"
        case .noFiles: return "Dosya Seçilmedi"
        case .noResults: return "Sonuç Bulunamadı"
        case .error: return "Bir Şeyler Ters Gitti"
        case .offline: return "Bağlantı Yok"
        case .premium: return "Premium Özellik"
        }
    }

    var message: String {
        switch self {
        case .noHistory:
            return "İlk dosyanızı sıkıştırarak başlayın.\nTüm işlemleriniz burada görünecek."
        case .noFiles:
            return "PDF, resim veya video seçerek\noptimizasyona başlayın."
        case .noResults:
            return "Aramanızla eşleşen sonuç bulunamadı.\nFarklı anahtar kelimeler deneyin."
        case .error(let message):
            return message
        case .offline:
            return "İnternet bağlantısı gerekli.\nLütfen bağlantınızı kontrol edin."
        case .premium:
            return "Bu özelliği kullanmak için\nPremium'a yükseltin."
        }
    }

    var actionTitle: String? {
        switch self {
        case .noHistory, .noFiles: return "Dosya Seç"
        case .noResults: return nil
        case .error: return "Tekrar Dene"
        case .offline: return "Ayarları Aç"
        case .premium: return "Premium'a Yükselt"
        }
    }

    var iconColor: Color {
        switch self {
        case .noHistory: return .blue
        case .noFiles: return .appMint
        case .noResults: return .orange
        case .error: return .red
        case .offline: return .gray
        case .premium: return .yellow
        }
    }
}

// MARK: - Main Empty State View

struct EmptyStateView: View {
    let type: EmptyStateType
    var action: (() -> Void)? = nil

    @State private var iconScale: CGFloat = 0.8
    @State private var iconOpacity: Double = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Animated Icon
            ZStack {
                // Background glow
                Circle()
                    .fill(type.iconColor.opacity(0.1))
                    .frame(width: 120, height: 120)

                // Icon container
                Circle()
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 88, height: 88)
                    .overlay(
                        Circle()
                            .stroke(type.iconColor.opacity(0.2), lineWidth: 1)
                    )

                // Icon
                Image(systemName: type.icon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(type.iconColor)
            }
            .scaleEffect(iconScale)
            .opacity(iconOpacity)

            // Text content
            VStack(spacing: 12) {
                Text(type.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text(type.message)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
            }

            // Action button
            if let actionTitle = type.actionTitle, let action = action {
                Button(action: action) {
                    HStack(spacing: 8) {
                        if type == .premium {
                            Image(systemName: "crown.fill")
                        }
                        Text(actionTitle)
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(type == .premium ? .black : .white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        type == .premium
                            ? AnyShapeStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(Color.appMint)
                    )
                    .cornerRadius(14)
                }
                .padding(.top, 8)
            }

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
        }
    }
}

// MARK: - Compact Empty State (For smaller spaces)

struct CompactEmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
    }
}

// MARK: - History Empty State (Specific Design)

struct HistoryEmptyState: View {
    let onSelectFile: () -> Void

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated illustration
            ZStack {
                // Background circles
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.appMint.opacity(0.1 - Double(i) * 0.03), lineWidth: 1)
                        .frame(width: 150 + CGFloat(i) * 40, height: 150 + CGFloat(i) * 40)
                        .scaleEffect(isAnimating ? 1.05 : 1.0)
                        .animation(
                            .easeInOut(duration: 2)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.3),
                            value: isAnimating
                        )
                }

                // Main icon container
                Circle()
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 100, height: 100)
                    .shadow(color: .black.opacity(0.1), radius: 20, y: 10)

                // Clock icon
                Image(systemName: "clock")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.appMint, .appTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // Text
            VStack(spacing: 12) {
                Text("Geçmiş Boş")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                Text("İlk dosyanızı sıkıştırın ve\noptimizasyon yolculuğunuza başlayın!")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // CTA Button
            Button(action: onSelectFile) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                    Text("İlk Dosyayı Seç")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(Color.appMint)
                .cornerRadius(14)
            }

            Spacer()
            Spacer()
        }
        .padding()
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Loading State

struct LoadingStateView: View {
    let message: String

    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            // Custom spinner
            ZStack {
                Circle()
                    .stroke(Color.appMint.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.appMint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(rotation))
            }

            Text(message)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Error State with Retry

struct ErrorStateView: View {
    let title: String
    let message: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Error icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.red)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))

                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button(action: retryAction) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Tekrar Dene")
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.red)
                .cornerRadius(10)
            }
        }
        .padding()
    }
}

// MARK: - Preview

#Preview("Empty States") {
    ScrollView {
        VStack(spacing: 40) {
            EmptyStateView(type: .noHistory) {
                print("Select file")
            }
            .frame(height: 400)

            Divider()

            HistoryEmptyState {
                print("Select")
            }
            .frame(height: 400)

            Divider()

            EmptyStateView(type: .error(message: "Dosya işlenirken bir hata oluştu.")) {
                print("Retry")
            }
            .frame(height: 400)
        }
    }
    .background(Color(.systemBackground))
}
