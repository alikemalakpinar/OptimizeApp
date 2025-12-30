//
//  ResultScreen.swift
//  optimize
//
//  Compression result screen with before/after comparison
//

import SwiftUI

struct ResultScreen: View {
    let result: CompressionResult

    let onShare: () -> Void
    let onSave: () -> Void
    let onNewFile: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Success header
                    SuccessHeader(title: "Hazır!")
                        .padding(.top, Spacing.xl)

                    // Result numbers
                    ResultNumbers(
                        fromSizeMB: result.originalFile.sizeMB,
                        toSizeMB: result.compressedSizeMB,
                        percentSaved: result.savingsPercent
                    )

                    // Output file info
                    OutputFileInfo(
                        fileName: compressedFileName
                    )
                    .padding(.horizontal, Spacing.md)

                    // Privacy reminder
                    PrivacyBadge()
                        .padding(.horizontal, Spacing.md)

                    Spacer(minLength: Spacing.xl)
                }
            }

            // Action buttons
            VStack(spacing: Spacing.sm) {
                PrimaryButton(title: "Paylaş", icon: "square.and.arrow.up") {
                    Haptics.impact()
                    onShare()
                }

                SecondaryButton(title: "Dosyalara Kaydet", icon: "square.and.arrow.down") {
                    onSave()
                }

                TextButton(title: "Yeni dosya seç", icon: "arrow.counterclockwise") {
                    onNewFile()
                }
                .padding(.top, Spacing.xs)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
            .background(Color.appBackground)
        }
        .appBackgroundLayered()
    }

    private var compressedFileName: String {
        let name = result.originalFile.name
        let ext = (name as NSString).pathExtension
        let baseName = (name as NSString).deletingPathExtension
        return "\(baseName)_optimized.\(ext)"
    }
}

#Preview {
    ResultScreen(
        result: CompressionResult(
            originalFile: FileInfo(
                name: "Rapor_2024.pdf",
                url: URL(fileURLWithPath: "/test.pdf"),
                size: 300_000_000,
                pageCount: 84,
                fileType: .pdf
            ),
            compressedURL: URL(fileURLWithPath: "/compressed.pdf"),
            compressedSize: 92_000_000
        ),
        onShare: {},
        onSave: {},
        onNewFile: {}
    )
}
