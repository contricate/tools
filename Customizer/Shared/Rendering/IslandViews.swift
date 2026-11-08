import SwiftUI

/// Renders one Dynamic Island slot (used by the Live Activity and the in-app preview).
struct IslandSlotView: View {
    let slot: IslandSlot
    let spec: IslandSpec
    let battery: BatteryInfo
    var startedAt: Date = .now
    var compact = true

    var body: some View {
        let tint = spec.tint.color
        switch slot {
        case .none:
            Color.clear.frame(width: 1, height: 1)
        case .clock:
            Text(Date.now, style: .time)
                .font(.system(size: compact ? 14 : 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .frame(maxWidth: compact ? 64 : nil)
        case .battery:
            HStack(spacing: 3) {
                if battery.charging { Image(systemName: "bolt.fill").font(.system(size: 10, weight: .bold)) }
                Text("\(Int((battery.level * 100).rounded()))%")
                    .font(.system(size: compact ? 13 : 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(tint)
        case .emoji:
            Text(spec.emoji).font(.system(size: compact ? 16 : 28))
        case .text:
            Text(spec.text)
                .font(.system(size: compact ? 13 : 20, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .frame(maxWidth: compact ? 70 : nil)
        case .symbol:
            Image(systemName: spec.symbol)
                .font(.system(size: compact ? 14 : 24, weight: .semibold))
                .foregroundStyle(tint)
        case .image:
            if let img = SharedStore.thumbnail(spec.imageID, maxSide: 80) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: compact ? 22 : 44, height: compact ? 22 : 44)
                    .clipShape(Circle())
            } else {
                Image(systemName: "photo.circle.fill").foregroundStyle(tint)
            }
        case .timer:
            Text(startedAt, style: .timer)
                .font(.system(size: compact ? 13 : 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .frame(maxWidth: compact ? 56 : nil)
        }
    }
}

/// Lock Screen presentation of the Live Activity (also used for the in-app preview).
struct LockScreenIslandView: View {
    let state: AuraIslandAttributes.ContentState

    var body: some View {
        let battery = BatteryInfo(level: state.batteryLevel, charging: state.charging, full: false, isEstimate: false)
        HStack(spacing: 14) {
            IslandSlotView(slot: state.spec.leading == .none ? .symbol : state.spec.leading, spec: state.spec,
                           battery: battery, startedAt: state.startedAt, compact: false)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.mode == "charging" ? "Charging" : state.spec.expandedTitle)
                    .font(.headline)
                    .foregroundStyle(state.text.color)
                Text(state.mode == "charging" ? "Started at \(Int((state.batteryLevel * 100).rounded()))%" : state.spec.expandedSubtitle)
                    .font(.caption)
                    .foregroundStyle(state.text.color.opacity(0.7))
            }
            Spacer()
            IslandSlotView(slot: state.spec.trailing == .none ? .clock : state.spec.trailing, spec: state.spec,
                           battery: battery, startedAt: state.startedAt, compact: false)
        }
        .padding(16)
    }
}
