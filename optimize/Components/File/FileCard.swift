//
//  FileCard.swift
//  optimize
//
//  File information card with type icon, name, size
//

import SwiftUI

struct FileCard: View {
    let name: String
    let sizeText: String
    let typeIcon: String
    var subtitle: String? = nil
    var onReplace: (() -> Void)? = nil

    var body: some View {
        GlassCard {
            HStack(spacing: Spacing.md) {
                // File type icon
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(Color.appAccent.opacity(0.1))
                        .frame(width: 56, height: 56)

                    Image(systemName: typeIcon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Color.appAccent)
                }

                // File info
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(name)
                        .font(.appBodyMedium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: Spacing.xs) {
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
        }
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

#Preview {
    VStack(spacing: Spacing.md) {
        FileCard(
            name: "Rapor_2024.pdf",
            sizeText: "300 MB",
            typeIcon: FileType.pdf.icon,
            subtitle: "84 sayfa"
        )

        FileCard(
            name: "Sunucu_Dosyasi.pdf",
            sizeText: "150 MB",
            typeIcon: FileType.pdf.icon,
            subtitle: "42 sayfa",
            onReplace: {}
        )
    }
    .padding()
}
