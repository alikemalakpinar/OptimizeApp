//
//  TrustBadges.swift
//  optimize
//
//  Trust-building UI elements that communicate security and privacy.
//  These badges help convert skeptical users by emphasizing local processing.
//
//  PSYCHOLOGY:
//  - "Bank-Grade Security" → Professional, serious
//  - "No Cloud Upload" → Privacy-conscious users
//  - "Offline Capable" → Works anywhere
//  - "Device-Only" → Data never leaves phone
//

import SwiftUI

// MARK: - Security Badge Types

enum TrustBadgeType: CaseIterable, Hashable {
    case localProcessing
    case bankGradeSecurity
    case noCloudUpload
    case offlineCapable
    case encrypted
    case noTracking

    var icon: String {
        switch self {
        case .localProcessing: return "iphone"
        case .bankGradeSecurity: return "lock.shield.fill"
        case .noCloudUpload: return "icloud.slash"
        case .offlineCapable: return "wifi.slash"
        case .encrypted: return "key.fill"
        case .noTracking: return "eye.slash"
        }
    }

    var title: String {
        switch self {
        case .localProcessing: return "Cihazda İşlenir"
        case .bankGradeSecurity: return "Banka Seviyesi Güvenlik"
        case .noCloudUpload: return "Buluta Yükleme Yok"
        case .offlineCapable: return "Çevrimdışı Çalışır"
        case .encrypted: return "AES-256 Şifreleme"
        case .noTracking: return "İzleme Yok"
        }
    }

    var englishTitle: String {
        switch self {
        case .localProcessing: return "On-Device Processing"
        case .bankGradeSecurity: return "Bank-Grade Security"
        case .noCloudUpload: return "No Cloud Upload"
        case .offlineCapable: return "Works Offline"
        case .encrypted: return "AES-256 Encrypted"
        case .noTracking: return "No Tracking"
        }
    }

    var color: Color {
        switch self {
        case .localProcessing: return .blue
        case .bankGradeSecurity: return .green
        case .noCloudUpload: return .orange
        case .offlineCapable: return .purple
        case .encrypted: return .cyan
        case .noTracking: return .pink
        }
    }
}

// MARK: - Single Trust Badge

struct TrustBadge: View {
    let type: TrustBadgeType
    var style: BadgeStyle = .compact

    enum BadgeStyle {
        case compact    // Icon + short text in pill
        case expanded   // Icon + text + description
        case iconOnly   // Just icon with tooltip
    }

    var body: some View {
        switch style {
        case .compact:
            compactBadge
        case .expanded:
            expandedBadge
        case .iconOnly:
            iconOnlyBadge
        }
    }

    private var compactBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: type.icon)
                .font(.system(size: 11, weight: .semibold))
            Text(type.title)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(100)
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var expandedBadge: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(type.color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: type.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(type.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(type.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)

                Text(type.englishTitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var iconOnlyBadge: some View {
        Image(systemName: type.icon)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(type.color)
            .padding(8)
            .background(type.color.opacity(0.1))
            .clipShape(Circle())
            .help(type.title) // Tooltip on hover (iPadOS/macOS)
    }
}

// MARK: - Trust Badge Row (Multiple Badges)

struct TrustBadgeRow: View {
    var badges: [TrustBadgeType] = [.localProcessing, .noCloudUpload]
    var style: TrustBadge.BadgeStyle = .compact

    var body: some View {
        HStack(spacing: 8) {
            ForEach(badges, id: \.self) { badge in
                TrustBadge(type: badge, style: style)
            }
        }
    }
}

// MARK: - Trust Indicator Strip (For Paywall/Onboarding)

struct TrustIndicatorStrip: View {
    @State private var currentIndex = 0
    private let badges: [TrustBadgeType] = [.localProcessing, .bankGradeSecurity, .noCloudUpload, .offlineCapable]

    var body: some View {
        VStack(spacing: 12) {
            // Rotating badge display
            HStack(spacing: 6) {
                Image(systemName: badges[currentIndex].icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(badges[currentIndex].color)

                Text(badges[currentIndex].title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(100)
            .animation(.easeInOut, value: currentIndex)

            // Dot indicators
            HStack(spacing: 4) {
                ForEach(0..<badges.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentIndex ? badges[index].color : Color.gray.opacity(0.3))
                        .frame(width: 4, height: 4)
                }
            }
        }
        .onAppear {
            startRotation()
        }
    }

    private func startRotation() {
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation {
                currentIndex = (currentIndex + 1) % badges.count
            }
        }
    }
}

// MARK: - Security Shield View (Larger Display)

struct SecurityShieldView: View {
    var body: some View {
        VStack(spacing: 16) {
            // Shield icon with glow
            ZStack {
                // Glow effect
                Circle()
                    .fill(Color.appMint.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)

                // Shield
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.appMint, .appTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("Dosyalarınız Güvende")
                    .font(.system(size: 18, weight: .bold, design: .rounded))

                Text("Tüm işlemler cihazınızda gerçekleşir.\nVerileriniz asla telefonunuzdan çıkmaz.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // Badge grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach([TrustBadgeType.localProcessing, .noCloudUpload, .encrypted, .noTracking], id: \.self) { badge in
                    TrustBadge(type: badge, style: .compact)
                }
            }
        }
        .padding(24)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
    }
}

// MARK: - Processing Security Overlay

struct ProcessingSecurityIndicator: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.appMint)

            Text("AES-256 • Local Only")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(100)
    }
}

// MARK: - Preview

#Preview("Trust Badges") {
    VStack(spacing: 24) {
        // Compact row
        TrustBadgeRow(badges: [.localProcessing, .noCloudUpload, .offlineCapable])

        // Expanded badges
        VStack(spacing: 8) {
            TrustBadge(type: .bankGradeSecurity, style: .expanded)
            TrustBadge(type: .localProcessing, style: .expanded)
        }
        .padding(.horizontal)

        // Icon only
        HStack(spacing: 12) {
            ForEach(TrustBadgeType.allCases, id: \.self) { badge in
                TrustBadge(type: badge, style: .iconOnly)
            }
        }

        // Rotating strip
        TrustIndicatorStrip()

        // Security shield
        SecurityShieldView()
            .padding(.horizontal)
    }
    .padding()
}
