import ActivityKit
import WidgetKit
import SwiftUI

/// The Dynamic Island + Lock Screen presentation of Aura's Live Activity.
struct AuraIslandLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AuraIslandAttributes.self) { context in
            LockScreenIslandView(state: context.state)
                .activityBackgroundTint(context.state.background.color.opacity(0.85))
                .activitySystemActionForegroundColor(context.state.text.color)
        } dynamicIsland: { context in
            let s = context.state
            let battery = BatteryInfo(level: s.batteryLevel, charging: s.charging, full: s.batteryLevel >= 0.999, isEstimate: false)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    IslandSlotView(slot: s.mode == "charging" ? .battery : (s.spec.leading == .none ? .symbol : s.spec.leading),
                                   spec: s.spec, battery: battery, startedAt: s.startedAt, compact: false)
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    IslandSlotView(slot: s.mode == "charging" ? .symbol : (s.spec.trailing == .none ? .clock : s.spec.trailing),
                                   spec: s.mode == "charging" ? chargingSpec(s.spec) : s.spec, battery: battery,
                                   startedAt: s.startedAt, compact: false)
                        .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if s.mode == "charging" {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Charging · \(Int((s.batteryLevel * 100).rounded()))% when started")
                                .font(.caption).foregroundStyle(.secondary)
                            // A progress bar that animates by itself (the only kind of continuous animation iOS allows here).
                            ProgressView(timerInterval: s.startedAt...s.startedAt.addingTimeInterval(120), countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                                .tint(s.spec.tint.color)
                        }
                    } else {
                        VStack(spacing: 2) {
                            Text(s.spec.expandedTitle).font(.headline).foregroundStyle(s.spec.tint.color)
                            if !s.spec.expandedSubtitle.isEmpty {
                                Text(s.spec.expandedSubtitle).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } compactLeading: {
                IslandSlotView(slot: s.mode == "charging" ? .symbol : s.spec.leading,
                               spec: s.mode == "charging" ? chargingSpec(s.spec) : s.spec, battery: battery, startedAt: s.startedAt)
            } compactTrailing: {
                IslandSlotView(slot: s.mode == "charging" ? .battery : s.spec.trailing, spec: s.spec, battery: battery, startedAt: s.startedAt)
            } minimal: {
                IslandSlotView(slot: s.mode == "charging" ? .symbol : s.spec.minimal,
                               spec: s.mode == "charging" ? chargingSpec(s.spec) : s.spec, battery: battery, startedAt: s.startedAt)
            }
            .keylineTint(s.spec.tint.color)
            .widgetURL(URL(string: "aura://island"))
        }
    }

    private func chargingSpec(_ spec: IslandSpec) -> IslandSpec {
        var c = spec
        c.symbol = "bolt.fill"
        return c
    }
}

