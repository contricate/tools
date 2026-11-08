import Foundation
import SwiftUI
import CoreText
import WidgetKit

/// Storage shared by the app and its widget extension via an App Group.
///
/// Sideloading tools (AltStore/SideStore) rename App Groups and list the new names in the
/// `ALTAppGroups` Info.plist key, so that list is checked first.
enum SharedStore {
    static let defaultGroup = "group.com.aura.customizer"

    static var groupCandidates: [String] {
        let alt = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] ?? []
        return alt + [defaultGroup]
    }

    /// The App Group container, or nil if this build isn't entitled to one.
    static let groupContainer: URL? = {
        for id in groupCandidates {
            if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
                return url
            }
        }
        return nil
    }()

    static var hasAppGroup: Bool { groupContainer != nil }

    static var activeGroupID: String? {
        groupCandidates.first { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) != nil }
    }

    /// Root folder for designs and images (falls back to the app's own Documents folder).
    static var root: URL {
        let base = groupContainer ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("Aura", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var imagesDir: URL { dir("Images") }
    static var fontsDir: URL { dir("Fonts") }
    static var exportsDir: URL { dir("Exports") }

    private static func dir(_ name: String) -> URL {
        let url = root.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var libraryURL: URL { root.appendingPathComponent("library.json") }

    static var defaults: UserDefaults {
        activeGroupID.flatMap { UserDefaults(suiteName: $0) } ?? .standard
    }

    // MARK: Library

    static func load() -> DesignLibrary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: libraryURL),
           let lib = try? decoder.decode(DesignLibrary.self, from: data) {
            return lib
        }
        var lib = DesignLibrary()
        lib.themes = Presets.all
        lib.activeThemeID = Presets.all.first?.id
        lib.widgets = Presets.starterWidgets(themes: Presets.all)
        return lib
    }

    static func save(_ lib: DesignLibrary, reloadWidgets: Bool = true) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(lib) {
            try? data.write(to: libraryURL, options: .atomic)
        }
        if reloadWidgets { WidgetCenter.shared.reloadAllTimelines() }
    }

    // MARK: Images

    /// Saves image data and returns its id. Large photos are downscaled for widget memory limits.
    @discardableResult
    static func saveImage(_ data: Data, maxSide: CGFloat = 1400, id: String = UUID().uuidString, keepPNG: Bool = false) -> String? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = !keepPNG
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        let out = keepPNG ? resized.pngData() : resized.jpegData(compressionQuality: 0.85)
        guard let out else { return nil }
        let url = imagesDir.appendingPathComponent(id)
        do { try out.write(to: url, options: .atomic) } catch { return nil }
        return id
    }

    static func imageURL(_ id: String) -> URL { imagesDir.appendingPathComponent(id) }

    static func image(_ id: String?) -> UIImage? {
        guard let id, !id.isEmpty else { return nil }
        return UIImage(contentsOfFile: imageURL(id).path)
    }

    /// A small version for places with tight memory limits (Live Activities, widget thumbnails).
    static func thumbnail(_ id: String?, maxSide: CGFloat) -> UIImage? {
        guard let img = image(id) else { return nil }
        let scale = min(1, maxSide / max(img.size.width, img.size.height))
        guard scale < 1 else { return img }
        return img.preparingThumbnail(of: CGSize(width: img.size.width * scale, height: img.size.height * scale))
    }

    static func deleteImage(_ id: String?) {
        guard let id else { return }
        try? FileManager.default.removeItem(at: imageURL(id))
    }

    // MARK: Battery snapshot (written by the app, read by widgets as a fallback)

    static func storeBattery(level: Float, state: UIDevice.BatteryState) {
        defaults.set(Double(level), forKey: "battery.level")
        defaults.set(state.rawValue, forKey: "battery.state")
        defaults.set(Date().timeIntervalSince1970, forKey: "battery.time")
    }

    static func storedBattery() -> (level: Double, charging: Bool, at: Date)? {
        let t = defaults.double(forKey: "battery.time")
        guard t > 0 else { return nil }
        let state = UIDevice.BatteryState(rawValue: defaults.integer(forKey: "battery.state")) ?? .unknown
        return (defaults.double(forKey: "battery.level"), state == .charging || state == .full, Date(timeIntervalSince1970: t))
    }
}

