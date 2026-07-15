import AppKit
import CoreText
import SwiftUI

// MARK: - Palette

/// Hand-drawn "paper & ink" palette. Every color adapts to light/dark appearance.
enum Paper {
    static let base = dynamic(light: 0xFAF4E6, dark: 0x1E1D22)
    static let raised = dynamic(light: 0xFFFCF3, dark: 0x26252C)
    static let sunken = dynamic(light: 0xF1E8D2, dark: 0x18171C)
    static let ink = dynamic(light: 0x2A2620, dark: 0xEAE4D3)
    static let accent = dynamic(light: 0xE2557B, dark: 0xF07FA0)
    static let leaf = dynamic(light: 0x47795B, dark: 0x7CB08D)
    static let sunshine = dynamic(light: 0xDFA92E, dark: 0xE9C46A)
    static let navy = dynamic(light: 0x35538F, dark: 0x93A9DE)

    static var inkSecondary: Color { ink.opacity(0.62) }
    static var inkFaint: Color { ink.opacity(0.32) }
    static var inkHairline: Color { ink.opacity(0.16) }

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return nsColor(hex: isDark ? dark : light)
        })
    }

    private static func nsColor(hex: UInt32) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: 1
        )
    }
}

// MARK: - Typeface

enum VirgilFont {
    static let family = "Virgil 3 YOFF"

    /// Registers the bundled Excalidraw handwriting face for this process.
    static func register() {
        guard let url = ResourceLocator.url(forResource: "Virgil", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

extension Font {
    static func virgil(_ size: CGFloat) -> Font {
        .custom(VirgilFont.family, size: size)
    }
}

// MARK: - Deterministic wobble

private nonisolated func wobble(_ index: Int, seed: Double, salt: Int) -> Double {
    let raw = sin(Double(index * 27_449 + salt * 130_003) + seed * 91_733) * 43_758.5453
    return (raw - floor(raw)) * 2 - 1
}

// MARK: - Sketchy shapes

/// A rounded rectangle whose edges wander slightly, like a rectangle drawn by hand.
struct SketchyRoundedRectangle: Shape {
    var cornerRadius: CGFloat = 12
    var seed: Double = 0
    var roughness: CGFloat = 1.4

    func path(in rect: CGRect) -> Path {
        let radius = min(cornerRadius, min(rect.width, rect.height) / 2 - 1)
        let points = perimeterPoints(in: rect, radius: max(radius, 2))
        guard points.count > 2 else { return Path(roundedRect: rect, cornerRadius: cornerRadius) }

        var path = Path()
        let first = midpoint(points[points.count - 1], points[0])
        path.move(to: first)
        for index in 0..<points.count {
            let control = points[index]
            let next = points[(index + 1) % points.count]
            path.addQuadCurve(to: midpoint(control, next), control: control)
        }
        path.closeSubpath()
        return path
    }

    private func perimeterPoints(in rect: CGRect, radius: CGFloat) -> [CGPoint] {
        var points: [CGPoint] = []
        var index = 0

        func jittered(_ point: CGPoint, along normal: CGVector) -> CGPoint {
            defer { index += 1 }
            let offset = CGFloat(wobble(index, seed: seed, salt: 11)) * roughness
            return CGPoint(x: point.x + normal.dx * offset, y: point.y + normal.dy * offset)
        }

        func edge(from start: CGPoint, to end: CGPoint, normal: CGVector) {
            let length = hypot(end.x - start.x, end.y - start.y)
            let segments = max(2, Int(length / 26))
            for step in 0...segments {
                let t = CGFloat(step) / CGFloat(segments)
                let point = CGPoint(
                    x: start.x + (end.x - start.x) * t,
                    y: start.y + (end.y - start.y) * t
                )
                points.append(jittered(point, along: normal))
            }
        }

        func corner(center: CGPoint, from startAngle: CGFloat) {
            for step in 1...2 {
                let angle = startAngle + CGFloat(step) * (.pi / 2) / 3
                let point = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
                points.append(jittered(point, along: CGVector(dx: cos(angle) * 0.7, dy: sin(angle) * 0.7)))
            }
        }

        edge(
            from: CGPoint(x: rect.minX + radius, y: rect.minY),
            to: CGPoint(x: rect.maxX - radius, y: rect.minY),
            normal: CGVector(dx: 0, dy: 1)
        )
        corner(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius), from: -.pi / 2)
        edge(
            from: CGPoint(x: rect.maxX, y: rect.minY + radius),
            to: CGPoint(x: rect.maxX, y: rect.maxY - radius),
            normal: CGVector(dx: -1, dy: 0)
        )
        corner(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius), from: 0)
        edge(
            from: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            to: CGPoint(x: rect.minX + radius, y: rect.maxY),
            normal: CGVector(dx: 0, dy: -1)
        )
        corner(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius), from: .pi / 2)
        edge(
            from: CGPoint(x: rect.minX, y: rect.maxY - radius),
            to: CGPoint(x: rect.minX, y: rect.minY + radius),
            normal: CGVector(dx: 1, dy: 0)
        )
        corner(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius), from: .pi)
        return points
    }

    private func midpoint(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
        CGPoint(x: (lhs.x + rhs.x) / 2, y: (lhs.y + rhs.y) / 2)
    }
}

