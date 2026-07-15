import SwiftUI

struct WallpaperArtwork: View {
    let style: StudioStyle
    let colors: [Color]
    let seed: Double

    init(style: StudioStyle, colors: [Color], seed: Double) {
        self.style = style
        self.colors = colors
        self.seed = seed
    }

    init(preset: WallpaperPreset) {
        self.init(style: .dunes, colors: preset.colors.map(Color.init), seed: preset.seed)
    }

    var body: some View {
        Canvas { context, size in
            context.clip(to: Path(CGRect(origin: .zero, size: size)))
            switch style {
            case .dunes: drawDunes(in: &context, size: size)
            case .aurora: drawAurora(in: &context, size: size)
            case .ridgeline: drawRidgeline(in: &context, size: size)
            case .sunburst: drawSunburst(in: &context, size: size)
            case .terrazzo: drawTerrazzo(in: &context, size: size)
            case .arcs: drawArcs(in: &context, size: size)
            case .stripes: drawStripes(in: &context, size: size)
            case .orbits: drawOrbits(in: &context, size: size)
            case .blobs: drawBlobs(in: &context, size: size)
            case .plaid: drawPlaid(in: &context, size: size)
            case .rain: drawRain(in: &context, size: size)
            case .moon: drawMoon(in: &context, size: size)
            }
            drawGrain(in: &context, size: size)
        }
    }

    // MARK: - Dunes

    private func drawDunes(in context: inout GraphicsContext, size: CGSize) {
        let base = Path(CGRect(origin: .zero, size: size))
        context.fill(
            base,
            with: .linearGradient(
                Gradient(colors: [colors[0], colors[1]]),
                startPoint: .zero,
                endPoint: CGPoint(x: size.width, y: size.height)
            )
        )

        let orbSize = min(size.width, size.height) * 0.3
        let orbOrigin = CGPoint(
            x: size.width * (0.58 + seed * 0.18),
            y: size.height * (0.12 + seed * 0.12)
        )
        let orb = Path(ellipseIn: CGRect(origin: orbOrigin, size: CGSize(width: orbSize, height: orbSize)))
        context.fill(orb, with: .color(colors[1].opacity(0.75)))

        for layer in 0..<3 {
            let path = wavePath(
                in: size,
                baseline: size.height * (0.52 + Double(layer) * 0.13),
                amplitude: size.height * (0.045 + Double(layer) * 0.009),
                phase: seed * 8 + Double(layer)
            )
            context.fill(path, with: .color(colors[layer + 1].opacity(0.96)))
        }
    }

    // MARK: - Aurora

