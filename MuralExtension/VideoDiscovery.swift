import Foundation

/// Resolve a video URL for a specific choice. Each rendering context owns
/// its own choice — never read the process-wide "current" selection here,
/// or concurrent acquires for different displays will race and a renderer
/// can end up initialized with the wrong monitor's video.
///
/// Falls back to the first video in the library, then bundle resources, so
/// the picker fallback path still has something to display.
func findVideoURL(forChoice videoID: String?) -> URL? {
    if let videoID,
       let url = VideoLibrary.shared.videoURL(for: videoID),
       FileManager.default.fileExists(atPath: url.path) {
        return url
    }

    if let first = VideoLibrary.shared.entries.first {
        let url = VideoLibrary.shared.videoURL(for: first)
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }
    }

    let videoExtensions = ["mp4", "mov", "m4v"]
    for ext in videoExtensions {
        if let url = Bundle.main.url(forResource: "wallpaper", withExtension: ext) {
            return url
        }
    }

    return nil
}

/// Compatibility wrapper for callers without a per-context choice (snapshot
/// requests that don't carry a wallpaperID, etc.). Uses the last user-picked
/// video as a best-effort hint — do not use this on the rendering path.
func findVideoURL() -> URL? {
    findVideoURL(forChoice: WallpaperState.shared.currentVideoID)
}
