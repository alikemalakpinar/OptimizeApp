//
//  CelebrationView.swift
//  optimize
//
//  Celebratory animations and motivational messages for task completion.
//  Provides confetti, success animations, and meaningful savings messages.
//
//  "Turn boring 'Done' messages into memorable moments"
//

import SwiftUI

// MARK: - Celebration Type

enum CelebrationType {
    case compression(savedBytes: Int64, originalSize: Int64)
    case batch(fileCount: Int, totalSaved: Int64)
    case milestone(title: String, description: String)
    case achievement(name: String, icon: String)
}

// MARK: - Celebration View

struct CelebrationView: View {
    let type: CelebrationType
    let onDismiss: () -> Void

    @State private var showConfetti = false
    @State private var animateContent = false
    @State private var animateStats = false

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Content
            VStack(spacing: 24) {
                // Success Icon
                successIcon
                    .scaleEffect(animateContent ? 1.0 : 0.5)
                    .opacity(animateContent ? 1.0 : 0.0)

                // Message
                messageContent
                    .opacity(animateContent ? 1.0 : 0.0)
                    .offset(y: animateContent ? 0 : 20)

                // Stats
                statsContent
                    .opacity(animateStats ? 1.0 : 0.0)
                    .offset(y: animateStats ? 0 : 10)

                // Action Button
                Button(action: onDismiss) {
                    Text("Harika!")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.green, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 32)
                .opacity(animateStats ? 1.0 : 0.0)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(.ultraThinMaterial)
            )
            .padding(24)
            .scaleEffect(animateContent ? 1.0 : 0.9)

            // Confetti
            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            HapticManager.shared.trigger(.celebration)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showConfetti = true
                animateContent = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                animateStats = true
            }
        }
    }

    // MARK: - Success Icon

    private var successIcon: some View {
        ZStack {
            // Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.green.opacity(0.5), .clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)

            // Icon
            Image(systemName: iconName)
                .font(.system(size: 50, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.bounce, value: animateContent)
        }
    }

    private var iconName: String {
        switch type {
        case .compression: return "checkmark.circle.fill"
        case .batch: return "checkmark.seal.fill"
        case .milestone: return "star.fill"
        case .achievement: return "trophy.fill"
        }
    }

    // MARK: - Message Content

    private var messageContent: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.title.bold())
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var title: String {
        switch type {
        case .compression: return "Sıkıştırma Başarılı!"
        case .batch(let count, _): return "\(count) Dosya Sıkıştırıldı!"
        case .milestone(let title, _): return title
        case .achievement(let name, _): return name
        }
    }

    private var subtitle: String {
        switch type {
        case .compression(let saved, let original):
            let percentage = Int(Double(saved) / Double(original) * 100)
            return "Dosyanız %\(percentage) küçültüldü"
        case .batch(_, let total):
            return ByteCountFormatter.string(fromByteCount: total, countStyle: .file) + " tasarruf edildi"
        case .milestone(_, let description): return description
        case .achievement: return "Yeni başarı kazandınız!"
        }
    }

    // MARK: - Stats Content

    @ViewBuilder
    private var statsContent: some View {
        switch type {
        case .compression(let saved, _):
            compressionStats(saved: saved)
        case .batch(let count, let total):
            batchStats(count: count, total: total)
        case .milestone, .achievement:
            EmptyView()
        }
    }

    private func compressionStats(saved: Int64) -> some View {
        VStack(spacing: 16) {
            // Savings amount
            HStack(spacing: 16) {
                statItem(
                    value: ByteCountFormatter.string(fromByteCount: saved, countStyle: .file),
                    label: "Tasarruf"
                )

                Divider()
                    .frame(height: 40)

                statItem(
                    value: "\(equivalentPhotos(bytes: saved))",
                    label: "Fotoğraf Değeri"
                )
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Motivational message
            Text(motivationalMessage(bytes: saved))
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func batchStats(count: Int, total: Int64) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                statItem(value: "\(count)", label: "Dosya")
                Divider().frame(height: 40)
                statItem(
                    value: ByteCountFormatter.string(fromByteCount: total, countStyle: .file),
                    label: "Toplam Tasarruf"
                )
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.green)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Calculations

    private func equivalentPhotos(bytes: Int64) -> Int {
        max(1, Int(bytes / (3 * 1024 * 1024))) // ~3MB per photo
    }

    private func motivationalMessage(bytes: Int64) -> String {
        let photos = equivalentPhotos(bytes: bytes)
        let songs = Int(bytes / (4 * 1024 * 1024))

        if photos >= 100 {
            return "🎉 Tam \(photos) fotoğraflık yer açtın! Tatil anılarına hazırsın."
        } else if photos >= 50 {
            return "📸 \(photos) yeni fotoğraf çekebilirsin! Kamerayı ısıt."
        } else if photos >= 10 {
            return "✨ \(photos) fotoğraf daha çekebilecek alan kazandın!"
        } else if songs >= 10 {
            return "🎵 \(songs) şarkılık yer açtın. Playlist'i genişlet!"
        } else {
            return "💾 Telefonun sana teşekkür ediyor!"
        }
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    ConfettiParticleView(particle: particle)
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
            }
        }
        .allowsHitTesting(false)
    }

    private func createParticles(in size: CGSize) {
        particles = (0..<50).map { _ in
            ConfettiParticle(
                x: CGFloat.random(in: 0...size.width),
                y: -20,
                color: [Color.red, .orange, .yellow, .green, .blue, .purple, .pink].randomElement()!,
                size: CGFloat.random(in: 6...12),
                rotation: Double.random(in: 0...360),
                velocity: CGFloat.random(in: 200...400),
                horizontalVelocity: CGFloat.random(in: -100...100)
            )
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let color: Color
    let size: CGFloat
    var rotation: Double
    let velocity: CGFloat
    let horizontalVelocity: CGFloat
}

struct ConfettiParticleView: View {
    let particle: ConfettiParticle
    @State private var animatedY: CGFloat = -20
    @State private var animatedX: CGFloat = 0
    @State private var animatedRotation: Double = 0
    @State private var opacity: Double = 1

    var body: some View {
        Rectangle()
            .fill(particle.color)
            .frame(width: particle.size, height: particle.size * 1.5)
            .rotationEffect(.degrees(animatedRotation))
            .position(x: particle.x + animatedX, y: animatedY)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeIn(duration: Double.random(in: 2...3))) {
                    animatedY = UIScreen.main.bounds.height + 50
                    animatedX = particle.horizontalVelocity
                    animatedRotation = particle.rotation + Double.random(in: 360...720)
                }
                withAnimation(.easeIn(duration: 2).delay(1)) {
                    opacity = 0
                }
            }
    }
}

// MARK: - Quick Celebration

struct QuickCelebrationBanner: View {
    let message: String
    let icon: String
    @Binding var isShowing: Bool

    var body: some View {
        if isShowing {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.green)
                    .symbolEffect(.bounce, value: isShowing)

                Text(message)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
            )
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
            .onAppear {
                HapticManager.shared.trigger(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { isShowing = false }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CelebrationView(
        type: .compression(savedBytes: 15_000_000, originalSize: 20_000_000),
        onDismiss: {}
    )
}
