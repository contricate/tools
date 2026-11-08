import SwiftUI

/// An honest map of iPhone customisation on iOS 18 without jailbreaking.
struct CapabilitiesView: View {
    struct Item: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
    }

    let supported: [Item] = [
        Item(title: "Home Screen widgets", detail: "10 layouts in any theme: clock, battery, status strip, photos, calendar, quotes, countdowns, app launchers, notification-style stacks."),
        Item(title: "Lock Screen widgets", detail: "Battery gauges, clocks, and your own text above the clock (inline slot)."),
        Item(title: "Interactive widgets", detail: "Theme switcher with tappable buttons (iOS 17+)."),
        Item(title: "Dynamic Island & Live Activities", detail: "Your design around the island and on the Lock Screen: clock, battery, emoji, text, symbols, photos, timers."),
        Item(title: "Control Center controls", detail: "Aura buttons in Control Center, on the Lock Screen and on the Action button (iOS 18)."),
        Item(title: "Focus filters", detail: "Different themes per Focus, switched automatically."),
        Item(title: "Shortcuts actions", detail: "Start/stop island, charging island, open charging screen, next/apply theme, get wallpaper."),
        Item(title: "Wallpapers", detail: "Full-resolution iPhone 16 Lock & Home wallpapers with halo/wing designs around the Dynamic Island."),
        Item(title: "Battery level & charging state", detail: "Read through Apple's public battery API for widgets, island and charging screen."),
        Item(title: "Custom fonts", detail: "Imported .ttf/.otf fonts in Aura's widgets, island and wallpapers."),
        Item(title: "Aura's own app icon", detail: "Five alternate icons.")
    ]
    let workarounds: [Item] = [
        Item(title: "Custom icons for other apps", detail: "Install an icon pack as a configuration profile of Web Clips, or use Shortcuts → Add to Home Screen. Icons open apps via their URL schemes."),
        Item(title: "Charging animations", detail: "A Shortcuts automation (“When charger is connected”) opens Aura's full-screen charging screen or shows a charging Dynamic Island."),
        Item(title: "Automatic wallpaper changes", detail: "Shortcuts: “Get Aura Wallpaper” → “Set Wallpaper”, on a schedule or per Focus."),
        Item(title: "Top-of-screen designs", detail: "Halos, wings and bands drawn into the wallpaper around the Dynamic Island, plus Lock Screen text above the clock."),
        Item(title: "App launcher widgets", detail: "Widgets open Aura, which immediately opens the chosen app (iOS doesn't let widgets open other apps directly)."),
        Item(title: "Contact Posters", detail: "Aura makes the poster image; you choose it in Contacts."),
        Item(title: "Ringtones & sounds", detail: "Create in GarageBand and export as a ringtone (see Guides)."),
        Item(title: "Keeping the island on", detail: "Live Activities end after 8 hours; a daily Shortcuts automation restarts it.")
    ]
    let entitlements: [Item] = [
        Item(title: "App Groups (widgets seeing your designs)", detail: "Needs a signing method that keeps App Groups — AltStore/SideStore or a developer account. Sideloadly with a free account may drop them; Aura shows a warning if so."),
        Item(title: "Live Activity updates while closed", detail: "Push updates need the Push Notifications entitlement and a server (paid developer account). Aura updates the island when opened or via Shortcuts instead."),
        Item(title: "Family Controls / Screen Time APIs", detail: "Require special Apple approval; not used."),
        Item(title: "Installing without re-signing", detail: "Free Apple IDs must re-sign every 7 days (AltStore can do this automatically); a paid account lasts a year.")
    ]
    let impossible: [Item] = [
        Item(title: "Replacing the real status bar", detail: "The time, signal, Wi-Fi and battery icons at the top are drawn by iOS. No app can change them."),
        Item(title: "Redesigning the Dynamic Island itself", detail: "Apps can only show Live Activities in it."),
        Item(title: "System-wide fonts or colours", detail: "Settings, Control Center, keyboard and other apps can't be themed."),
        Item(title: "Real battery health or cycle count", detail: "Private to iOS; see Settings → Battery."),
        Item(title: "Signal strength / Wi-Fi bars", detail: "Not available to apps."),
        Item(title: "Directly replacing other apps' icons", detail: "Only the workarounds above."),
        Item(title: "Setting wallpaper or ringtone from an app", detail: "Only through Settings, Photos or Shortcuts."),
        Item(title: "Lock Screen clock font beyond Apple's choices", detail: "Only Apple's built-in styles.")
    ]

    var body: some View {
        List {
            Section {
                Text("Aura is built only on public iOS APIs, so it installs on a normal iPhone 16 and keeps working after updates. Here's exactly what that allows.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            group("Fully supported", "checkmark.seal.fill", .green, supported)
            group("Creative workarounds", "wand.and.stars", .cyan, workarounds)
            group("Needs special entitlements or signing", "key.fill", .orange, entitlements)
            group("Impossible without a jailbreak", "xmark.octagon.fill", .red, impossible)
        }
        .auraScreen()
        .navigationTitle("What's Possible")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func group(_ title: String, _ icon: String, _ color: Color, _ items: [Item]) -> some View {
        Section {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title).font(.subheadline.weight(.semibold))
                    Text(item.detail).font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        } header: {
            Label(title, systemImage: icon).foregroundStyle(color)
        }
    }
}

struct GuidesView: View {
    var body: some View {
        List {
            guide("Install Aura (IPA)", "iphone", [
                "Download Aura.ipa from the GitHub Actions run (Artifacts → Aura-ipa).",
                "Best: AltStore or SideStore — they keep the App Group, so widgets can read your designs. Free Apple ID: re-sign every 7 days (AltStore refreshes automatically).",
                "Sideloadly also works, but with a free account the App Group may not carry over; if Aura shows the App Group warning, widgets will only show presets.",
                "On iPhone: Settings → General → VPN & Device Management → trust your Apple ID, and turn on Developer Mode (Settings → Privacy & Security) when asked.",
                "Requires iOS 18 or later (iPhone 16 ships with iOS 18)."
            ])
            guide("Add widgets", "square.grid.2x2", [
                "Long-press the Home Screen → Edit → Add Widget → search “Aura”.",
                "Pick Aura Design, Battery, Clock or Theme Switcher, choose a size, Add Widget.",
                "Long-press the widget → Edit Widget to choose a design or theme.",
                "Tip: stack several Aura widgets (drop one on another) and turn on Smart Rotate."
            ])
            guide("Home Screen layouts", "rectangle.3.group", [
                "Clean look: in Edit → Customize choose Large icons — iOS 18 hides labels.",
                "Dark/Tinted icons: Edit → Customize → Tinted, then pick your theme's accent colour.",
                "Put matching icon-pack icons on page 1 and move originals to the App Library (long-press → Remove from Home Screen).",
                "Make separate pages for moods and link them to Focus modes (Settings → Focus → Customize Screens)."
            ])
            guide("Custom ringtones & sounds", "music.note", [
                "Get GarageBand (free) and import a song or sound (Files or a recording).",
                "Trim it to under 30 seconds.",
                "My Songs → long-press the project → Share → Ringtone → Export.",
                "Settings → Sounds & Haptics → Ringtone (or Text Tone) → choose it.",
                "Shortcuts can also play a custom sound on charging: add “Play Sound” to the charging automation."
            ])
            guide("Contact Posters", "person.crop.rectangle", [
                "Make one in Studio → Contact Poster and save it to Photos.",
                "Contacts → My Card → Contact Photo & Poster → Edit → + → Photos.",
                "Choose the poster, adjust it, and pick a font/colour for your name."
            ])
            guide("Charging animation", "bolt.fill", [
                "Shortcuts → Automation → + → Charger → Is Connected → Run Immediately.",
                "Add action “Open Aura Charging Screen” (full screen) or “Show Aura Charging Island” (Dynamic Island).",
                "Optional second automation: Charger → Is Disconnected → “Stop Aura Island”."
            ])
            guide("Rotating wallpapers", "photo.on.rectangle.angled", [
                "Shortcuts → Automation → Time of Day (or When Focus turns on).",
                "Add “Next Aura Theme” (optional), then “Get Aura Wallpaper”, then “Set Wallpaper” (choose Lock Screen, Home Screen or both, and turn off Show Preview)."
            ])
            guide("Troubleshooting", "wrench.and.screwdriver", [
                "Widgets show presets only → App Group missing; reinstall with AltStore/SideStore.",
                "Island won't start → Settings → Aura → Live Activities on.",
                "Profile icons don't open an app → that app doesn't support links; use the Shortcuts method for it.",
                "Battery widget lags → iOS limits widget refreshes; opening Aura refreshes them."
            ])
        }
        .auraScreen()
        .navigationTitle("Guides")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func guide(_ title: String, _ icon: String, _ steps: [String]) -> some View {
        Section {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(i + 1)").font(.caption.bold()).frame(width: 22, height: 22).background(Color.accentColor.opacity(0.25), in: Circle())
                            Text(s).font(.subheadline)
                        }
                    }
                }
                .padding(.vertical, 6)
            } label: {
                Label(title, systemImage: icon).font(.headline)
            }
        }
    }
}
