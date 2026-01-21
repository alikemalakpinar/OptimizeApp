//
//  PermissionRecoveryHelper.swift
//  optimize
//
//  Graceful handling of denied permissions with Settings redirect flow.
//  Prevents users from thinking the app is broken when they deny permissions.
//
//  CRITICAL UX FIX:
//  Without this, users who deny permissions see no feedback and think
//  the app is broken. They leave 1-star reviews saying "doesn't work".
//
//  FLOW:
//  1. User denies permission
//  2. Show friendly alert explaining why permission is needed
//  3. Offer "Open Settings" button to grant permission
//  4. Optionally offer alternative action (e.g., "Save to Files" instead of "Save to Photos")
//

import SwiftUI
import Photos
import AVFoundation

// MARK: - Permission Type

enum PermissionType: Identifiable {
    case photoLibrary
    case photoLibraryAddOnly
    case camera
    case microphone

    var id: String {
        switch self {
        case .photoLibrary: return "photoLibrary"
        case .photoLibraryAddOnly: return "photoLibraryAddOnly"
        case .camera: return "camera"
        case .microphone: return "microphone"
        }
    }

    var title: String {
        switch self {
        case .photoLibrary:
            return String(localized: "Fotoğraf Erişimi Gerekli")
        case .photoLibraryAddOnly:
            return String(localized: "Galeriye Kaydetme İzni Gerekli")
        case .camera:
            return String(localized: "Kamera Erişimi Gerekli")
        case .microphone:
            return String(localized: "Mikrofon Erişimi Gerekli")
        }
    }

    var message: String {
        switch self {
        case .photoLibrary:
            return String(localized: "Fotoğraflarınızı optimize etmek için fotoğraf kütüphanenize erişim gerekiyor. Lütfen Ayarlar'dan izin verin.")
        case .photoLibraryAddOnly:
            return String(localized: "Sıkıştırılmış dosyayı galerinize kaydetmek için izin gerekiyor. Lütfen Ayarlar'dan izin verin.")
        case .camera:
            return String(localized: "Doğrudan fotoğraf çekip sıkıştırmak için kamera erişimi gerekiyor. Lütfen Ayarlar'dan izin verin.")
        case .microphone:
            return String(localized: "Video sıkıştırma sırasında ses işlemek için mikrofon erişimi gerekli olabilir. Lütfen Ayarlar'dan izin verin.")
        }
    }

    var icon: String {
        switch self {
        case .photoLibrary, .photoLibraryAddOnly:
            return "photo.on.rectangle"
        case .camera:
            return "camera"
        case .microphone:
            return "mic"
        }
    }
}

// MARK: - Permission Status

enum PermissionStatus {
    case notDetermined
    case authorized
    case limited
    case denied
    case restricted

    var canProceed: Bool {
        switch self {
        case .authorized, .limited:
            return true
        case .notDetermined, .denied, .restricted:
            return false
        }
    }
}

// MARK: - Permission Recovery Helper

@MainActor
final class PermissionRecoveryHelper: ObservableObject {

    // MARK: - Singleton

    static let shared = PermissionRecoveryHelper()

    // MARK: - Published State

    @Published var showingPermissionAlert = false
    @Published var currentPermissionType: PermissionType?
    @Published var alternativeActionTitle: String?
    @Published var alternativeAction: (() -> Void)?

    // MARK: - Permission Checks

    /// Check Photo Library access status
    static func checkPhotoLibraryStatus() -> PermissionStatus {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .limited: return .limited
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }

    /// Check Photo Library Add Only status
    static func checkPhotoLibraryAddOnlyStatus() -> PermissionStatus {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .limited: return .limited
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }

