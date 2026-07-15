import AppKit
import AVFoundation
import Foundation

enum NativeVideoWallpaperError: LocalizedError {
    case noVideoTrack
    case thumbnailFailed
    case deployedCopyMissing
    case wallpaperStoreUnreadable

    var errorDescription: String? {
        switch self {
        case .noVideoTrack: "This file does not contain a video track macOS can decode."
        case .thumbnailFailed: "Mural could not create a preview for this video."
        case .deployedCopyMissing: "The deployed copy of this video is missing."
        case .wallpaperStoreUnreadable: "The macOS wallpaper store could not be read."
        }
    }
}

/// Deploys video files into the sandbox owned by Mural's WallpaperExtensionKit extension.
/// WallpaperAgent hosts that extension and drives it on the Desktop and Lock Screen.
enum NativeVideoWallpaperService {
    private struct Metadata: Codable {
        let id: String
        var name: String
        var filename: String
        var duration: Double
        var fps: Double
        var resolution: CGSize
        var dateAdded: Date
        var variants: [VideoVariant]?
    }

    private struct VideoVariant: Codable {
        let filename: String
        let fps: Int
        let resolution: CGSize
    }

    private static let notification = "local.mural.wallpapers.libraryChanged"

    private static var documentsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/local.mural.wallpapers.extension/Data/Documents")
    }

    private static var videosURL: URL {
        documentsURL.appendingPathComponent("videos", isDirectory: true)
    }

    static func deploy(_ sourceURL: URL) async throws -> String {
        if let existing = existingMetadata(filename: sourceURL.lastPathComponent) {
            return existing.id
        }

        let asset = AVURLAsset(url: sourceURL)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw NativeVideoWallpaperError.noVideoTrack
        }

        let id = UUID().uuidString
        let directory = videosURL.appendingPathComponent(id, isDirectory: true)
        let destination = directory.appendingPathComponent(sourceURL.lastPathComponent)
        let fileManager = FileManager.default

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try fileManager.copyItem(at: sourceURL, to: destination)

            let frameRate = try await track.load(.nominalFrameRate)
            let naturalSize = try await track.load(.naturalSize)
            let duration = try await asset.load(.duration)

            let metadata = Metadata(
                id: id,
                name: sourceURL.deletingPathExtension().lastPathComponent,
                filename: destination.lastPathComponent,
                duration: CMTimeGetSeconds(duration),
                fps: Double(frameRate),
                resolution: naturalSize,
                dateAdded: Date(),
                variants: nil
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(metadata).write(
                to: directory.appendingPathComponent("metadata.json"),
                options: .atomic
            )
            try await generateThumbnail(for: destination, in: directory)
            notifyExtension()
            return id
        } catch {
            try? fileManager.removeItem(at: directory)
            throw error
        }
    }

    /// Removes a deployed copy only when macOS is no longer referencing its choice ID.
    /// WallpaperAgent may keep using a choice after the source disappears from Mural's
    /// library, so deleting an active copy would leave the Desktop with no video frames.
    @discardableResult
    static func removeIfUnused(filename: String) throws -> Bool {
        guard let metadata = existingMetadata(filename: filename) else { return true }
        guard !isReferencedByWallpaperStore(choiceID: metadata.id) else { return false }

        let directory = videosURL.appendingPathComponent(metadata.id, isDirectory: true)
        try FileManager.default.removeItem(at: directory)
        notifyExtension()
        return true
    }

    /// Activates a deployed video by rewriting every Desktop choice in the macOS
    /// wallpaper store to point at it, then restarting WallpaperAgent so the change
    /// takes effect immediately — the same result as picking it in System Settings.
    /// Async so the plist rewrite and the blocking agent restart stay off the main actor.
    static func activate(choiceID: String) async throws {
        let directory = videosURL.appendingPathComponent(choiceID, isDirectory: true)
        let metadataURL = directory.appendingPathComponent("metadata.json")
        guard let data = try? Data(contentsOf: metadataURL),
              let metadata = try? JSONDecoder().decode(Metadata.self, from: data) else {
            throw NativeVideoWallpaperError.deployedCopyMissing
        }
        let videoURL = directory.appendingPathComponent(metadata.filename)

        let storeURL = wallpaperStoreURL
        guard let storeData = try? Data(contentsOf: storeURL),
              var root = unsafe try? PropertyListSerialization.propertyList(from: storeData, format: nil) as? [String: Any] else {
            throw NativeVideoWallpaperError.wallpaperStoreUnreadable
        }

        root = rewritingDesktopChoices(in: root, choiceID: choiceID, videoURL: videoURL)

        let output = try PropertyListSerialization.data(fromPropertyList: root, format: .binary, options: 0)
        try output.write(to: storeURL, options: .atomic)
        try restartWallpaperAgent()
    }

    /// Replaces the content of every `Desktop` node with a choice provided by
    /// Mural's wallpaper extension. Idle (screen saver) nodes are left untouched.
    static func rewritingDesktopChoices(
        in node: [String: Any],
        choiceID: String,
        videoURL: URL
    ) -> [String: Any] {
        var result = node
        for (key, value) in node {
            guard var child = value as? [String: Any] else { continue }
            if key == "Desktop", child["Content"] is [String: Any] {
                child["Content"] = [
                    "Choices": [
                        [
                            "Configuration": Data(choiceID.utf8),
                            "Files": [["relative": videoURL.absoluteString]],
                            "Provider": extensionBundleID
                        ]
                    ],
                    "EncodedOptionValues": videoOptionValues,
                    "Shuffle": "$null"
                ] as [String: Any]
                child["LastSet"] = Date()
                child["LastUse"] = Date()
                result[key] = child
            } else {
                result[key] = rewritingDesktopChoices(in: child, choiceID: choiceID, videoURL: videoURL)
            }
        }
        return result
    }

    private static let extensionBundleID = "local.mural.wallpapers.extension"

    private static var wallpaperStoreURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.wallpaper/Store/Index.plist")
    }

    /// Default option values (crop placement, average color) as System Settings
    /// writes them for an extension-provided video choice.
    private static let videoOptionValues = Data(base64Encoded: """
    YnBsaXN0MDDRAQJWdmFsdWVz0gMEBRJVY29sb3JZcGxhY2VtZW500QMG0QcIUl8w0QMJ0goLDBFaY29tcG9uZW50c1pjb2xvclNwYWNlpA0O\
    DxAjP9BQUFBQUFAjP9paWlpaWlojP+VVVVVVVVUjP/AAAAAAAABPEENicGxpc3QwMF8QF2tDR0NvbG9yU3BhY2VHZW5lcmljUkdCCAAAAAAA\
    AAEBAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAi0RMUVnBpY2tlctEHFdEWF1JpZFRDcm9wCAsSFx0nKi0wMzhDTlNcZW53vcDHys3QAAAAAAAA\
    AQEAAAAAAAAAGAAAAAAAAAAAAAAAAAAAANU=
    """)!

    /// Throws when killall cannot launch: the store was rewritten but the agent
    /// keeps showing the old choice, so the caller must not report success.
    private static func restartWallpaperAgent() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["WallpaperAgent"]
        try process.run()
        process.waitUntilExit()
    }

    @MainActor
    static func openWallpaperSettings() {
        let deepLink = URL(string: "x-apple.systempreferences:com.apple.Wallpaper-Settings.extension")!
        if !NSWorkspace.shared.open(deepLink) {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
    }

    private static func existingMetadata(filename: String) -> Metadata? {
        let fileManager = FileManager.default
        guard let directories = try? fileManager.contentsOfDirectory(
            at: videosURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else { return nil }

        for directory in directories {
            let url = directory.appendingPathComponent("metadata.json")
            guard let data = try? Data(contentsOf: url),
                  let metadata = try? JSONDecoder().decode(Metadata.self, from: data) else { continue }
            if metadata.filename == filename { return metadata }
        }
        return nil
    }

    private static func isReferencedByWallpaperStore(choiceID: String) -> Bool {
        let indexURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.wallpaper/Store/Index.plist")

        // Fail closed: if macOS changes or temporarily locks its store, preserving a
        // small deployed copy is safer than breaking the user's active wallpaper.
        guard let index = try? Data(contentsOf: indexURL) else { return true }
        return wallpaperIndex(index, referencesChoiceID: choiceID)
    }

    static func wallpaperIndex(_ index: Data, referencesChoiceID choiceID: String) -> Bool {
        index.range(of: Data(choiceID.utf8)) != nil
    }

    private static func generateThumbnail(for videoURL: URL, in directory: URL) async throws {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: videoURL))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 960, height: 600)
        let image = try await generator.image(at: .zero).image
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.86]) else {
            throw NativeVideoWallpaperError.thumbnailFailed
        }
        try data.write(to: directory.appendingPathComponent("thumbnail.jpg"), options: .atomic)
    }

    private static func notifyExtension() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(notification as CFString),
            nil,
            nil,
            true
        )
    }
}
