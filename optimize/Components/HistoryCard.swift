//
//  HistoryCard.swift
//  optimize
//
//  Enhanced history card with visual progress bars showing compression results.
//  Transforms boring file lists into satisfying achievement displays.
//
//  DESIGN PHILOSOPHY:
//  - Show, don't tell - visual progress is more satisfying than numbers
//  - Green = success, make it prominent
//  - Every card should feel like a small victory
//

import SwiftUI

// MARK: - History Item Model

struct HistoryItem: Identifiable {
    let id: UUID
    let fileName: String
    let originalSize: Int64
    let compressedSize: Int64
    let compressionDate: Date
    let fileType: FileCategory
    let thumbnailURL: URL?

    var savedBytes: Int64 {
        originalSize - compressedSize
    }

    var savedPercentage: Double {
        guard originalSize > 0 else { return 0 }
        return Double(savedBytes) / Double(originalSize)
    }

    var formattedOriginalSize: String {
        ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file)
    }

    var formattedCompressedSize: String {
        ByteCountFormatter.string(fromByteCount: compressedSize, countStyle: .file)
    }

    var formattedSavedSize: String {
        ByteCountFormatter.string(fromByteCount: savedBytes, countStyle: .file)
    }

    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: compressionDate, relativeTo: Date())
    }
}

// MARK: - History Card View

struct HistoryCard: View {
    let item: HistoryItem
    let onTap: () -> Void

    @State private var animateProgress = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Thumbnail / Icon
                thumbnailView

                // Content
                VStack(alignment: .leading, spacing: 8) {
                    // File name and date
                    HStack {
                        Text(item.fileName)
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Spacer()

                        Text(item.formattedDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Compression progress bar
                    compressionProgressBar

                    // Size info
                    sizeInfoRow
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.1)) {
                animateProgress = true
            }
        }
    }

    // MARK: - Thumbnail

    private var thumbnailView: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 12)
                .fill(categoryColor.opacity(0.15))
                .frame(width: 56, height: 56)

            // Icon
            Image(systemName: item.fileType.icon)
                .font(.title2)
                .foregroundColor(categoryColor)

            // Success badge
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                        .background(Circle().fill(.white).padding(-2))
                }
            }
            .frame(width: 56, height: 56)
        }
    }

    private var categoryColor: Color {
        switch item.fileType {
        case .pdf: return .red
        case .image: return .green
        case .video: return .purple
        case .document: return .blue
        case .other: return .gray
        }
    }

    // MARK: - Compression Progress Bar

    private var compressionProgressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background (original size)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)

                // Compressed portion (green)
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [.green, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: animateProgress
                            ? geometry.size.width * (1 - item.savedPercentage)
                            : geometry.size.width,
                        height: 8
                    )

                // Saved portion (striped pattern)
                if animateProgress {
                    HStack(spacing: 0) {
                        Spacer()
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.green.opacity(0.3), .green.opacity(0.1)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * item.savedPercentage, height: 8)
                            .overlay(
                                StripedPattern()
                                    .foregroundColor(.green.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            )
                    }
                }
            }
        }
        .frame(height: 8)
    }

    // MARK: - Size Info Row

    private var sizeInfoRow: some View {
        HStack(spacing: 4) {
            // Original size
            Text(item.formattedOriginalSize)
                .font(.caption)
                .foregroundColor(.secondary)

            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundColor(.secondary)

            // Compressed size (bold, green)
            Text(item.formattedCompressedSize)
                .font(.caption.bold())
                .foregroundColor(.green)

            Spacer()

            // Savings badge
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)

                Text("-\(Int(item.savedPercentage * 100))%")
                    .font(.caption.bold())
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.15))
            .clipShape(Capsule())
        }
    }
}

// MARK: - Striped Pattern

struct StripedPattern: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let stripeWidth: CGFloat = 4
                let spacing: CGFloat = 4

                var x: CGFloat = -geometry.size.height

                while x < geometry.size.width + geometry.size.height {
                    path.move(to: CGPoint(x: x, y: geometry.size.height))
                    path.addLine(to: CGPoint(x: x + geometry.size.height, y: 0))
                    path.addLine(to: CGPoint(x: x + geometry.size.height + stripeWidth, y: 0))
                    path.addLine(to: CGPoint(x: x + stripeWidth, y: geometry.size.height))
                    path.closeSubpath()

                    x += stripeWidth + spacing
                }
            }
            .fill()
        }
    }
}

// MARK: - History List Header

struct HistoryListHeader: View {
    let totalSaved: Int64
    let fileCount: Int

    var body: some View {
        VStack(spacing: 16) {
            // Total savings card
            HStack(spacing: 20) {
                // Total saved
                VStack(alignment: .leading, spacing: 4) {
                    Text("Toplam Tasarruf")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(ByteCountFormatter.string(fromByteCount: totalSaved, countStyle: .file))
                        .font(.title.bold())
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }

                Spacer()

                // File count
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Dosya")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(fileCount)")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [.green.opacity(0.3), .cyan.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )

            // Motivational message
            Text(motivationalText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var motivationalText: String {
        let photos = Int(totalSaved / (3 * 1024 * 1024))

        if photos >= 100 {
            return "🎉 Muhteşem! \(photos) fotoğraflık alan kazandın."
        } else if photos >= 10 {
            return "📸 Harika! \(photos) fotoğraf daha çekebilirsin."
        } else if fileCount > 0 {
            return "✨ Her sıkıştırma bir adım daha fazla alan demek!"
        } else {
            return "İlk dosyanı sıkıştırarak başla!"
        }
    }
}

// MARK: - Compact History Row

struct CompactHistoryRow: View {
    let item: HistoryItem

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: item.fileType.icon)
                .font(.body)
                .foregroundColor(categoryColor)
                .frame(width: 32)

            // Name
            Text(item.fileName)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()

            // Savings
            Text("-\(Int(item.savedPercentage * 100))%")
                .font(.caption.bold())
                .foregroundColor(.green)
        }
        .padding(.vertical, 8)
    }

    private var categoryColor: Color {
        switch item.fileType {
        case .pdf: return .red
        case .image: return .green
        case .video: return .purple
        case .document: return .blue
        case .other: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        HistoryListHeader(totalSaved: 150_000_000, fileCount: 42)

        HistoryCard(
            item: HistoryItem(
                id: UUID(),
                fileName: "presentation.pdf",
                originalSize: 15_000_000,
                compressedSize: 3_500_000,
                compressionDate: Date().addingTimeInterval(-3600),
                fileType: .pdf,
                thumbnailURL: nil
            ),
            onTap: {}
        )

        HistoryCard(
            item: HistoryItem(
                id: UUID(),
                fileName: "vacation_photo.jpg",
                originalSize: 8_000_000,
                compressedSize: 2_000_000,
                compressionDate: Date().addingTimeInterval(-86400),
                fileType: .image,
                thumbnailURL: nil
            ),
            onTap: {}
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
