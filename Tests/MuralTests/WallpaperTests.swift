import Foundation
import Testing
@testable import Mural

@Test func everyPresetHasFourColors() {
    for preset in WallpaperPreset.allCases {
        #expect(preset.colors.count == 4)
    }
}

@Test func filterNamesAreUnique() {
    #expect(Set(LibraryFilter.allCases.map(\.rawValue)).count == LibraryFilter.allCases.count)
}

@Test @MainActor func proceduralWallpaperRendersAsPNG() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let url = directory.appendingPathComponent("quiet-tide.png")
    defer { try? FileManager.default.removeItem(at: directory) }

    try WallpaperRenderer.render(.quietTide, to: url)

    let data = try Data(contentsOf: url)
    #expect(data.starts(with: [0x89, 0x50, 0x4e, 0x47]))
    #expect(data.count > 100_000)
}

@Test func curatedPalettesHaveFourColorsAndUniqueNames() {
    for palette in StudioPalette.curated {
        #expect(palette.colors.count == 4)
    }
    #expect(Set(StudioPalette.curated.map(\.name)).count == StudioPalette.curated.count)
}

@Test @MainActor func everyStudioStyleRendersAsPNG() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    for style in StudioStyle.allCases {
        let design = StudioDesign(backdrop: .style(style), colors: StudioPalette.curated[0].colors, seed: 0.5)
        let url = directory.appendingPathComponent("\(style.rawValue).png")
        try WallpaperRenderer.render(design, to: url)

        let data = try Data(contentsOf: url)
        #expect(data.starts(with: [0x89, 0x50, 0x4e, 0x47]))
        #expect(data.count > 100_000)
    }
}

@Test func rewritesEveryDesktopChoiceAndLeavesIdleAlone() throws {
    let idleContent: [String: Any] = [
        "Choices": [["Provider": "com.apple.NeptuneOneExtension", "Configuration": Data(), "Files": [Any]()]],
        "Shuffle": "$null"
    ]
    let store: [String: Any] = [
        "SystemDefault": [
            "Type": "individual",
            "Desktop": ["Content": ["Choices": [Any]()], "LastSet": Date.distantPast],
            "Idle": ["Content": idleContent]
        ],
        "Spaces": [
            "space-1": [
                "Default": ["Desktop": ["Content": ["Choices": [Any]()]]]
            ]
        ]
    ]
    let choiceID = "762DB689-BB25-435A-BB26-619F07F61A3F"
    let videoURL = URL(fileURLWithPath: "/tmp/loop.mp4")

    let rewritten = NativeVideoWallpaperService.rewritingDesktopChoices(
        in: store,
        choiceID: choiceID,
        videoURL: videoURL
    )

    for path in [["SystemDefault", "Desktop"], ["Spaces", "space-1", "Default", "Desktop"]] {
        var node: Any = rewritten
        for key in path { node = try #require((node as? [String: Any])?[key]) }
        let desktop = try #require(node as? [String: Any])
        let content = try #require(desktop["Content"] as? [String: Any])
        let choice = try #require((content["Choices"] as? [[String: Any]])?.first)
        #expect(choice["Provider"] as? String == "local.mural.wallpapers.extension")
        #expect(choice["Configuration"] as? Data == Data(choiceID.utf8))
        #expect((desktop["LastSet"] as? Date).map { $0 > .distantPast } == true)
    }

    let idle = try #require(
        ((rewritten["SystemDefault"] as? [String: Any])?["Idle"] as? [String: Any])?["Content"] as? [String: Any]
    )
    let idleChoice = try #require((idle["Choices"] as? [[String: Any]])?.first)
    #expect(idleChoice["Provider"] as? String == "com.apple.NeptuneOneExtension")
}

@Test @MainActor func detectsVideoReferencedByMacOSWallpaperStore() {
    let choiceID = "762DB689-BB25-435A-BB26-619F07F61A3F"
    let index = Data("prefix\0\(choiceID)\0suffix".utf8)

    #expect(NativeVideoWallpaperService.wallpaperIndex(index, referencesChoiceID: choiceID))
    #expect(!NativeVideoWallpaperService.wallpaperIndex(index, referencesChoiceID: UUID().uuidString))
}
