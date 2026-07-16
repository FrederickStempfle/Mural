import Foundation
import Testing
@testable import MuralKit

@Test func videoEntrySurvivesARoundTrip() throws {
    let entry = VideoEntry(
        id: "762DB689-BB25-435A-BB26-619F07F61A3F",
        name: "Loop",
        filename: "loop.mp4",
        duration: 12.5,
        fps: 60,
        resolution: CGSize(width: 3840, height: 2160),
        dateAdded: Date(timeIntervalSince1970: 1_700_000_000),
        variants: [VideoVariant(filename: "loop_30.mp4", fps: 30, resolution: CGSize(width: 1920, height: 1080))]
    )

    let data = try JSONEncoder().encode(entry)
    #expect(try JSONDecoder().decode(VideoEntry.self, from: data) == entry)
}

/// The app writes `metadata.json` and the extension reads it, so these key names
/// are a cross-process contract. Renaming a property is a breaking change to
/// every library already on disk — this pins the names so it fails here first.
@Test func metadataJSONKeysAreStable() throws {
    let entry = VideoEntry(
        id: "id",
        name: "name",
        filename: "file.mp4",
        duration: 1,
        fps: 30,
        resolution: .zero,
        dateAdded: Date(timeIntervalSince1970: 0),
        variants: [VideoVariant(filename: "v.mp4", fps: 30, resolution: .zero)]
    )

    let data = try JSONEncoder().encode(entry)
    let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

    #expect(Set(json.keys) == ["id", "name", "filename", "duration", "fps", "resolution", "dateAdded", "variants"])

    let variant = try #require((json["variants"] as? [[String: Any]])?.first)
    #expect(Set(variant.keys) == ["filename", "fps", "resolution"])
}

/// The app always writes `variants: nil`; the extension fills them in later.
/// Decoding must tolerate the key being absent entirely.
@Test func variantsAreOptionalOnDisk() throws {
    let json = """
    {"id":"a","name":"n","filename":"f.mp4","duration":1,"fps":30,\
    "resolution":[1920,1080],"dateAdded":0}
    """
    let entry = try JSONDecoder().decode(VideoEntry.self, from: Data(json.utf8))
    #expect(entry.variants == nil)
    #expect(entry.resolution == CGSize(width: 1920, height: 1080))
}
