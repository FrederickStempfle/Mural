import AppKit
import SwiftUI

/// The composed studio artwork: backdrop plus placed stickers. Both the live
/// preview and the full-resolution render draw this view, so what you see is
/// exactly what gets rendered.
struct StudioCanvas: View {
    let design: StudioDesign

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backdrop(size: geometry.size)
                ForEach(design.stickers) { placement in
                    StickerStamp(placement: placement, canvasSize: geometry.size)
                }
            }
        }
        .clipped()
    }

    @ViewBuilder
    private func backdrop(size: CGSize) -> some View {
        switch design.backdrop {
        case .style(let style):
            WallpaperArtwork(style: style, colors: design.colors, seed: design.seed)
        case .photo(let url):
            if let image = StickerLibrary.image(at: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                ZStack {
                    Color(nsColor: .quaternaryLabelColor)
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// One sticker drawn at its relative placement. Kept separate so StudioView
/// can wrap the identical geometry in gestures for the interactive preview.
struct StickerStamp: View {
    let placement: StickerPlacement
    let canvasSize: CGSize

    var body: some View {
        if let image = StickerLibrary.image(at: placement.url) {
            let width = canvasSize.width * placement.width
            let aspect = image.size.height / max(image.size.width, 1)
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: width, height: width * aspect)
                .rotationEffect(.degrees(placement.rotation))
                .position(
                    x: canvasSize.width * placement.centerX,
                    y: canvasSize.height * placement.centerY
                )
        }
    }
}

/// Loads and caches sticker and backdrop images by URL.
@MainActor
enum StickerLibrary {
    private static var cache: [URL: NSImage] = [:]

    static func image(at url: URL) -> NSImage? {
        if let cached = cache[url] { return cached }
        guard let image = NSImage(contentsOf: url) else { return nil }
        cache[url] = image
        return image
    }

    /// The bundled sticker catalog, ordered by filename.
    static let bundled: [URL] = ResourceLocator.stickerURLs()

    static func displayName(for url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "Sticker-", with: "")
            .replacingOccurrences(of: "-", with: " ")
    }
}
