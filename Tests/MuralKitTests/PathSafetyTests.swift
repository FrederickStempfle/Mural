import Foundation
import Testing
@testable import MuralKit

@Test func onlyUUIDsAreValidEntryIDs() {
    #expect(PathSafety.isValidEntryID(UUID().uuidString))
    #expect(PathSafety.isValidEntryID("762DB689-BB25-435A-BB26-619F07F61A3F"))

    #expect(!PathSafety.isValidEntryID(""))
    #expect(!PathSafety.isValidEntryID(".."))
    #expect(!PathSafety.isValidEntryID("../../etc"))
    #expect(!PathSafety.isValidEntryID("/etc/passwd"))
    #expect(!PathSafety.isValidEntryID("not-a-uuid"))
}

@Test func safeComponentsArePlainBasenames() {
    #expect(PathSafety.isSafeComponent("loop.mp4"))
    #expect(PathSafety.isSafeComponent("variant_30fps.mp4"))
    #expect(PathSafety.isSafeComponent("metadata.json"))
    #expect(PathSafety.isSafeComponent(".hidden"))
}

@Test func traversalAndControlCharactersAreRejected() {
    #expect(!PathSafety.isSafeComponent(""))
    #expect(!PathSafety.isSafeComponent("."))
    #expect(!PathSafety.isSafeComponent(".."))
    #expect(!PathSafety.isSafeComponent("../evil.mp4"))
    #expect(!PathSafety.isSafeComponent("dir/loop.mp4"))
    #expect(!PathSafety.isSafeComponent("/absolute.mp4"))
    #expect(!PathSafety.isSafeComponent("back\\slash.mp4"))
    #expect(!PathSafety.isSafeComponent("null\0byte.mp4"))
    #expect(!PathSafety.isSafeComponent("newline\nname.mp4"))
    // A trailing slash makes lastPathComponent disagree with the input.
    #expect(!PathSafety.isSafeComponent("trailing/"))
}

@Test func containmentAcceptsDescendantsAndTheBaseItself() {
    let base = URL(fileURLWithPath: "/tmp/mural/videos", isDirectory: true)

    #expect(PathSafety.contained(base, in: base))
    #expect(PathSafety.contained(base.appendingPathComponent("a.mp4"), in: base))
    #expect(PathSafety.contained(base.appendingPathComponent("id/a.mp4"), in: base))
}

@Test func containmentRejectsEscapesAndSiblingPrefixes() {
    let base = URL(fileURLWithPath: "/tmp/mural/videos", isDirectory: true)

    #expect(!PathSafety.contained(URL(fileURLWithPath: "/tmp/mural"), in: base))
    #expect(!PathSafety.contained(base.appendingPathComponent("../escaped.mp4"), in: base))
    #expect(!PathSafety.contained(URL(fileURLWithPath: "/etc/passwd"), in: base))
    // "videos-backup" must not pass just because it shares a string prefix.
    #expect(!PathSafety.contained(URL(fileURLWithPath: "/tmp/mural/videos-backup/a.mp4"), in: base))
}

@Test func containmentResolvesSymlinksRatherThanTrustingTheSpelling() throws {
    let fileManager = FileManager.default
    let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let base = root.appendingPathComponent("videos", isDirectory: true)
    let outside = root.appendingPathComponent("outside", isDirectory: true)
    defer { try? fileManager.removeItem(at: root) }

    try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: outside, withIntermediateDirectories: true)

    // A link that lives inside `base` but points out of it must not be contained.
    let link = base.appendingPathComponent("escape")
    try fileManager.createSymbolicLink(at: link, withDestinationURL: outside)

    #expect(!PathSafety.contained(link, in: base))
}
