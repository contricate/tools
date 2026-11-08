import SwiftUI

/// Draws the battery in any of the theme's styles. `size` is the nominal height.
struct BatteryGraphic: View {
    let theme: Theme
    let battery: BatteryInfo
    var size: CGFloat = 60
    var style: BatteryStyle? = nil
    var showLabel: Bool? = nil

    private var s: BatteryStyle { style ?? theme.battery.style }
    private var pct: Int { Int((battery.level * 100).rounded()) }
    private var color: Color { theme.batteryColor(battery) }
    private var label: Bool { showLabel ?? theme.battery.showPercent }

    var body: some View {
        switch s {
        case .ring: ring
        case .bar: bar
        case .pill: pill
        case .liquid: liquid
        case .segments: segments
        case .classic: classic
        case .digits: digits
        case .emoji: emoji
        }
    }

    private var percentText: some View {
        Text("\(pct)%")
            .font(theme.font(size: size * 0.26))
            .monospacedDigit()
            .foregroundStyle(theme.text.color)
    }

    private var bolt: some View {
        Image(systemName: "bolt.fill")
            .font(.system(size: size * 0.22, weight: .bold))
            .foregroundStyle(theme.battery.chargingColor.color)
    }

    private var ring: some View {
        ZStack {
            Circle().stroke(color.opacity(0.22), lineWidth: size * 0.1)
            Circle()
                .trim(from: 0, to: battery.level)
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.6), radius: size * 0.06)
            VStack(spacing: 0) {
                if battery.charging { bolt }
                if label { percentText }
            }
        }
        .frame(width: size, height: size)
    }

    private var bar: some View {
        VStack(alignment: .leading, spacing: size * 0.08) {
            if label {
                HStack(spacing: 4) {
                    percentText
                    if battery.charging { bolt }
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.2))
                    Capsule().fill(color).frame(width: max(geo.size.height, geo.size.width * battery.level))
                }
            }
            .frame(height: size * 0.14)
        }
        .frame(width: size * 2)
    }

    private var pill: some View {
        HStack(spacing: size * 0.08) {
            if battery.charging { bolt }
            Text("\(pct)")
                .font(theme.font(size: size * 0.3, weightOverride: 7))
                .monospacedDigit()
        }
        .foregroundStyle(theme.text.color)
        .padding(.horizontal, size * 0.18)
        .padding(.vertical, size * 0.08)
        .background(
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.25))
                    Capsule().fill(color.opacity(0.85)).frame(width: geo.size.width * battery.level)
                }
            }
        )
        .clipShape(Capsule())
    }

    private var liquid: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .stroke(theme.text.color.opacity(0.35), lineWidth: size * 0.04)
            GeometryReader { geo in
                VStack {
                    Spacer(minLength: 0)
                    WaveShape(phase: battery.level * 10, amplitude: geo.size.height * 0.04)
                        .fill(LinearGradient(colors: [color.opacity(0.95), color.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                        .frame(height: geo.size.height * max(0.06, battery.level))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
            .padding(size * 0.05)
            VStack(spacing: 0) {
                if battery.charging { bolt }
                if label { percentText }
            }
        }
        .frame(width: size * 0.72, height: size)
    }

    private var segments: some View {
        VStack(alignment: .leading, spacing: size * 0.06) {
            HStack(spacing: size * 0.05) {
                ForEach(0..<10, id: \.self) { i in
                    RoundedRectangle(cornerRadius: size * 0.03)
                        .fill(Double(i) < battery.level * 10 ? color : color.opacity(0.15))
                        .frame(width: size * 0.13, height: size * 0.32)
                        .shadow(color: Double(i) < battery.level * 10 ? color.opacity(0.7) : .clear, radius: size * 0.04)
                }
            }
            if label {
                HStack(spacing: 4) { percentText; if battery.charging { bolt } }
            }
        }
    }

    private var classic: some View {
        HStack(spacing: size * 0.08) {
            if label { percentText }
            HStack(spacing: 1) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: size * 0.09, style: .continuous)
                        .stroke(theme.text.color.opacity(0.5), lineWidth: size * 0.03)
                    RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
                        .fill(color)
                        .padding(size * 0.04)
                        .frame(width: max(size * 0.12, size * 0.75 * battery.level))
                    if battery.charging {
                        Image(systemName: "bolt.fill").font(.system(size: size * 0.2, weight: .heavy))
                            .foregroundStyle(theme.text.color).frame(width: size * 0.75)
                    }
                }
                .frame(width: size * 0.75, height: size * 0.38)
                RoundedRectangle(cornerRadius: 1).fill(theme.text.color.opacity(0.5)).frame(width: size * 0.04, height: size * 0.14)
            }
        }
    }

    private var digits: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(pct)").font(theme.font(size: size * 0.8, weightOverride: 8)).monospacedDigit()
                Text("%").font(theme.font(size: size * 0.3))
            }
            .foregroundStyle(color)
            Text(battery.charging ? "Charging" : (battery.level <= theme.battery.lowThreshold ? theme.battery.lowMessage : "Battery"))
                .font(theme.font(size: size * 0.18))
                .foregroundStyle(theme.secondaryText.color)
        }
    }

    private var emoji: some View {
        VStack(spacing: 2) {
            Text(battery.charging ? theme.battery.emojiCharging : (battery.level <= theme.battery.lowThreshold ? theme.battery.emojiLow : theme.battery.emojiFull))
                .font(.system(size: size * 0.6))
            if label { percentText }
        }
    }
}

struct WaveShape: Shape {
    var phase: Double
    var amplitude: CGFloat

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: amplitude))
        let steps = 40
        for i in 0...steps {
            let x = rect.width * CGFloat(i) / CGFloat(steps)
            let y = amplitude + sin(Double(i) / Double(steps) * .pi * 2 + phase) * Double(amplitude)
            p.addLine(to: CGPoint(x: x, y: CGFloat(y)))
        }
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.closeSubpath()
        return p
    }
}
