import SwiftUI

/// Renders a theme background (solid, gradient, mesh, or photo with effects).
struct ThemeBackground: View {
    let spec: BackgroundSpec
    var photoMaxSide: CGFloat = 1400

    var body: some View {
        ZStack {
            switch spec.kind {
            case .solid:
                spec.color.color
            case .gradient:
                gradient
            case .photo:
                if let img = SharedStore.thumbnail(spec.photoID, maxSide: photoMaxSide) {
                    GeometryReader { geo in
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .saturation(spec.saturation)
                            .blur(radius: spec.blur)
                    }
                } else {
                    gradient
                }
            }
            if spec.dim > 0 { Color.black.opacity(spec.dim) }
            if spec.grain > 0 { GrainOverlay(amount: spec.grain) }
        }
    }

    @ViewBuilder private var gradient: some View {
        let colors = spec.colors.isEmpty ? [spec.color.color, spec.color.color] : spec.colors.map(\.color)
        switch spec.gradientKind {
        case .linear:
            let (s, e) = Self.points(angle: spec.angle)
            LinearGradient(colors: colors, startPoint: s, endPoint: e)
        case .radial:
            GeometryReader { geo in
                RadialGradient(colors: colors, center: .center, startRadius: 0,
                               endRadius: max(geo.size.width, geo.size.height) * 0.75)
            }
        case .angular:
            AngularGradient(colors: colors + [colors[0]], center: .center, angle: .degrees(spec.angle))
        case .mesh:
            MeshGradient(width: 3, height: 3, points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [Float(0.5 + 0.2 * cos(spec.angle * .pi / 180)), Float(0.5 + 0.2 * sin(spec.angle * .pi / 180))], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1]
            ], colors: Self.meshColors(colors))
        }
    }

    static func meshColors(_ c: [Color]) -> [Color] {
        let p = c.isEmpty ? [Color.black] : c
        return (0..<9).map { i in
            let pattern = [0, 1, 2, 1, 3, 0, 2, 0, 1]
            return p[pattern[i] % p.count]
        }
    }

    /// Converts a CSS-style angle (0 = to top, 90 = to right) to gradient endpoints.
    static func points(angle: Double) -> (UnitPoint, UnitPoint) {
        let r = (angle - 90) * .pi / 180
        let dx = cos(r) / 2, dy = sin(r) / 2
        return (UnitPoint(x: 0.5 - dx, y: 0.5 - dy), UnitPoint(x: 0.5 + dx, y: 0.5 + dy))
    }
}

/// Deterministic film-grain texture.
struct GrainOverlay: View {
    let amount: Double
    var body: some View {
        Canvas { ctx, size in
            var seed: UInt64 = 0x9E3779B97F4A7C15
            let count = Int(size.width * size.height / 30 * amount)
            for _ in 0..<min(count, 20000) {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let x = CGFloat(seed >> 33) .truncatingRemainder(dividingBy: max(1, size.width))
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let y = CGFloat(seed >> 33).truncatingRemainder(dividingBy: max(1, size.height))
                let bright = (seed >> 20) & 1 == 0
                ctx.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)),
                         with: .color(bright ? .white.opacity(0.18) : .black.opacity(0.22)))
            }
        }
        .allowsHitTesting(false)
    }
}

/// Glass/border treatment for a card using theme settings (widget-safe; no materials).
struct ThemedCard<Content: View>: View {
    let theme: Theme
    var padding: CGFloat = 12
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: max(6, theme.cornerRadius * 0.6), style: .continuous)
                    .fill(Color.white.opacity(theme.glass * 0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: max(6, theme.cornerRadius * 0.6), style: .continuous)
                    .stroke(theme.borderColor.color, lineWidth: theme.glass > 0 ? max(0.5, theme.borderWidth) : theme.borderWidth)
                    .opacity(theme.borderWidth > 0 || theme.glass > 0 ? 1 : 0)
            )
    }
}