/// Current battery level/state. Works in the app and in widget extensions on a real device.
struct BatteryInfo: Equatable {
    var level: Double      // 0…1
    var charging: Bool
    var full: Bool
    var isEstimate: Bool   // true when the system didn't report a value (e.g. simulator)

    static func current() -> BatteryInfo {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        let level = device.batteryLevel
        let state = device.batteryState
        if level >= 0 {
            return BatteryInfo(level: Double(level), charging: state == .charging, full: state == .full, isEstimate: false)
        }
        if let s = SharedStore.storedBattery() {
            return BatteryInfo(level: s.level, charging: s.charging, full: s.level >= 0.999, isEstimate: true)
        }
        return BatteryInfo(level: 0.76, charging: false, full: false, isEstimate: true)
    }

    static let preview = BatteryInfo(level: 0.76, charging: false, full: false, isEstimate: true)
}

/// Registers fonts the user imported so both app and widgets can render them.
enum FontRegistry {
    private static var registered = Set<String>()

    static func registerAll() {
        let urls = (try? FileManager.default.contentsOfDirectory(at: SharedStore.fontsDir, includingPropertiesForKeys: nil)) ?? []
        for url in urls where !registered.contains(url.lastPathComponent) {
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            registered.insert(url.lastPathComponent)
        }
    }

    /// Copies a font file into shared storage and returns its PostScript names.
    static func importFont(from url: URL) throws -> [String] {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let dest = SharedStore.fontsDir.appendingPathComponent(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: dest.path) { try FileManager.default.removeItem(at: dest) }
        try FileManager.default.copyItem(at: url, to: dest)
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(dest as CFURL) as? [CTFontDescriptor], !descriptors.isEmpty else {
            try? FileManager.default.removeItem(at: dest)
            throw CocoaError(.fileReadCorruptFile)
        }
        registerAll()
        return descriptors.compactMap { CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String }
    }

    static func importedFontNames() -> [String] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: SharedStore.fontsDir, includingPropertiesForKeys: nil)) ?? []
        return urls.flatMap { url -> [String] in
            guard let d = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] else { return [] }
            return d.compactMap { CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String }
        }
    }
}

extension Theme {
    func font(size: CGFloat, weightOverride: Int? = nil) -> Font {
        let w = Self.fontWeight(weightOverride ?? type.weight)
        switch type.design {
        case .custom:
            if let name = type.customFontName {
                FontRegistry.registerAll()
                return .custom(name, size: size)
            }
            return .system(size: size, weight: w, design: .rounded)
        case .standard: return .system(size: size, weight: w, design: .default)
        case .rounded: return .system(size: size, weight: w, design: .rounded)
        case .serif: return .system(size: size, weight: w, design: .serif)
        case .mono: return .system(size: size, weight: w, design: .monospaced)
        }
    }

    static func fontWeight(_ v: Int) -> Font.Weight {
        switch v {
        case ...1: return .ultraLight
        case 2: return .thin
        case 3: return .light
        case 4: return .regular
        case 5: return .medium
        case 6: return .semibold
        case 7: return .bold
        case 8: return .heavy
        default: return .black
        }
    }

    func batteryRGBA(_ b: BatteryInfo) -> RGBA {
        if b.charging { return battery.chargingColor }
        if b.full || b.level >= 0.995 { return battery.fullColor }
        if b.level <= battery.lowThreshold { return battery.lowColor }
        return battery.normalColor
    }

    func batteryColor(_ b: BatteryInfo) -> Color { batteryRGBA(b).color }
}
