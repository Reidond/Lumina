//
//  MediaSaver.swift
//  Lumina
//
//  Saves a downloaded file from the App Group container to Photos (visual media) or to a
//  user-chosen location in Files (via .fileExporter at the call site on iOS, or NSSavePanel
//  on macOS).
//

import Foundation
import Photos
import LuminaKit
#if canImport(AppKit)
import AppKit
#endif

enum MediaSaver {
    enum SaveError: LocalizedError {
        case photosPermissionDenied
        case unsupportedForPhotos
        case fileMissing

        var errorDescription: String? {
            switch self {
            case .photosPermissionDenied: String(localized: "Lumina needs permission to add to Photos.")
            case .unsupportedForPhotos: String(localized: "This media type can’t be saved to Photos.")
            case .fileMissing: String(localized: "The downloaded file is no longer available.")
            }
        }
    }

    /// Save a video/image/gif to the Photos library (add-only).
    static func saveToPhotos(fileURL: URL, mediaKind: MediaKind) async throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { throw SaveError.fileMissing }
        let assetType: PHAssetResourceType
        switch mediaKind {
        case .video: assetType = .video
        case .image, .gif: assetType = .photo
        case .audio, .unknown: throw SaveError.unsupportedForPhotos
        }

        let status = await requestAddOnlyAuthorization()
        guard status == .authorized || status == .limited else { throw SaveError.photosPermissionDenied }

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = false
            request.addResource(with: assetType, fileURL: fileURL, options: options)
        }
    }

    private static func requestAddOnlyAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { continuation.resume(returning: $0) }
        }
    }

    #if canImport(AppKit)
    /// macOS: copy the file to a user-chosen destination via NSSavePanel.
    @MainActor
    static func exportToFilesMac(fileURL: URL, suggestedName: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        try? FileManager.default.removeItem(at: destination)
        try? FileManager.default.copyItem(at: fileURL, to: destination)
    }
    #endif
}
