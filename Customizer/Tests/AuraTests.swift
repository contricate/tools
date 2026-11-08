import XCTest
@testable import Aura

final class ModelTests: XCTestCase {
    func testHexRoundTrip() {
        let c = RGBA(hex: "#FF2E88")!
        XCTAssertEqual(c.hex, "#FF2E88")
        XCTAssertEqual(c.r, 1, accuracy: 0.001)
        XCTAssertNil(RGBA(hex: "nope"))
        XCTAssertEqual(RGBA(hex: "00000080")!.a, 128.0 / 255, accuracy: 0.001)
        XCTAssertGreaterThan(RGBA.white.luminance, RGBA.black.luminance)
    }

    func testPresetsAreUniqueAndComplete() {
        let presets = Presets.all
        XCTAssertEqual(presets.count, 10)
        XCTAssertEqual(Set(presets.map(\.id)).count, 10)
        for name in ["Minimalist", "Dark AMOLED", "Gaming", "Neon", "Clean iOS", "Personal Photo"] {
            XCTAssertTrue(presets.contains { $0.name == name }, name)
        }
        // Stable ids so presets aren't duplicated across launches.
        XCTAssertEqual(Presets.all[0].id, Presets.all[0].id)
    }

    func testLibraryCodableRoundTrip() throws {
        var lib = DesignLibrary(themes: Presets.all, widgets: Presets.starterWidgets(themes: Presets.all))
        lib.activeThemeID = Presets.all[2].id
        lib.iconPacks = [IconPack(name: "P", icons: [IconItem(appName: "Spotify", imageID: "x", url: "spotify://")])]
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let back = try dec.decode(DesignLibrary.self, from: enc.encode(lib))
        XCTAssertEqual(back.themes.count, 10)
        XCTAssertEqual(back.widgets.count, lib.widgets.count)
        XCTAssertEqual(back.activeThemeID, lib.activeThemeID)
        XCTAssertEqual(back.iconPacks.first?.icons.first?.url, "spotify://")
    }

    func testFocusOverridesActiveTheme() {
        var lib = DesignLibrary(themes: Presets.all, activeThemeID: Presets.all[0].id)
        XCTAssertEqual(lib.currentTheme.name, "Minimalist")
        lib.focusThemeID = Presets.all[3].id
        XCTAssertEqual(lib.currentTheme.name, "Neon")
        var design = WidgetDesign(name: "w", layout: .clock)
        XCTAssertEqual(lib.resolvedTheme(for: design).name, "Neon")
        design.themeID = Presets.all[1].id
        XCTAssertEqual(lib.resolvedTheme(for: design).name, "Dark AMOLED")
    }

    func testBatteryColours() {
        let t = Presets.amoled
        XCTAssertEqual(t.batteryRGBA(BatteryInfo(level: 0.1, charging: false, full: false, isEstimate: false)), t.battery.lowColor)
        XCTAssertEqual(t.batteryRGBA(BatteryInfo(level: 0.1, charging: true, full: false, isEstimate: false)), t.battery.chargingColor)
        XCTAssertEqual(t.batteryRGBA(BatteryInfo(level: 1, charging: false, full: true, isEstimate: false)), t.battery.fullColor)
        XCTAssertEqual(t.batteryRGBA(BatteryInfo(level: 0.6, charging: false, full: false, isEstimate: false)), t.battery.normalColor)
    }
}

final class FeatureTests: XCTestCase {
    func testIconFileMatching() {
        XCTAssertEqual(AppCatalog.match(fileName: "instagram_icon@3x.png")?.name, "Instagram")
        XCTAssertEqual(AppCatalog.match(fileName: "WhatsApp.png")?.name, "WhatsApp")
        XCTAssertEqual(AppCatalog.match(fileName: "spotify-green-aesthetic.PNG")?.name, "Spotify")
        XCTAssertEqual(AppCatalog.match(fileName: "twitter.png")?.name, "X")
        XCTAssertEqual(AppCatalog.match(fileName: "Google Maps.png")?.name, "Google Maps")
        XCTAssertNil(AppCatalog.match(fileName: "random-flower.png"))
    }

