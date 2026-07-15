import SwiftUI

/// The composition a procedural studio wallpaper is drawn with.
enum StudioStyle: String, CaseIterable, Identifiable {
    case dunes
    case aurora
    case ridgeline
    case sunburst
    case terrazzo
    case arcs
    case stripes
    case orbits
    case blobs
    case plaid
    case rain
    case moon

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dunes: "Dunes"
        case .aurora: "Aurora"
        case .ridgeline: "Ridgeline"
        case .sunburst: "Sunburst"
        case .terrazzo: "Terrazzo"
        case .arcs: "Arcs"
        case .stripes: "Stripes"
        case .orbits: "Orbits"
        case .blobs: "Cutouts"
        case .plaid: "Plaid"
        case .rain: "Rainfall"
        case .moon: "Moonrise"
        }
    }

    var symbol: String {
        switch self {
        case .dunes: "water.waves"
        case .aurora: "sparkles"
        case .ridgeline: "mountain.2"
        case .sunburst: "sun.max"
        case .terrazzo: "circle.hexagongrid"
        case .arcs: "rainbow"
        case .stripes: "line.diagonal"
        case .orbits: "circles.hexagonpath"
        case .blobs: "drop"
        case .plaid: "grid"
        case .rain: "cloud.rain"
        case .moon: "moon.stars"
        }
    }
}

/// What fills the canvas behind the stickers: a drawn style or the user's photo.
enum StudioBackdrop: Hashable {
    case style(StudioStyle)
    case photo(URL)
}

/// One sticker placed on the canvas. Position and width are relative to the
/// canvas (0–1), so previews and the full-resolution render agree exactly.
struct StickerPlacement: Identifiable, Hashable {
    let id: UUID
    let url: URL
    var centerX: Double
    var centerY: Double
    var width: Double
    var rotation: Double

    init(url: URL, centerX: Double = 0.5, centerY: Double = 0.5, width: Double = 0.18, rotation: Double = 0) {
        self.id = UUID()
        self.url = url
        self.centerX = centerX
        self.centerY = centerY
        self.width = width
        self.rotation = rotation
    }
}

/// A named set of four tones, ordered light to dark.
struct StudioPalette: Identifiable, Hashable {
    let name: String
    let colors: [Color]

    var id: String { name }

    static let curated: [StudioPalette] =
        WallpaperPreset.allCases.map { preset in
            StudioPalette(name: preset.title, colors: preset.colors.map(Color.init))
        } + [
            StudioPalette(name: "Peach Fuzz", colors: [hex(0xF7E1C8), hex(0xEDA96E), hex(0xC96F4A), hex(0x7A3B2E)]),
            StudioPalette(name: "Ink Wash", colors: [hex(0xE8E6E1), hex(0xB5B3AC), hex(0x6E6C66), hex(0x2C2B28)]),
            StudioPalette(name: "Midnight", colors: [hex(0xB8C4E0), hex(0x67729D), hex(0x3A3F63), hex(0x14152B)]),
            StudioPalette(name: "Meadow", colors: [hex(0xF2EFC7), hex(0xB9CE8B), hex(0x6D9B5B), hex(0x2F5233)]),
            StudioPalette(name: "Sorbet", colors: [hex(0xF9E0E3), hex(0xF2A6B3), hex(0xD96C8A), hex(0x8C3A56)]),
            StudioPalette(name: "Glacier", colors: [hex(0xE9F1F2), hex(0xACCBD6), hex(0x6E93A6), hex(0x32506B)]),
            StudioPalette(name: "Desert Road", colors: [hex(0xF2E3C9), hex(0xD9A566), hex(0xA66038), hex(0x59322B)]),
            StudioPalette(name: "Neon Dusk", colors: [hex(0xD9BFF2), hex(0x9B72CF), hex(0x5C3D99), hex(0x251A40)]),
            StudioPalette(name: "Forest Floor", colors: [hex(0xE5E0CF), hex(0xA3B18A), hex(0x588157), hex(0x344E41)]),
            StudioPalette(name: "Sea Glass", colors: [hex(0xE7F0EA), hex(0x9CC5B0), hex(0x4E8D7C), hex(0x1F4E46)]),
            StudioPalette(name: "Bubblegum", colors: [hex(0xF7D6E0), hex(0xEFA3C8), hex(0xC566A0), hex(0x71336B)]),
            StudioPalette(name: "Storm", colors: [hex(0xDFE3E8), hex(0x9FB1C1), hex(0x5A7186), hex(0x2B3A4A)])
        ]

    private static func hex(_ value: UInt32) -> Color {
        Color(
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255
        )
    }
}

/// A wallpaper the user is sketching in Mural Studio.
struct StudioDesign: Hashable {
    var backdrop: StudioBackdrop
    var colors: [Color]
    var seed: Double
    var stickers: [StickerPlacement]

    init(backdrop: StudioBackdrop, colors: [Color], seed: Double, stickers: [StickerPlacement] = []) {
        self.backdrop = backdrop
        self.colors = colors
        self.seed = seed
        self.stickers = stickers
    }

    /// Maps a built-in procedural preset onto the studio's editable form.
    init(preset: WallpaperPreset) {
        self.init(backdrop: .style(.dunes), colors: preset.colors.map(Color.init), seed: preset.seed)
    }

    static let initial = StudioDesign(backdrop: .style(.dunes), colors: StudioPalette.curated[0].colors, seed: 0.42)

    var style: StudioStyle? {
        if case .style(let style) = backdrop { style } else { nil }
    }

    static func random() -> StudioDesign {
        StudioDesign(
            backdrop: .style(StudioStyle.allCases.randomElement() ?? .dunes),
            colors: Bool.random()
                ? randomColors()
                : (StudioPalette.curated.randomElement()?.colors ?? initial.colors),
            seed: .random(in: 0..<1)
        )
    }

    /// Four cohesive tones: a shared hue that drifts slightly while
    /// brightness falls and saturation deepens, like the curated palettes.
    static func randomColors() -> [Color] {
        let hue = Double.random(in: 0..<1)
        let drift = Double.random(in: -0.09...0.09)
        let brightness = [0.9, 0.66, 0.44, 0.22]
        let saturation = [0.22, 0.38, 0.48, 0.52]
        return (0..<4).map { step in
            Color(
                hue: wrappedHue(hue + drift * Double(step)),
                saturation: saturation[step],
                brightness: brightness[step]
            )
        }
    }

    var suggestedName: String {
        let base = style?.title ?? "Collage"
        return "\(base) No. \(Int((seed * 98).rounded()) + 1)"
    }

    private static func wrappedHue(_ value: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: 1)
        return remainder < 0 ? remainder + 1 : remainder
    }
}