    private func drawAurora(in context: inout GraphicsContext, size: CGSize) {
        let base = Path(CGRect(origin: .zero, size: size))
        context.fill(
            base,
            with: .linearGradient(
                Gradient(colors: [colors[3], colors[2]]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )

        drawStars(in: &context, size: size, count: 140, maxYFraction: 0.85)

        for index in 0..<6 {
            let center = CGPoint(
                x: size.width * (0.08 + Double(index) * 0.17 + (pseudoRandom(index, salt: 41) - 0.5) * 0.1),
                y: size.height * (0.16 + pseudoRandom(index, salt: 59) * 0.38)
            )
            let radius = min(size.width, size.height) * (0.28 + pseudoRandom(index, salt: 67) * 0.3)
            let glow = colors[index.isMultiple(of: 2) ? 1 : 0]
            context.fill(
                base,
                with: .radialGradient(
                    Gradient(colors: [glow.opacity(0.5), glow.opacity(0)]),
                    center: center,
                    startRadius: 0,
                    endRadius: radius
                )
            )
        }

        let hills = ridgePath(
            in: size,
            baseline: size.height * 0.92,
            amplitude: size.height * 0.08,
            segments: 10,
            salt: 83
        )
        context.fill(hills, with: .color(.black.opacity(0.38)))
    }

    // MARK: - Ridgeline

    private func drawRidgeline(in context: inout GraphicsContext, size: CGSize) {
        let base = Path(CGRect(origin: .zero, size: size))
        context.fill(
            base,
            with: .linearGradient(
                Gradient(colors: [colors[0], colors[1]]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )

        let sunRadius = min(size.width, size.height) * 0.085
        let sunCenter = CGPoint(x: size.width * (0.24 + seed * 0.5), y: size.height * 0.24)
        context.fill(circlePath(center: sunCenter, radius: sunRadius), with: .color(.white.opacity(0.8)))

        for layer in 0..<4 {
            let ridge = ridgePath(
                in: size,
                baseline: size.height * (0.46 + Double(layer) * 0.15),
                amplitude: size.height * (0.16 - Double(layer) * 0.02),
                segments: 14,
                salt: 83 + layer * 37
            )
            let tone = colors[min(layer + 1, 3)]
            let opacity = min(0.5 + Double(layer) * 0.16, 1)
            context.fill(ridge, with: .color(tone.opacity(opacity)))
        }
    }

    // MARK: - Sunburst

    private func drawSunburst(in context: inout GraphicsContext, size: CGSize) {
        let base = Path(CGRect(origin: .zero, size: size))
        context.fill(base, with: .color(colors[0]))

        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.42)
        let reach = hypot(size.width, size.height)
        let rayCount = 22
        for ray in 0..<rayCount where ray.isMultiple(of: 2) {
            let start = Double(ray) / Double(rayCount) * 2 * .pi + seed * .pi
            let end = start + 2 * .pi / Double(rayCount)
            var wedge = Path()
            wedge.move(to: center)
            wedge.addArc(
                center: center,
                radius: reach,
                startAngle: .radians(start),
                endAngle: .radians(end),
                clockwise: false
            )
            wedge.closeSubpath()
            context.fill(wedge, with: .color(colors[1].opacity(0.28)))
        }

        let sunRadius = min(size.width, size.height) * 0.16
        context.stroke(
            circlePath(center: center, radius: sunRadius * 1.25),
            with: .color(colors[1].opacity(0.55)),
            lineWidth: sunRadius * 0.08
        )
        context.fill(circlePath(center: center, radius: sunRadius), with: .color(colors[1]))
        context.fill(circlePath(center: center, radius: sunRadius * 0.6), with: .color(colors[2].opacity(0.85)))

        for layer in 0..<2 {
            let path = wavePath(
                in: size,
                baseline: size.height * (0.66 + Double(layer) * 0.14),
                amplitude: size.height * 0.03,
                phase: seed * 6 + Double(layer) * 1.7
            )
            context.fill(path, with: .color(colors[layer + 2].opacity(0.96)))
        }
    }

    // MARK: - Terrazzo

    private func drawTerrazzo(in context: inout GraphicsContext, size: CGSize) {
        let base = Path(CGRect(origin: .zero, size: size))
        context.fill(base, with: .color(colors[0]))

        let chipCount = 110
        for index in 0..<chipCount {
            let center = CGPoint(
                x: pseudoRandom(index, salt: 11) * size.width,
                y: pseudoRandom(index, salt: 29) * size.height
            )
            let radius = min(size.width, size.height) * (0.012 + pseudoRandom(index, salt: 43) * 0.05)
            let tone = colors[1 + index % 3]
            context.fill(
                chipPath(center: center, radius: radius, salt: index),
                with: .color(tone.opacity(0.75 + pseudoRandom(index, salt: 61) * 0.25))
            )
        }

        for index in 0..<50 {
            let center = CGPoint(
                x: pseudoRandom(index, salt: 71) * size.width,
                y: pseudoRandom(index, salt: 89) * size.height
            )
            let radius = min(size.width, size.height) * 0.004
            context.fill(circlePath(center: center, radius: radius), with: .color(.white.opacity(0.5)))
        }
    }

    // MARK: - Arcs

    private func drawArcs(in context: inout GraphicsContext, size: CGSize) {
        let base = Path(CGRect(origin: .zero, size: size))
        context.fill(base, with: .color(colors[0]))

        let center = CGPoint(x: size.width * (0.3 + seed * 0.4), y: size.height * 1.02)
        let bandWidth = min(size.width, size.height) * 0.11
        let baseRadius = min(size.width, size.height) * 0.32
        for band in 0..<5 {
            let radius = baseRadius + Double(band) * bandWidth
            let tone = colors[1 + band % 3]
            var arc = Path()
            arc.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            context.stroke(arc, with: .color(tone.opacity(0.92)), style: StrokeStyle(lineWidth: bandWidth * 0.72, lineCap: .round))
        }

        let echoCenter = CGPoint(x: size.width * (seed > 0.5 ? 0.06 : 0.94), y: -size.height * 0.04)
        for band in 0..<3 {
            let radius = baseRadius * 0.5 + Double(band) * bandWidth * 0.7
            let tone = colors[3 - band % 2]
            var arc = Path()
            arc.addArc(center: echoCenter, radius: radius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
            context.stroke(arc, with: .color(tone.opacity(0.4)), style: StrokeStyle(lineWidth: bandWidth * 0.34, lineCap: .round))
        }
    }

    // MARK: - Stripes

    private func drawStripes(in context: inout GraphicsContext, size: CGSize) {
        let base = Path(CGRect(origin: .zero, size: size))
        context.fill(base, with: .color(colors[0]))

        context.drawLayer { layer in
            layer.translateBy(x: size.width / 2, y: size.height / 2)
            layer.rotate(by: .degrees(-30 + seed * 60))
            layer.translateBy(x: -size.width / 2, y: -size.height / 2)

            let reach = hypot(size.width, size.height)
            var x = -reach * 0.5
            var index = 0
            while x < reach * 1.5 {
                let width = reach * (0.02 + pseudoRandom(index, salt: 17) * 0.08)
                let tone = colors[1 + index % 3]
                let stripe = Path(CGRect(x: x, y: -reach * 0.5, width: width, height: reach * 2))
                layer.fill(stripe, with: .color(tone.opacity(0.6 + pseudoRandom(index, salt: 31) * 0.4)))
                x += width + reach * (0.03 + pseudoRandom(index, salt: 53) * 0.09)
                index += 1
            }
        }
    }

    // MARK: - Orbits

    private func drawOrbits(in context: inout GraphicsContext, size: CGSize) {
        let base = Path(CGRect(origin: .zero, size: size))
        context.fill(
            base,
            with: .linearGradient(
                Gradient(colors: [colors[3], colors[2]]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )

        drawStars(in: &context, size: size, count: 110, maxYFraction: 1)

        let center = CGPoint(x: size.width * (0.35 + seed * 0.3), y: size.height * 0.46)
        let sunRadius = min(size.width, size.height) * 0.07
        context.fill(circlePath(center: center, radius: sunRadius), with: .color(colors[0]))

        for ring in 0..<5 {
            let radius = sunRadius * (2.2 + Double(ring) * 1.5)
            context.stroke(
                circlePath(center: center, radius: radius),
                with: .color(colors[0].opacity(0.28)),
                style: StrokeStyle(lineWidth: max(1.2, size.width / 900), dash: ring.isMultiple(of: 2) ? [] : [6, 5])
            )

            let angle = pseudoRandom(ring, salt: 37) * 2 * .pi
            let planetRadius = sunRadius * (0.18 + pseudoRandom(ring, salt: 47) * 0.3)
            let planetCenter = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            context.fill(circlePath(center: planetCenter, radius: planetRadius), with: .color(colors[ring % 2]))
        }
    }

    // MARK: - Blobs

    private func drawBlobs(in context: inout GraphicsContext, size: CGSize) {
        let base = Path(CGRect(origin: .zero, size: size))
        context.fill(base, with: .color(colors[0]))

        for index in 0..<8 {
            let center = CGPoint(
                x: size.width * (0.1 + pseudoRandom(index, salt: 13) * 0.8),
                y: size.height * (0.1 + pseudoRandom(index, salt: 41) * 0.8)
            )
            let radius = min(size.width, size.height) * (0.09 + pseudoRandom(index, salt: 59) * 0.14)
            let tone = colors[1 + index % 3]
            context.fill(
                blobPath(center: center, radius: radius, salt: index),
                with: .color(tone.opacity(0.88))
            )
        }
    }

    // MARK: - Plaid

    private func drawPlaid(in context: inout GraphicsContext, size: CGSize) {
        let base = Path(CGRect(origin: .zero, size: size))
        context.fill(base, with: .color(colors[0]))

        var x: Double = -size.width * 0.02
        var index = 0
        while x < size.width {
            let width = size.width * (0.03 + pseudoRandom(index, salt: 19) * 0.09)
            let tone = colors[1 + index % 3]
            context.fill(
                Path(CGRect(x: x, y: 0, width: width, height: size.height)),
                with: .color(tone.opacity(0.35))
            )
            x += width + size.width * (0.04 + pseudoRandom(index, salt: 37) * 0.08)
            index += 1
        }

        var y: Double = -size.height * 0.02
        index = 40
        while y < size.height {
            let height = size.height * (0.03 + pseudoRandom(index, salt: 23) * 0.09)
            let tone = colors[1 + index % 3]
            context.fill(
                Path(CGRect(x: 0, y: y, width: size.width, height: height)),
                with: .color(tone.opacity(0.35))
            )
            y += height + size.height * (0.04 + pseudoRandom(index, salt: 43) * 0.08)
            index += 1
        }
    }

    // MARK: - Rain

    private func drawRain(in context: inout GraphicsContext, size: CGSize) {
        let base = Path(CGRect(origin: .zero, size: size))
        context.fill(
            base,
            with: .linearGradient(
                Gradient(colors: [colors[1], colors[2]]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )

        let slant = size.width * (0.008 + seed * 0.012)
        for index in 0..<160 {
            let start = CGPoint(
                x: pseudoRandom(index, salt: 7) * size.width,
                y: pseudoRandom(index, salt: 21) * size.height
            )
            let length = size.height * (0.02 + pseudoRandom(index, salt: 33) * 0.05)
            var drop = Path()
            drop.move(to: start)
            drop.addLine(to: CGPoint(x: start.x - slant, y: start.y + length))
            let tone = index % 4 == 0 ? colors[0] : colors[3]
            context.stroke(
                drop,
                with: .color(tone.opacity(0.25 + pseudoRandom(index, salt: 49) * 0.3)),
                style: StrokeStyle(lineWidth: max(1, size.width / 1400), lineCap: .round)
            )
        }

        let ground = wavePath(
            in: size,
            baseline: size.height * 0.88,
            amplitude: size.height * 0.012,
            phase: seed * 5
        )
        context.fill(ground, with: .color(colors[3].opacity(0.9)))
    }

    // MARK: - Moon

    private func drawMoon(in context: inout GraphicsContext, size: CGSize) {
        let base = Path(CGRect(origin: .zero, size: size))
        context.fill(
            base,
            with: .linearGradient(
                Gradient(colors: [colors[3], colors[2]]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )

        drawStars(in: &context, size: size, count: 120, maxYFraction: 0.9)

        let moonRadius = min(size.width, size.height) * 0.17
        let moonCenter = CGPoint(x: size.width * (0.3 + seed * 0.4), y: size.height * 0.32)
        context.fill(
            base,
            with: .radialGradient(
                Gradient(colors: [colors[0].opacity(0.35), colors[0].opacity(0)]),
                center: moonCenter,
                startRadius: moonRadius,
                endRadius: moonRadius * 2.6
            )
        )
        context.fill(circlePath(center: moonCenter, radius: moonRadius), with: .color(colors[0]))
        for index in 0..<5 {
            let angle = pseudoRandom(index, salt: 27) * 2 * .pi
            let distance = pseudoRandom(index, salt: 39) * moonRadius * 0.62
            let craterCenter = CGPoint(
                x: moonCenter.x + cos(angle) * distance,
                y: moonCenter.y + sin(angle) * distance
            )
            let craterRadius = moonRadius * (0.06 + pseudoRandom(index, salt: 57) * 0.1)
            context.fill(circlePath(center: craterCenter, radius: craterRadius), with: .color(colors[1].opacity(0.45)))
        }

        for index in 0..<4 {
            let cloudY = size.height * (0.2 + pseudoRandom(index, salt: 63) * 0.5)
            let cloudWidth = size.width * (0.24 + pseudoRandom(index, salt: 77) * 0.3)
            let cloudX = pseudoRandom(index, salt: 91) * size.width - cloudWidth / 2
            let cloudHeight = size.height * 0.028
            let cloud = Path(
                roundedRect: CGRect(x: cloudX, y: cloudY, width: cloudWidth, height: cloudHeight),
                cornerRadius: cloudHeight / 2
            )
            context.fill(cloud, with: .color(colors[2].opacity(0.55)))
        }

        let hills = ridgePath(
            in: size,
            baseline: size.height * 0.9,
            amplitude: size.height * 0.09,
            segments: 9,
            salt: 97
        )
        context.fill(hills, with: .color(.black.opacity(0.42)))
    }

    // MARK: - Shared strokes

    /// A sine band filled down to the bottom edge, as used by dunes and horizons.
    private func wavePath(in size: CGSize, baseline: Double, amplitude: Double, phase: Double) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: baseline))
        let points = 9
        for index in 0...points {
            let x = size.width * Double(index) / Double(points)
            let wave = sin(Double(index) * 1.35 + phase)
            path.addLine(to: CGPoint(x: x, y: baseline + wave * amplitude))
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }

    /// A jagged skyline filled down to the bottom edge.
    private func ridgePath(in size: CGSize, baseline: Double, amplitude: Double, segments: Int, salt: Int) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: baseline))
        for index in 0...segments {
            let x = size.width * Double(index) / Double(segments)
            let lift = pseudoRandom(index, salt: salt)
            path.addLine(to: CGPoint(x: x, y: baseline - lift * amplitude))
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }

    /// An irregular 6-point chip, like a terrazzo stone fragment.
    private func chipPath(center: CGPoint, radius: Double, salt: Int) -> Path {
        var path = Path()
        let points = 6
        for index in 0...points {
            let angle = Double(index % points) / Double(points) * 2 * .pi + pseudoRandom(salt, salt: 3) * .pi
            let wobble = 0.6 + pseudoRandom(index + salt * 7, salt: 9) * 0.5
            let point = CGPoint(
                x: center.x + cos(angle) * radius * wobble,
                y: center.y + sin(angle) * radius * wobble
            )
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    /// A soft organic blob traced with smooth quad curves.
    private func blobPath(center: CGPoint, radius: Double, salt: Int) -> Path {
        let points = 8
        var vertices: [CGPoint] = []
        for index in 0..<points {
            let angle = Double(index) / Double(points) * 2 * .pi
            let wobble = 0.65 + pseudoRandom(index + salt * 13, salt: 25) * 0.6
            vertices.append(CGPoint(
                x: center.x + cos(angle) * radius * wobble,
                y: center.y + sin(angle) * radius * wobble
            ))
        }
        var path = Path()
        let midpoint = CGPoint(
            x: (vertices[points - 1].x + vertices[0].x) / 2,
            y: (vertices[points - 1].y + vertices[0].y) / 2
        )
        path.move(to: midpoint)
        for index in 0..<points {
            let control = vertices[index]
            let next = vertices[(index + 1) % points]
            path.addQuadCurve(
                to: CGPoint(x: (control.x + next.x) / 2, y: (control.y + next.y) / 2),
                control: control
            )
        }
        path.closeSubpath()
        return path
    }

    private func circlePath(center: CGPoint, radius: Double) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    private func drawStars(in context: inout GraphicsContext, size: CGSize, count: Int, maxYFraction: Double) {
        for index in 0..<count {
            let x = pseudoRandom(index, salt: 5) * size.width
            let y = pseudoRandom(index, salt: 17) * size.height * maxYFraction
            let radius = 0.6 + pseudoRandom(index, salt: 23) * 1.6
            let star = Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius))
            context.fill(star, with: .color(.white.opacity(0.1 + pseudoRandom(index, salt: 31) * 0.25)))
        }
    }

    private func drawGrain(in context: inout GraphicsContext, size: CGSize) {
        let grainCount = Int(max(120, size.width / 3))
        for index in 0..<grainCount {
            let x = pseudoRandom(index, salt: 19) * size.width
            let y = pseudoRandom(index, salt: 47) * size.height
            let radius = 0.35 + pseudoRandom(index, salt: 73) * 0.9
            let dot = Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius))
            context.fill(dot, with: .color(.white.opacity(0.08)))
        }
    }

    private func pseudoRandom(_ value: Int, salt: Int) -> Double {
        let x = sin(Double(value * 12_989 + salt * 78_233) + seed * 43_758) * 43_758.5453
        return x - floor(x)
    }
}
