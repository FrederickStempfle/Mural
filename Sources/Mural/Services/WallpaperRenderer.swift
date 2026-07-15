import AppKit
import SwiftUI

@MainActor
enum WallpaperRenderer {
    static func render(_ preset: WallpaperPreset, to destination: URL) async throws {
        try await render(StudioDesign(preset: preset), to: destination)
    }

    /// Snapshots the design on the main actor — SwiftUI's ImageRenderer requires
    /// it — then hands the PNG encode and file write to a detached task so the
    /// UI can keep painting while the heavy encoding runs.
    static func render(_ design: StudioDesign, to destination: URL) async throws {
        let size = CGSize(width: 2880, height: 1800)
        let renderer = ImageRenderer(content: StudioCanvas(design: design).frame(width: size.width, height: size.height))
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = 1

        guard let image = renderer.cgImage else {
            throw WallpaperError.renderFailed
        }

        try await Task.detached(priority: .userInitiated) {
            guard let pngData = NSBitmapImageRep(cgImage: image)
                .representation(using: .png, properties: [:]) else {
                throw WallpaperError.renderFailed
            }
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try pngData.write(to: destination, options: .atomic)
        }.value
    }
}
