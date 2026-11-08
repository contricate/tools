import WidgetKit
import SwiftUI
import AppIntents

/// iOS 18 Control Center / Lock Screen / Action button controls.

struct ThemeControlConfig: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "Theme"
    @Parameter(title: "Theme") var theme: ThemeEntity?
    init() {}
}

struct ApplyThemeControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: "aura.control.applyTheme", intent: ThemeControlConfig.self) { config in
            ControlWidgetButton(action: ThemeControlAction(themeID: config.theme?.id ?? "")) {
                Label(config.theme?.name ?? "Next Theme", systemImage: "paintpalette.fill")
            }
        }
        .displayName("Apply Theme")
        .description("Switch to a chosen Aura theme.")
    }
}

struct NextThemeControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "aura.control.nextTheme") {
            ControlWidgetButton(action: NextThemeIntent()) {
                Label("Next Theme", systemImage: "arrow.triangle.2.circlepath")
            }
        }
        .displayName("Next Aura Theme")
    }
}

struct StartIslandControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "aura.control.island") {
            ControlWidgetButton(action: StartIslandIntent()) {
                Label("Aura Island", systemImage: "capsule.fill")
            }
        }
        .displayName("Start Aura Island")
        .description("Shows your themed Dynamic Island design.")
    }
}

struct ChargingScreenControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "aura.control.charging") {
            ControlWidgetButton(action: OpenAuraIntent(screen: .charging)) {
                Label("Charging Screen", systemImage: "bolt.batteryblock.fill")
            }
        }
        .displayName("Aura Charging Screen")
    }
}