    func testWebClipProfile() throws {
        let data = try XCTUnwrap(WebClipProfile.build(name: "Neon", clips: [
            .init(label: "Spotify", url: "spotify://", iconPNG: Data([1, 2, 3])),
            .init(label: "YouTube", url: "youtube://", iconPNG: Data([4, 5]))
        ]))
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(plist["PayloadType"] as? String, "Configuration")
        let content = try XCTUnwrap(plist["PayloadContent"] as? [[String: Any]])
        XCTAssertEqual(content.count, 2)
        XCTAssertEqual(content[0]["PayloadType"] as? String, "com.apple.webClip.managed")
        XCTAssertEqual(content[0]["URL"] as? String, "spotify://")
        XCTAssertEqual(content[1]["Label"] as? String, "YouTube")
        XCTAssertEqual(content[0]["Icon"] as? Data, Data([1, 2, 3]))
        XCTAssertNotEqual(content[0]["PayloadUUID"] as? String, content[1]["PayloadUUID"] as? String)
    }

    func testClockWords() {
        func at(_ h: Int, _ m: Int) -> Date { Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: h, minute: m))! }
        XCTAssertEqual(ClockWords.phrase(for: at(9, 15)), "quarter past nine")
        XCTAssertEqual(ClockWords.phrase(for: at(9, 40)), "twenty to ten")
        XCTAssertEqual(ClockWords.phrase(for: at(9, 58)), "ten o'clock")
        XCTAssertEqual(ClockWords.phrase(for: at(0, 0)), "twelve o'clock")
        XCTAssertEqual(ClockWords.phrase(for: at(23, 30)), "half past eleven")
    }

    func testLaunchURLRoundTrip() {
        let wrapped = LaunchURL.wrap("spotify://track?id=1&x=2")
        XCTAssertEqual(wrapped.scheme, "aura")
        XCTAssertEqual(LaunchURL.unwrap(wrapped)?.absoluteString, "spotify://track?id=1&x=2")
        XCTAssertEqual(LaunchURL.wrap("aura://open?app=camera").absoluteString, "aura://open?app=camera")
        XCTAssertNil(LaunchURL.unwrap(URL(string: "https://example.com")!))
    }

    func testGradientAngles() {
        let (s, e) = ThemeBackground.points(angle: 90)
        XCTAssertEqual(s.x, 0, accuracy: 0.001); XCTAssertEqual(e.x, 1, accuracy: 0.001)
        let (s2, e2) = ThemeBackground.points(angle: 180)
        XCTAssertEqual(s2.y, 0, accuracy: 0.001); XCTAssertEqual(e2.y, 1, accuracy: 0.001)
    }

    func testBundleRoundTrip() throws {
        var t = Presets.neon
        t.id = UUID(); t.name = "Exported"; t.isPreset = true
        let data = try XCTUnwrap(AuraBundle.make(themes: [t], widgets: [WidgetDesign(name: "W", layout: .quote)], packs: []))
        var lib = DesignLibrary(themes: Presets.all)
        let summary = try AuraBundle.merge(data, into: &lib)
        XCTAssertTrue(summary.contains("1 theme"))
        XCTAssertEqual(lib.themes.count, 11)
        XCTAssertEqual(lib.themes.last?.name, "Exported")
        XCTAssertEqual(lib.themes.last?.isPreset, false, "Imported themes become the user's own")
        // Importing again updates instead of duplicating.
        _ = try AuraBundle.merge(data, into: &lib)
        XCTAssertEqual(lib.themes.count, 11)
    }

    func testIslandGeometryFitsScreen() {
        let r = DeviceGeometry.island
        XCTAssertEqual(r.midX, DeviceGeometry.screen.width / 2, accuracy: 0.5)
        XCTAssertEqual(DeviceGeometry.pixelSize, CGSize(width: 1179, height: 2556))
    }
}
