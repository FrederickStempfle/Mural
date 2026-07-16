import Foundation

/// Identifiers that both the app and the extension have to agree on.
///
/// Deliberately narrow: only names that cross the process boundary belong here.
/// Identifiers used on one side only (the extension's own preference and state
/// notifications, queue labels, log subsystems) stay where they are used.
public enum MuralIdentifiers {
    /// Bundle ID of the wallpaper extension. The app writes this as the
    /// `Provider` of a desktop choice; macOS uses it to route to the extension.
    public static let extensionBundleID = "local.mural.wallpapers.extension"

    /// Darwin notification posted by the app after it adds or removes a video,
    /// and observed by the extension to re-scan the library.
    public static let libraryChangedNotification = "local.mural.wallpapers.libraryChanged"
}
