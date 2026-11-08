# Aura — iPhone customisation studio (iOS 18+, designed for iPhone 16)

Aura pushes iPhone customisation as far as Apple's public APIs allow — **no jailbreak, no private APIs**. It ships as an app plus a WidgetKit extension that share your designs through an App Group.

## What it does
- **Themes / profiles** — complete looks (wallpaper, widgets, icon style, battery, clock, Dynamic Island, charging screen). 10 presets: Minimalist, Dark AMOLED, Gaming, Neon, Clean iOS, Personal Photo, Sunset, Pastel, Deep Ocean, Forest. Create, duplicate, apply, import/export.
- **Customization Studio** with live previews: background (solid, linear/radial/angular/mesh gradients, photos with blur/dim/saturation/grain), colours, fonts (incl. imported .ttf/.otf), glass, borders, corner radius, clock & battery styles, icon style.
- **Home Screen widgets** — 10 layouts (clock, battery, status strip, photos, calendar, quote, countdown, app launcher, notification stack, clock+battery) in small/medium/large; interactive Theme Switcher.
- **Lock Screen widgets** — battery gauges, clocks (analog, words), custom text above the clock.
- **Dynamic Island** — Live Activity designs (compact left/right, minimal, expanded, Lock Screen) with clock, battery, emoji, text, SF Symbols, photo, elapsed timer; charging mode.
- **Battery** — 8 styles, level-based colours (normal/low/charging/full), low-battery message & emoji, full-screen animated **charging screen** (liquid, ring, neon, orbit, minimal, photo).
- **Wallpapers** — exported at 1179×2556 for iPhone 16, Lock & Home versions, with halos/wings/bands around the Dynamic Island.
- **Icons** — generate a full themed pack, import packs from Files (folders, auto-matched by file name) or Photos, install as Home Screen icons via a Web Clip configuration profile, or save for the Shortcuts method. Aura's own icon has 5 alternates.
- **Control Center / Lock Screen / Action button controls** (iOS 18), **Focus filter** (theme per Focus), **Shortcuts actions** (start/stop island, charging island, charging screen, next/apply theme, get wallpaper).
- **Contact Poster** maker, Lock Screen presets, guides (ringtones, layouts, automations, installation), and an honest **What's Possible** screen.

## Feasibility (summary)
| Category | Examples |
|---|---|
| Fully supported | Widgets (Home, Lock, StandBy, interactive), Live Activities/Dynamic Island, Control Center controls, Focus filters, App Intents/Shortcuts, battery level & state, custom fonts in own UI, alternate app icon |
| Creative workarounds | Other apps' icons (Web Clip profile / Shortcuts), charging animations (automation → app/island), wallpaper automation (Shortcuts "Set Wallpaper"), top-of-screen designs drawn into wallpaper, launcher widgets bouncing through Aura, contact posters, ringtones via GarageBand |
| Needs entitlements / signing | App Groups (widgets reading designs), push-updated Live Activities (Push entitlement + server), Screen Time APIs (Apple approval) |
| Impossible without jailbreak | Replacing the status bar, redesigning the Dynamic Island itself, system-wide theming, battery health/cycle count, signal/Wi-Fi bars, Lock Screen clock fonts beyond Apple's, setting wallpaper/ringtone programmatically |

## Install
1. GitHub → Actions → **Build Aura IPA** → latest run → **Artifacts → Aura-ipa**.
2. Install with **AltStore** or **SideStore** (recommended — they register the App Group so widgets can read your designs). Sideloadly works too, but with a free account the App Group may be dropped; Aura detects this and warns you (widgets then show presets).
3. iPhone: trust your Apple ID (Settings → General → VPN & Device Management) and enable Developer Mode if asked.
4. Free Apple ID: apps expire after 7 days unless refreshed (AltStore refreshes automatically). Free accounts also limit how many app IDs you can register per week; Aura uses two (app + widgets).

### Signing details
- The IPA is ad-hoc signed with its entitlements (`com.apple.security.application-groups: group.com.aura.customizer`) so re-signing tools can see them.
- AltStore/SideStore rename App Groups; Aura reads the `ALTAppGroups` Info.plist key they add, so it keeps working.
- No push, HealthKit, or other restricted entitlements are used.

## Build locally (Mac)
```sh
brew install xcodegen
cd Customizer && xcodegen generate && open Aura.xcodeproj
```
Set your team for both targets and an App Group you own (update `SharedStore.defaultGroup` and both `.entitlements`).

## Tests & CI
`AuraTests` cover colour parsing, presets, library persistence, Focus precedence, battery colour rules, icon-pack file matching, Web Clip profile generation, word clock, launcher URLs, gradients, design import/export and iPhone 16 geometry. CI also launches the app in the iPhone 16 simulator on 11 screens and fails on any crash.
