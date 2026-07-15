import SwiftUI

struct WallpaperArtwork: View {
    let preset: WallpaperPreset

    var body: some View {
        Canvas { context, size in
            let colors = preset.colors.map(Color.init)
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
                x: size.width * (0.58 + preset.seed * 0.18),
                y: size.height * (0.12 + preset.seed * 0.12)
            )
            let orb = Path(ellipseIn: CGRect(origin: orbOrigin, size: CGSize(width: orbSize, height: orbSize)))
            context.fill(orb, with: .color(colors[1].opacity(0.75)))

            for layer in 0..<3 {
                var path = Path()
                let startY = size.height * (0.52 + Double(layer) * 0.13)
                path.move(to: CGPoint(x: 0, y: startY))
                let points = 9
                for index in 0...points {
                    let x = size.width * Double(index) / Double(points)
                    let wave = sin(Double(index) * 1.35 + preset.seed * 8 + Double(layer))
                    let y = startY + wave * size.height * (0.045 + Double(layer) * 0.009)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: size.height))
                path.closeSubpath()
                context.fill(path, with: .color(colors[layer + 1].opacity(0.96)))
            }

            let grainCount = Int(max(120, size.width / 3))
            for index in 0..<grainCount {
                let x = pseudoRandom(index, salt: 19) * size.width
                let y = pseudoRandom(index, salt: 47) * size.height
                let radius = 0.35 + pseudoRandom(index, salt: 73) * 0.9
                let dot = Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius))
                context.fill(dot, with: .color(.white.opacity(0.08)))
            }
        }
    }

    private func pseudoRandom(_ value: Int, salt: Int) -> Double {
        let x = sin(Double(value * 12_989 + salt * 78_233) + preset.seed * 43_758) * 43_758.5453
        return x - floor(x)
    }
}
