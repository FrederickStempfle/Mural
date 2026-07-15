import AppKit
import Foundation

enum WallpaperError: LocalizedError {
    case renderFailed
    case missingResource(String)
    case videoUnsupported
    case noDisplay

    var errorDescription: String? {
        switch self {
        case .renderFailed:
            "Mural couldn’t render this wallpaper."
        case .missingResource(let name):
            "The bundled wallpaper “\(name)” is missing."
        case .videoUnsupported:
            "Video wallpapers can’t be applied as a still desktop image."
        case .noDisplay:
            "Mural couldn’t find a connected display."
        }
    }
}

@MainActor
final class WallpaperService {
    private let workspace = NSWorkspace.shared
    private let fileManager = FileManager.default

    func apply(_ wallpaper: Wallpaper, to target: DisplayTarget) async throws {
        let url = try await resolvedURL(for: wallpaper)
        let screens: [NSScreen]

        switch target {
        case .all:
            screens = NSScreen.screens
        case .main:
            screens = NSScreen.main.map { [$0] } ?? []
        }

        guard !screens.isEmpty else { throw WallpaperError.noDisplay }

        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
            .allowClipping: true
        ]

        for screen in screens {
            try workspace.setDesktopImageURL(url, for: screen, options: options)
        }
    }

    private func resolvedURL(for wallpaper: Wallpaper) async throws -> URL {
        switch wallpaper.source {
        case .bundled(let url):
            return url
        case .imported(let url):
            return url
        case .video:
            // Videos go through NativeVideoWallpaperService; reaching this
            // path means a caller skipped that branch.
            throw WallpaperError.videoUnsupported
        case .procedural(let preset):
            let url = try applicationSupportDirectory()
                .appendingPathComponent("Rendered", isDirectory: true)
                .appendingPathComponent("\(preset.rawValue).png")
            if !fileManager.fileExists(atPath: url.path) {
                try await WallpaperRenderer.render(preset, to: url)
            }
            return url
        }
    }

    private func applicationSupportDirectory() throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appendingPathComponent("Mural", isDirectory: true)
    }
}
