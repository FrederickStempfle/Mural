import AppKit
import SwiftUI

@MainActor
enum WallpaperRenderer {
    static func render(_ preset: WallpaperPreset, to destination: URL) throws {
        let size = CGSize(width: 2880, height: 1800)
        let renderer = ImageRenderer(content: WallpaperArtwork(preset: preset).frame(width: size.width, height: size.height))
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = 1

        guard let image = renderer.nsImage,
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw WallpaperError.renderFailed
        }

        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try pngData.write(to: destination, options: .atomic)
    }
}
