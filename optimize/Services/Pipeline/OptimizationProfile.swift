//
//  OptimizationProfile.swift
//  optimize
//
//  Intelligent optimization profile that determines how the compression engine behaves.
//  This is the "brain" that makes smart decisions based on user intent.
//
//  ARCHITECTURE:
//  - Quick: Speed over size (metadata strip, basic compression)
//  - Balanced: Best of both worlds (smart format selection, moderate compression)
//  - Ultra: Maximum savings (full rebuild, aggressive compression)
//

import Foundation

// MARK: - Optimization Strategy

enum OptimizationStrategy: String, CaseIterable, Identifiable, Codable {
    case quick = "Speed"
    case balanced = "Balanced"
    case ultra = "Max Saver"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .quick: return String(localized: "Hızlı")
        case .balanced: return String(localized: "Dengeli")
        case .ultra: return String(localized: "Maksimum Tasarruf")
        }
    }

    var localizedDescription: String {
        switch self {
        case .quick:
            return String(localized: "En hızlı işlem, temel optimizasyon")
        case .balanced:
            return String(localized: "Hız ve boyut arasında ideal denge")
        case .ultra:
            return String(localized: "Maksimum küçültme, tam yeniden inşa")
        }
    }

    var icon: String {
        switch self {
        case .quick: return "hare.fill"
        case .balanced: return "scale.3d"
        case .ultra: return "arrow.down.to.line.compact"
        }
    }

    var estimatedSavings: String {
        switch self {
        case .quick: return "20-40%"
        case .balanced: return "40-60%"
        case .ultra: return "60-90%"
        }
    }
}

// MARK: - PDF Rebuild Mode

enum PDFRebuildMode: String, CaseIterable, Codable {
    case safe = "safe"      // Only clean unnecessary objects
    case smart = "smart"    // Rebuild if incremental updates detected
    case ultra = "ultra"    // Rasterize everything and rebuild (smallest size)

    var description: String {
        switch self {
        case .safe:
            return "Güvenli: Sadece gereksiz objeleri temizle"
        case .smart:
            return "Akıllı: Incremental update varsa yeniden inşa et"
        case .ultra:
            return "Ultra: Her şeyi rasterize et (En küçük boyut)"
        }
    }
}

// MARK: - Image Format Preference

enum ImageFormatPreference: String, CaseIterable, Codable {
    case auto = "auto"      // Let the engine decide
    case heic = "heic"      // Prefer HEIC for maximum savings
    case jpeg = "jpeg"      // Compatibility mode
    case webp = "webp"      // Web optimization

    var fileExtension: String {
        switch self {
        case .auto, .heic: return "heic"
        case .jpeg: return "jpg"
        case .webp: return "webp"
        }
    }
}

// MARK: - Optimization Profile

struct OptimizationProfile: Codable, Equatable {

    // MARK: - Core Settings

    let strategy: OptimizationStrategy

    // MARK: - Privacy & Web Safety

    /// Strip all metadata (EXIF, GPS, MakerNotes, etc.)
    var stripMetadata: Bool = true

    /// Convert Display P3 to sRGB for web compatibility and size savings
    var convertToSRGB: Bool = true

    /// Remove embedded color profiles
    var removeColorProfiles: Bool = false

    // MARK: - Format Intelligence

    /// Prefer HEIC format for iOS devices (~50% savings over JPEG)
    var preferHEIC: Bool = true

    /// Detect photo-like PNGs and convert them to JPEG/HEIC
    var smartPNGDetection: Bool = true

    /// Preferred image format
    var imageFormat: ImageFormatPreference = .auto

    // MARK: - Quality Settings

    /// JPEG/HEIC quality (0.0 - 1.0)
    var imageQuality: CGFloat {
        switch strategy {
        case .quick: return 0.85
        case .balanced: return 0.75
        case .ultra: return 0.60
        }
    }

    /// DPI for PDF rasterization
    var targetDPI: Int {
        switch strategy {
        case .quick: return 200
        case .balanced: return 150
        case .ultra: return 120
        }
    }

    // MARK: - PDF Specific

    /// PDF rebuild mode
    var pdfRebuildMode: PDFRebuildMode = .smart

    /// Flatten PDF layers
    var flattenPDFLayers: Bool = false

    /// Remove PDF annotations
    var removePDFAnnotations: Bool = false

    /// Linearize PDF for web (fast web view)
    var linearizePDF: Bool = true

    // MARK: - Video Specific (for VideoCompressionService)

    /// Target video resolution
    var videoResolution: VideoResolution {
        switch strategy {
        case .quick: return .hd1080p
        case .balanced: return .hd720p
        case .ultra: return .sd480p
        }
    }

    /// Video bitrate multiplier (1.0 = default, 0.5 = half)
    var videoBitrateMultiplier: Double {
        switch strategy {
        case .quick: return 0.8
        case .balanced: return 0.6
        case .ultra: return 0.4
        }
    }

    // MARK: - Presets

    static let quick = OptimizationProfile(
        strategy: .quick,
        stripMetadata: true,
        convertToSRGB: false,
        preferHEIC: true,
        pdfRebuildMode: .safe
    )

    static let balanced = OptimizationProfile(
        strategy: .balanced,
        stripMetadata: true,
        convertToSRGB: true,
        preferHEIC: true,
        pdfRebuildMode: .smart
    )

    static let ultra = OptimizationProfile(
        strategy: .ultra,
        stripMetadata: true,
        convertToSRGB: true,
        removeColorProfiles: true,
        preferHEIC: true,
        smartPNGDetection: true,
        pdfRebuildMode: .ultra,
        flattenPDFLayers: true
    )

    // MARK: - Factory Methods

    static func from(preset: CompressionPreset) -> OptimizationProfile {
        switch preset.quality {
        case .low:
            return .ultra
        case .medium:
            return .balanced
        case .high:
            return .quick
        case .custom:
            return .balanced
        }
    }
}

// MARK: - Video Resolution

enum VideoResolution: String, CaseIterable, Codable {
    case sd480p = "480p"
    case hd720p = "720p"
    case hd1080p = "1080p"
    case uhd4k = "4K"

    var dimensions: CGSize {
        switch self {
        case .sd480p: return CGSize(width: 854, height: 480)
        case .hd720p: return CGSize(width: 1280, height: 720)
        case .hd1080p: return CGSize(width: 1920, height: 1080)
        case .uhd4k: return CGSize(width: 3840, height: 2160)
        }
    }

    var avPresetName: String {
        switch self {
        case .sd480p: return "AVAssetExportPreset640x480"
        case .hd720p: return "AVAssetExportPreset1280x720"
        case .hd1080p: return "AVAssetExportPreset1920x1080"
        case .uhd4k: return "AVAssetExportPreset3840x2160"
        }
    }
}

// MARK: - Profile Builder

extension OptimizationProfile {

    /// Create a custom profile with specific settings
    static func custom(
        strategy: OptimizationStrategy = .balanced,
        stripMetadata: Bool = true,
        convertToSRGB: Bool = true,
        preferHEIC: Bool = true,
        pdfRebuildMode: PDFRebuildMode = .smart
    ) -> OptimizationProfile {
        OptimizationProfile(
            strategy: strategy,
            stripMetadata: stripMetadata,
            convertToSRGB: convertToSRGB,
            preferHEIC: preferHEIC,
            pdfRebuildMode: pdfRebuildMode
        )
    }
}
