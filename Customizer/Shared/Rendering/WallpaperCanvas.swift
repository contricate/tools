import SwiftUI

/// iPhone 16 screen geometry in points (the 6.1" model: 393 × 852 pt, rendered at 3×).
enum DeviceGeometry {
    static let screen = CGSize(width: 393, height: 852)
    static let scale: CGFloat = 3
    static let cornerRadius: CGFloat = 55
    /// Approximate Dynamic Island cut-out position on iPhone 16.
    static let island = CGRect(x: (393 - 125) / 2, y: 11, width: 125, height: 37)
    static var pixelSize: CGSize { CGSize(width: screen.width * scale, height: screen.height * scale) }
}

enum WallpaperVariant: String, CaseIterable, Identifiable {
    case lock, home
    var id: String { rawValue }
    var label: String { self == .lock ? "Lock Screen" : "Home Screen" }
}

/// A full-screen wallpaper for the theme, with optional decorations around the Dynamic Island.
struct WallpaperCanvas: View {
    let theme: Theme
    var variant: WallpaperVariant = .lock

    var body: some View {
        let w = theme.wallpaper
        let island = DeviceGeometry.island.offsetBy(dx: 0, dy: w.islandOffsetY)
        let color = w.decorationColor.color
        ZStack(alignment: .topLeading) {
            ThemeBackground(spec: theme.background, photoMaxSide: 2600)
                .blur(radius: variant == .home ? w.homeBlur : 0)
            if variant == .home && w.homeDim > 0 { Color.black.opacity(w.homeDim) }

            switch w.decoration {
            case .none:
                EmptyView()
            case .islandHalo:
                let halo = island.insetBy(dx: -6 - w.decorationWidth, dy: -6 - w.decorationWidth)
                Capsule()
                    .stroke(color, lineWidth: w.decorationWidth)
                    .frame(width: halo.width, height: halo.height)
                    .shadow(color: color.opacity(w.decorationGlow), radius: 10)
                    .shadow(color: color.opacity(w.decorationGlow * 0.6), radius: 22)
                    .offset(x: halo.minX, y: halo.minY)
            case .islandWings:
                let y = island.midY
                ForEach([true, false], id: \.self) { left in
                    let length: CGFloat = 92
                    Capsule()
                        .fill(LinearGradient(colors: left ? [color.opacity(0), color] : [color, color.opacity(0)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: length, height: w.decorationWidth)
                        .shadow(color: color.opacity(w.decorationGlow), radius: 8)
                        .offset(x: left ? island.minX - length - 8 : island.maxX + 8, y: y - w.decorationWidth / 2)
                }
            case .statusBand:
                LinearGradient(colors: [color.opacity(0.55 * max(0.3, w.decorationGlow)), color.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(width: DeviceGeometry.screen.width, height: 120)
            case .topFrame:
                RoundedRectangle(cornerRadius: DeviceGeometry.cornerRadius - 6, style: .continuous)
                    .stroke(color, lineWidth: w.decorationWidth)
                    .shadow(color: color.opacity(w.decorationGlow), radius: 10)
                    .padding(6)
                    .frame(width: DeviceGeometry.screen.width, height: DeviceGeometry.screen.height)
            }

            if !w.overlayText.isEmpty {
                Text(w.overlayText)
                    .font(theme.font(size: 30))
                    .tracking(theme.type.tracking)
                    .foregroundStyle(theme.text.color.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .frame(width: DeviceGeometry.screen.width - 60)
                    .offset(x: 30, y: variant == .lock ? DeviceGeometry.screen.height * 0.72 : DeviceGeometry.screen.height * 0.45)
            }
        }
        .frame(width: DeviceGeometry.screen.width, height: DeviceGeometry.screen.height, alignment: .topLeading)
        .clipped()
    }
}

/// A contact-poster style portrait with a name in the theme's type.
struct PosterCanvas: View {
    let theme: Theme
    let name: String
    var photoID: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            if let img = SharedStore.thumbnail(photoID, maxSide: 2600) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: DeviceGeometry.screen.width, height: DeviceGeometry.screen.height).clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
            } else {
                ThemeBackground(spec: theme.background, photoMaxSide: 2600)
            }
            Text(name)
                .font(theme.font(size: 64, weightOverride: 8))
                .tracking(theme.type.tracking)
                .foregroundStyle(theme.text.color)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.4)
                .lineLimit(2)
                .padding(.horizontal, 24)
                .padding(.bottom, 120)
        }
        .frame(width: DeviceGeometry.screen.width, height: DeviceGeometry.screen.height)
        .clipped()
    }
}
