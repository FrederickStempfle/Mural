import CoreGraphics
import Foundation

/// A single video in the library, as persisted to `metadata.json`.
///
/// This is the wire format between the app and the extension: the app writes it
/// when deploying a video, the extension reads it when scanning. Both processes
/// must agree byte-for-byte, which is why the type lives here rather than being
/// declared on each side.
public struct VideoEntry: Codable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var filename: String
    public var duration: Double
    public var fps: Double
    public var resolution: CGSize
    public var dateAdded: Date
    public var variants: [VideoVariant]?

    public init(
        id: String,
        name: String,
        filename: String,
        duration: Double,
        fps: Double,
        resolution: CGSize,
        dateAdded: Date,
        variants: [VideoVariant]? = nil
    ) {
        self.id = id
        self.name = name
        self.filename = filename
        self.duration = duration
        self.fps = fps
        self.resolution = resolution
        self.dateAdded = dateAdded
        self.variants = variants
    }
}

/// A transcoded rendition of a `VideoEntry`, used to drop frame rate under a
/// restrictive `PlaybackPolicy` without re-encoding on the fly.
public struct VideoVariant: Codable, Equatable, Sendable {
    public let filename: String
    public let fps: Int
    public let resolution: CGSize

    public init(filename: String, fps: Int, resolution: CGSize) {
        self.filename = filename
        self.fps = fps
        self.resolution = resolution
    }
}
