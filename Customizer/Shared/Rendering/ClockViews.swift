import SwiftUI

/// Clock in the theme's style for a specific moment (widgets supply one entry per minute).
struct ClockGraphic: View {
    let theme: Theme
    let date: Date
    var size: CGFloat = 60
    var style: ClockStyle? = nil
    var showDate: Bool? = nil

    private var st: ClockStyle { style ?? theme.clock.style }
    private var withDate: Bool { showDate ?? theme.clock.showDate }

    private var hm: (String, String) {
        let cal = Calendar.current
        var h = cal.component(.hour, from: date)
        let m = cal.component(.minute, from: date)
        if !theme.clock.use24h { h = h % 12 == 0 ? 12 : h % 12 }
        return (theme.clock.use24h ? String(format: "%02d", h) : "\(h)", String(format: "%02d", m))
    }

    var body: some View {
        switch st {
        case .digital: digital
        case .stacked: stacked
        case .analog: analog
        case .minimal: minimal
        case .words: words
        }
    }

    private var dateLine: some View {
        Text(date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
            .font(theme.font(size: size * 0.2, weightOverride: 5))
            .foregroundStyle(theme.secondaryText.color)
    }

    private var digital: some View {
        VStack(alignment: .leading, spacing: 0) {
            if withDate { dateLine }
            Text("\(hm.0):\(hm.1)")
                .font(theme.font(size: size))
                .monospacedDigit()
                .tracking(theme.type.tracking)
                .foregroundStyle(theme.text.color)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
    }

    private var stacked: some View {
        VStack(alignment: .leading, spacing: -size * 0.18) {
            Text(hm.0).foregroundStyle(theme.text.color)
            Text(hm.1).foregroundStyle(theme.accent.color)
        }
        .font(theme.font(size: size * 0.95, weightOverride: 8))
        .monospacedDigit()
        .minimumScaleFactor(0.5)
    }

    private var minimal: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(hm.0).\(hm.1)")
                .font(theme.font(size: size * 0.8, weightOverride: 2))
                .tracking(2 + theme.type.tracking)
                .foregroundStyle(theme.text.color)
                .lineLimit(1).minimumScaleFactor(0.5)
            if withDate {
                Text(date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                    .font(theme.font(size: size * 0.16, weightOverride: 5)).tracking(3)
                    .foregroundStyle(theme.secondaryText.color)
            }
        }
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(ClockWords.phrase(for: date))
                .font(theme.font(size: size * 0.38, weightOverride: 6))
                .foregroundStyle(theme.text.color)
                .lineLimit(3)
                .minimumScaleFactor(0.6)
            if withDate { dateLine }
        }
    }

    private var analog: some View {
        let cal = Calendar.current
        let h = Double(cal.component(.hour, from: date) % 12)
        let m = Double(cal.component(.minute, from: date))
        return ZStack {
            Circle().fill(theme.text.color.opacity(0.08))
            Circle().stroke(theme.text.color.opacity(0.3), lineWidth: max(1, size * 0.02))
            ForEach(0..<12, id: \.self) { i in
                Capsule()
                    .fill(theme.text.color.opacity(i % 3 == 0 ? 0.9 : 0.4))
                    .frame(width: max(1, size * 0.025), height: size * (i % 3 == 0 ? 0.1 : 0.06))
                    .offset(y: -size * 0.42)
                    .rotationEffect(.degrees(Double(i) * 30))
            }
            Capsule().fill(theme.text.color)
                .frame(width: size * 0.05, height: size * 0.26)
                .offset(y: -size * 0.13)
                .rotationEffect(.degrees((h + m / 60) * 30))
            Capsule().fill(theme.accent.color)
                .frame(width: size * 0.035, height: size * 0.38)
                .offset(y: -size * 0.19)
                .rotationEffect(.degrees(m * 6))
            Circle().fill(theme.accent.color).frame(width: size * 0.08)
        }
        .frame(width: size, height: size)
    }
}

enum ClockWords {
    static let numbers = ["twelve", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve"]

    /// "quarter past nine", "ten to five", "nine o'clock".
    static func phrase(for date: Date) -> String {
        let cal = Calendar.current
        var h = cal.component(.hour, from: date) % 12
        let m = cal.component(.minute, from: date)
        let rounded = Int((Double(m) / 5).rounded()) * 5
        var next = (h + 1) % 12
        if rounded == 60 { h = next; next = (h + 1) % 12 }
        let hour = numbers[h], nextHour = numbers[next]
        switch rounded % 60 {
        case 0: return "\(hour) o'clock"
        case 15: return "quarter past \(hour)"
        case 30: return "half past \(hour)"
        case 45: return "quarter to \(nextHour)"
        case let x where x < 30: return "\(minuteWord(x)) past \(hour)"
        case let x: return "\(minuteWord(60 - x)) to \(nextHour)"
        }
    }

    private static func minuteWord(_ m: Int) -> String {
        switch m {
        case 5: return "five"
        case 10: return "ten"
        case 20: return "twenty"
        case 25: return "twenty-five"
        default: return "\(m)"
        }
    }
}
