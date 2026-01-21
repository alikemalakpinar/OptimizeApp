//
//  FileCard.swift
//  optimize
//
//  File information card with type-specific visual treatments
//
//  DESIGN SYSTEM:
//  - PDF: Document icon, blue-purple accent (professional)
//  - Image: Photo stack, mint-teal accent (creative)
//  - Video: Film strip, orange-coral accent (dynamic)
//  - Each type has distinct icon container shape and color scheme
//

import SwiftUI

struct FileCard: View {
    let name: String
    let sizeText: String
    let typeIcon: String
    var subtitle: String? = nil
    var fileType: FileType = .pdf
    var onReplace: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    // Type-specific colors
    private var accentColor: Color {
        switch fileType {
        case .pdf, .document: return .premiumBlue
        case .image: return .appMint
        case .video: return .warmOrange
        case .unknown: return .appAccent
        }
    }

    private var gradientColors: [Color] {
        switch fileType {
        case .pdf, .document: return [.premiumPurple, .premiumBlue]
        case .image: return [.appMint, .appTeal]
        case .video: return [.warmOrange, .warmCoral]
        case .unknown: return [.appAccent, .appAccent.opacity(0.7)]
        }
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Type-specific icon container
            fileTypeIcon

            // File info
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(name)
                    .font(.appBodyMedium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: Spacing.xs) {
                    // File type badge
                    FileTypeBadge(type: fileType)

                    Text(sizeText)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)

                    if let subtitle = subtitle {
                        Text("•")
                            .font(.appCaption)
                            .foregroundStyle(.tertiary)

                        Text(subtitle)
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Replace button if provided
            if let onReplace = onReplace {
                Button(action: {
                    Haptics.selection()
                    onReplace()
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : .white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [gradientColors[0].opacity(0.3), gradientColors[1].opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Type-Specific Icon

    @ViewBuilder
    private var fileTypeIcon: some View {
        switch fileType {
        case .pdf, .document:
            // PDF: Rounded rectangle with document icon
            ZStack {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.premiumPurple.opacity(0.15), Color.premiumBlue.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                Image(systemName: "doc.text.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.premiumPurple, Color.premiumBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

        case .image:
            // Image: Circle with photo stack icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.appMint.opacity(0.2), Color.appTeal.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.appMint, Color.appTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

        case .video:
            // Video: Squircle with film icon and play indicator
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.warmOrange.opacity(0.2), Color.warmCoral.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                ZStack {
                    Image(systemName: "film.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.warmOrange, Color.warmCoral],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Small play indicator
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 6, weight: .bold))
                                .foregroundStyle(Color.warmOrange)
                        )
                        .offset(x: 14, y: 14)
                }
            }

        case .unknown:
            // Generic file icon
            ZStack {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(Color.appAccent.opacity(0.1))
                    .frame(width: 56, height: 56)

                Image(systemName: typeIcon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Color.appAccent)
            }
        }
    }
}

// MARK: - File Type Badge

/// Small badge showing file type
struct FileTypeBadge: View {
    let type: FileType

    private var label: String {
        switch type {
        case .pdf: return "PDF"
        case .image: return "IMG"
        case .video: return "VID"
        case .document: return "DOC"
        case .unknown: return "FILE"
        }
    }

    private var color: Color {
        switch type {
        case .pdf, .document: return .premiumBlue
        case .image: return .appMint
        case .video: return .warmOrange
        case .unknown: return .secondary
        }
    }

    var body: some View {
        Text(label)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - File Type Helper
enum FileType {
    case pdf
    case image
    case video
    case document
    case unknown

    var icon: String {
        switch self {
        case .pdf: return "doc.fill"
        case .image: return "photo.fill"
        case .video: return "film.fill"
        case .document: return "doc.text.fill"
        case .unknown: return "doc.fill"
        }
    }

    static func from(extension ext: String) -> FileType {
        switch ext.lowercased() {
        case "pdf": return .pdf
        case "jpg", "jpeg", "png", "heic", "gif", "webp": return .image
        case "mp4", "mov", "avi", "mkv": return .video
        case "doc", "docx", "txt", "rtf": return .document
        default: return .unknown
        }
    }
}

#Preview("All File Types") {
    VStack(spacing: Spacing.md) {
        FileCard(
            name: "Rapor_2024.pdf",
            sizeText: "300 MB",
            typeIcon: FileType.pdf.icon,
            subtitle: "84 sayfa",
            fileType: .pdf
        )

        FileCard(
            name: "Vacation_Photo.heic",
            sizeText: "12 MB",
            typeIcon: FileType.image.icon,
            subtitle: "4032×3024",
            fileType: .image
        )

        FileCard(
            name: "Interview_Final.mp4",
            sizeText: "1.2 GB",
            typeIcon: FileType.video.icon,
            subtitle: "15:32",
            fileType: .video,
            onReplace: {}
        )

        FileCard(
            name: "Unknown_File.xyz",
            sizeText: "500 KB",
            typeIcon: FileType.unknown.icon,
            fileType: .unknown
        )
    }
    .padding()
}