    /// Check Camera access status
    static func checkCameraStatus() -> PermissionStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }

    // MARK: - Request Permissions

    /// Request Photo Library access
    static func requestPhotoLibraryAccess() async -> PermissionStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .limited: return .limited
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }

    /// Request Photo Library Add Only access
    static func requestPhotoLibraryAddOnlyAccess() async -> PermissionStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .limited: return .limited
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }

    /// Request Camera access
    static func requestCameraAccess() async -> PermissionStatus {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        return granted ? .authorized : .denied
    }

    // MARK: - Recovery Flow

    /// Show permission recovery alert with optional alternative action
    func showRecoveryAlert(
        for permissionType: PermissionType,
        alternativeTitle: String? = nil,
        alternativeAction: (() -> Void)? = nil
    ) {
        self.currentPermissionType = permissionType
        self.alternativeActionTitle = alternativeTitle
        self.alternativeAction = alternativeAction
        self.showingPermissionAlert = true
    }

    /// Open app settings
    func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }

    /// Dismiss alert and perform alternative action
    func performAlternativeAction() {
        showingPermissionAlert = false
        alternativeAction?()
    }

    /// Dismiss alert
    func dismissAlert() {
        showingPermissionAlert = false
        currentPermissionType = nil
        alternativeActionTitle = nil
        alternativeAction = nil
    }
}

// MARK: - SwiftUI Permission Alert View

struct PermissionRecoveryAlert: ViewModifier {
    @ObservedObject var helper = PermissionRecoveryHelper.shared

    func body(content: Content) -> some View {
        content
            .alert(
                helper.currentPermissionType?.title ?? "",
                isPresented: $helper.showingPermissionAlert,
                presenting: helper.currentPermissionType
            ) { permissionType in
                Button(String(localized: "Ayarlar'ı Aç")) {
                    helper.openSettings()
                    helper.dismissAlert()
                }

                if let alternativeTitle = helper.alternativeActionTitle {
                    Button(alternativeTitle) {
                        helper.performAlternativeAction()
                    }
                }

                Button(String(localized: "İptal"), role: .cancel) {
                    helper.dismissAlert()
                }
            } message: { permissionType in
                Text(permissionType.message)
            }
    }
}

// MARK: - View Extension

extension View {
    /// Add permission recovery alert handling to any view
    func withPermissionRecoveryAlert() -> some View {
        modifier(PermissionRecoveryAlert())
    }
}

// MARK: - Convenience Methods for Common Flows

extension PermissionRecoveryHelper {

    /// Handle "Save to Gallery" flow with recovery
    func saveToGallery(
        fileURL: URL,
        isVideo: Bool,
        onSuccess: @escaping () -> Void,
        onAlternative: (() -> Void)? = nil
    ) async {
        // Check current permission
        let status = Self.checkPhotoLibraryAddOnlyStatus()

        switch status {
        case .notDetermined:
            // Request permission
            let newStatus = await Self.requestPhotoLibraryAddOnlyAccess()
            if newStatus.canProceed {
                await performSave(fileURL: fileURL, isVideo: isVideo, onSuccess: onSuccess)
            } else {
                showRecoveryAlert(
                    for: .photoLibraryAddOnly,
                    alternativeTitle: onAlternative != nil ? String(localized: "Dosyalara Kaydet") : nil,
                    alternativeAction: onAlternative
                )
            }

        case .authorized, .limited:
            await performSave(fileURL: fileURL, isVideo: isVideo, onSuccess: onSuccess)

        case .denied, .restricted:
            showRecoveryAlert(
                for: .photoLibraryAddOnly,
                alternativeTitle: onAlternative != nil ? String(localized: "Dosyalara Kaydet") : nil,
                alternativeAction: onAlternative
            )
        }
    }

    private func performSave(fileURL: URL, isVideo: Bool, onSuccess: @escaping () -> Void) async {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                if isVideo {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
                } else {
                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: fileURL)
                }
            }
            await MainActor.run {
                onSuccess()
            }
        } catch {
            #if DEBUG
            print("❌ [PermissionRecovery] Save failed: \(error)")
            #endif
        }
    }
}
