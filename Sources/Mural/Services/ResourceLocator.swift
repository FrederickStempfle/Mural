import Foundation

enum ResourceLocator {
    static func url(forResource name: String, withExtension extensionName: String) -> URL? {
        for bundle in resourceBundles {
            if let url = bundle.url(forResource: name, withExtension: extensionName) {
                return url
            }
        }
        return nil
    }

    /// Image files in this directory are bundled with the app and shown in Mural Studio.
    static func preMadeWallpaperURLs() -> [URL] {
        let imageExtensions: Set<String> = ["avif", "heic", "heif", "jpeg", "jpg", "png", "tif", "tiff", "webp"]
        let nonWallpaperResources: Set<String> = [
            "AppIcon.icns", "LogoMark.png", "WordmarkDark.png", "WordmarkLight.png"
        ]

        let resources = resourceBundles.flatMap { bundle in
            // Swift Package Manager preserves the folder, while Xcode's synchronized
            // resource build phase flattens it in the shipped app. Check both layouts.
            (bundle.urls(forResourcesWithExtension: nil, subdirectory: "PreMadeWallpapers") ?? [])
                + (bundle.urls(forResourcesWithExtension: nil, subdirectory: nil) ?? [])
        }

        return Dictionary(grouping: resources, by: \.standardizedFileURL)
            .keys
            .filter { !nonWallpaperResources.contains($0.lastPathComponent) }
            .filter { !$0.lastPathComponent.hasPrefix("Sticker-") }
            .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// Bundled sticker assets for Mural Studio. Files are named "Sticker-*.png"
    /// so they stay identifiable when Xcode flattens resource folders.
    static func stickerURLs() -> [URL] {
        let resources = resourceBundles.flatMap { bundle in
            (bundle.urls(forResourcesWithExtension: "png", subdirectory: "Stickers") ?? [])
                + (bundle.urls(forResourcesWithExtension: "png", subdirectory: nil) ?? [])
        }

        return Dictionary(grouping: resources, by: \.standardizedFileURL)
            .keys
            .filter { $0.lastPathComponent.hasPrefix("Sticker-") }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    private static var resourceBundles: [Bundle] {
        var bundles = [Bundle.main]
#if SWIFT_PACKAGE
        bundles.append(Bundle.module)
#endif
        return bundles
    }
}