/// A slightly wavering straight line for dividers and underlines.
struct SketchyLine: Shape {
    var seed: Double = 0
    var roughness: CGFloat = 1.1

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let isHorizontal = rect.width >= rect.height
        let length = isHorizontal ? rect.width : rect.height
        let segments = max(3, Int(length / 30))

        for step in 0...segments {
            let t = CGFloat(step) / CGFloat(segments)
            let offset = CGFloat(wobble(step, seed: seed, salt: 29)) * roughness
            let point = isHorizontal
                ? CGPoint(x: rect.minX + length * t, y: rect.midY + offset)
                : CGPoint(x: rect.midX + offset, y: rect.minY + length * t)
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}

// MARK: - Sketchy chrome modifiers

/// Excalidraw-style double stroke: a confident pass plus a lighter second pass.
struct SketchyBorder: ViewModifier {
    var cornerRadius: CGFloat
    var color: Color
    var lineWidth: CGFloat
    var seed: Double

    func body(content: Content) -> some View {
        content
            .overlay {
                SketchyRoundedRectangle(cornerRadius: cornerRadius, seed: seed)
                    .stroke(color, lineWidth: lineWidth)
            }
            .overlay {
                SketchyRoundedRectangle(cornerRadius: cornerRadius, seed: seed + 7.3, roughness: 2)
                    .stroke(color.opacity(0.35), lineWidth: lineWidth * 0.8)
            }
    }
}

extension View {
    func sketchyBorder(
        cornerRadius: CGFloat,
        color: Color = Paper.ink,
        lineWidth: CGFloat = 1.4,
        seed: Double = 0
    ) -> some View {
        modifier(SketchyBorder(cornerRadius: cornerRadius, color: color, lineWidth: lineWidth, seed: seed))
    }

    /// Solid offset "sticker" shadow, drawn with the same sketchy outline.
    func sketchyShadow(cornerRadius: CGFloat, seed: Double = 0, offset: CGSize = CGSize(width: 3, height: 4)) -> some View {
        background {
            SketchyRoundedRectangle(cornerRadius: cornerRadius, seed: seed + 3.1)
                .fill(Paper.ink.opacity(0.28))
                .offset(x: offset.width, y: offset.height)
        }
    }
}

// MARK: - Buttons

struct SketchyButtonStyle: ButtonStyle {
    enum Variant {
        case filled
        case outline
    }

    var variant: Variant = .filled
    var tint: Color = Paper.accent
    var cornerRadius: CGFloat = 11
    var seed: Double = 0

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        configuration.label
            .font(.virgil(15))
            .foregroundStyle(variant == .filled ? Paper.raised : Paper.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                SketchyRoundedRectangle(cornerRadius: cornerRadius, seed: seed)
                    .fill(variant == .filled ? tint : Paper.raised)
            }
            .sketchyBorder(cornerRadius: cornerRadius, seed: seed)
            .sketchyShadow(
                cornerRadius: cornerRadius,
                seed: seed,
                offset: isPressed ? CGSize(width: 1, height: 1.5) : CGSize(width: 3, height: 4)
            )
            .offset(x: isPressed ? 2 : 0, y: isPressed ? 2.5 : 0)
            .animation(.spring(duration: 0.18), value: isPressed)
    }
}

// MARK: - Decorations

/// A translucent strip of washi tape.
struct TapeView: View {
    var rotation: Double = -3
    var tint: Color = Paper.sunshine

    var body: some View {
        Rectangle()
            .fill(tint.opacity(0.4))
            .frame(width: 56, height: 17)
            .overlay {
                Rectangle().stroke(Paper.ink.opacity(0.12), lineWidth: 0.8)
            }
            .rotationEffect(.degrees(rotation))
    }
}

/// Dot-grid notebook paper backdrop.
struct DotGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 24
            var y: CGFloat = spacing / 2
            while y < size.height {
                var x: CGFloat = spacing / 2
                while x < size.width {
                    let dot = Path(ellipseIn: CGRect(x: x, y: y, width: 1.6, height: 1.6))
                    context.fill(dot, with: .color(Paper.ink.opacity(0.07)))
                    x += spacing
                }
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }
}

/// A little hand-drawn sun doodle for the logotype.
struct SunDoodle: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.26

            var disc = Path()
            disc.addArc(center: center, radius: radius, startAngle: .degrees(8), endAngle: .degrees(348), clockwise: false)
            context.stroke(disc, with: .color(Paper.sunshine), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))

            for ray in 0..<8 {
                let angle = Double(ray) * .pi / 4 + 0.18
                let jitter = 1 + 0.16 * wobble(ray, seed: 4.2, salt: 53)
                var path = Path()
                path.move(to: CGPoint(
                    x: center.x + cos(angle) * radius * 1.45,
                    y: center.y + sin(angle) * radius * 1.45
                ))
                path.addLine(to: CGPoint(
                    x: center.x + cos(angle) * radius * (1.95 * jitter),
                    y: center.y + sin(angle) * radius * (1.95 * jitter)
                ))
                context.stroke(path, with: .color(Paper.sunshine), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            }
        }
    }
}

/// Stable per-item wobble so each card keeps its own tilt and outline.
nonisolated func sketchSeed(for id: String) -> Double {
    let hash = id.unicodeScalars.reduce(5381 as UInt64) { ($0 << 5) &+ $0 &+ UInt64($1.value) }
    return Double(hash % 1000) / 1000 * 12
}
