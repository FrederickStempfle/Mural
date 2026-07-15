# Mural

Mural is a native macOS wallpaper library built with SwiftUI. It applies images through `NSWorkspace.setDesktopImageURL`, supports all displays or the main display, imports local images and videos into a persistent library, and includes favorites and recent history.

The starter library contains one original generated paper-collage wallpaper and five lightweight procedural wallpapers rendered locally at 2880×1800 when selected.

For videos on macOS 26, Mural embeds a native wallpaper extension backed by Apple's private `WallpaperExtensionKit`. WallpaperAgent hosts playback on the Desktop and Lock Screen, including when Mural is closed. Applying a video sets it automatically across all displays and Spaces: Mural rewrites the Desktop choices in the macOS wallpaper store (`com.apple.wallpaper/Store/Index.plist`) and restarts WallpaperAgent. If that rewrite ever fails, Mural falls back to opening the **Mural — Video Wallpapers** collection in System Settings for manual selection.

Removing a video from Mural keeps its deployed system copy whenever macOS still references that wallpaper, preventing an active Desktop or Lock Screen choice from losing its media file.

This private integration may break after a macOS update and is not suitable for Mac App Store distribution. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Run

The static Swift Package target requires macOS 14 or later. Native video wallpapers require macOS 26 and Xcode 26.

```sh
swift run Mural
```

## Build the complete app bundle

```sh
./scripts/build-app.sh
open dist/Mural.app
```

The build script creates an ad-hoc signed `dist/Mural.app` containing `MuralExtension.appex`. For distribution, replace ad-hoc signing with your Developer ID and notarization workflow.
