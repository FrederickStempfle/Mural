import AppKit
import Foundation

enum WallpaperSource: Hashable {
    case bundled(URL)
    case procedural(WallpaperPreset)
    case imported(URL)
    case video(URL)
}

struct Wallpaper: Identifiable, Hashable {
    let id: String
    let title: String
    let collection: String
    let source: WallpaperSource

    var isVideo: Bool {
        if case .video = source { true } else { false }
    }

    var isImported: Bool {
        switch source {
        case .imported, .video: true
        default: false
        }
    }
}

enum WallpaperPreset: String, CaseIterable, Hashable, Codable {
    case quietTide
    case blueHour
    case ember
    case moss
    case plum

    var title: String {
        switch self {
        case .quietTide: "Quiet Tide"
        case .blueHour: "Blue Hour"
        case .ember: "Ember"
        case .moss: "Moss Study"
        case .plum: "Plum Field"
        }
    }

    var collection: String { "Mural Studio" }

    var colors: [NSColor] {
        switch self {
        case .quietTide:
            [NSColor(hex: 0xD8E0D5), NSColor(hex: 0x91A89E), NSColor(hex: 0x426A66), NSColor(hex: 0x173D3D)]
        case .blueHour:
            [NSColor(hex: 0xD7D8D4), NSColor(hex: 0x8D9BA8), NSColor(hex: 0x4A5968), NSColor(hex: 0x202936)]
        case .ember:
            [NSColor(hex: 0xE3C5A6), NSColor(hex: 0xC36B45), NSColor(hex: 0x783D35), NSColor(hex: 0x342725)]
        case .moss:
            [NSColor(hex: 0xD4CEB4), NSColor(hex: 0x8E9773), NSColor(hex: 0x4E654F), NSColor(hex: 0x243A32)]
        case .plum:
            [NSColor(hex: 0xD8C7CE), NSColor(hex: 0xAA7C8B), NSColor(hex: 0x704858), NSColor(hex: 0x372D39)]
        }
    }

    var seed: Double {
        switch self {
        case .quietTide: 0.12
        case .blueHour: 0.31
        case .ember: 0.48
        case .moss: 0.67
        case .plum: 0.86
        }
    }
}

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all = "All Wallpapers"
    case builtIn = "Curated"
    case imported = "My Wallpapers"
    case studio = "Mural Studio"
    case favorites = "Favorites"
    case recent = "Recently Used"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .all: "rectangle.grid.2x2"
        case .builtIn: "photo.stack"
        case .imported: "photo.on.rectangle.angled"
        case .studio: "paintbrush"
        case .favorites: "heart"
        case .recent: "clock.arrow.circlepath"
        }
    }
}

enum DisplayTarget: String, CaseIterable, Identifiable {
    case all = "All Displays"
    case main = "Main Display"

    var id: String { rawValue }
}
