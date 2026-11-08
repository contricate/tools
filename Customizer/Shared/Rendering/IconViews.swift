import SwiftUI

struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        for i in 0..<6 {
            let a = Double(i) * .pi / 3 - .pi / 2
            let pt = CGPoint(x: c.x + r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a)))
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        return p
    }
}

struct IconShapeView: Shape {
    let shape: IconShape
    func path(in rect: CGRect) -> Path {
        switch shape {
        case .squircle: return RoundedRectangle(cornerRadius: rect.width * 0.225, style: .continuous).path(in: rect)
        case .circle: return Circle().path(in: rect)
        case .rounded: return RoundedRectangle(cornerRadius: rect.width * 0.32, style: .continuous).path(in: rect)
        case .square: return RoundedRectangle(cornerRadius: rect.width * 0.06).path(in: rect)
        case .hexagon: return Hexagon().path(in: rect)
        }
    }
}

/// An app icon: either a themed SF Symbol glyph or an imported picture, clipped to the theme's shape.
struct IconTile: View {
    let spec: IconSpec
    var symbol: String = "star.fill"
    var image: UIImage? = nil
    var size: CGFloat = 60

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                if spec.useGradient {
                    LinearGradient(colors: [spec.background.color, spec.background2.color], startPoint: .topLeading, endPoint: .bottomTrailing)
                } else {
                    spec.background.color
                }
                if spec.glass {
                    LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.05)], startPoint: .top, endPoint: .center)
                }
                Image(systemName: symbol)
                    .font(.system(size: size * spec.glyphScale, weight: .semibold))
                    .foregroundStyle(spec.glyph.color)
                    .shadow(color: spec.glyph.color.opacity(spec.showBorder ? 0.5 : 0), radius: size * 0.05)
            }
        }
        .frame(width: size, height: size)
        .clipShape(IconShapeView(shape: spec.shape))
        .overlay(IconShapeView(shape: spec.shape).stroke(spec.glyph.color.opacity(spec.showBorder ? 0.45 : 0), lineWidth: max(1, size * 0.02)))
    }
}
