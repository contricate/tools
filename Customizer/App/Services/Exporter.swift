import SwiftUI
import Photos
import UniformTypeIdentifiers

enum ExportError: LocalizedError {
    case renderFailed, photosDenied
    var errorDescription: String? {
        switch self {
        case .renderFailed: return "The image couldn't be created."
        case .photosDenied: return "Aura doesn't have permission to add photos. Allow it in Settings → Privacy → Photos → Aura."
        }
    }
}

/// Renders designs to full-resolution images and saves/shares them.
@MainActor
enum Exporter {
    static func render<V: View>(_ view: V, scale: CGFloat) -> UIImage? {
        let r = ImageRenderer(content: view)
        r.scale = scale
        r.isOpaque = true
        return r.uiImage
    }

    /// 1179 × 2556 px — the iPhone 16's native resolution.
    static func wallpaperPNG(_ theme: Theme, variant: WallpaperVariant) -> Data? {
        render(WallpaperCanvas(theme: theme, variant: variant), scale: DeviceGeometry.scale)?.pngData()
    }

    static func posterPNG(_ theme: Theme, name: String, photoID: String?) -> Data? {
        render(PosterCanvas(theme: theme, name: name, photoID: photoID), scale: DeviceGeometry.scale)?.pngData()
    }

    static func iconPNG(spec: IconSpec, symbol: String, image: UIImage? = nil, pixels: CGFloat = 512) -> Data? {
        let r = ImageRenderer(content: IconTile(spec: spec, symbol: symbol, image: image, size: pixels / 3))
        r.scale = 3
        r.isOpaque = false
        return r.uiImage?.pngData()
    }

    static func saveToPhotos(_ datas: [Data]) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw ExportError.photosDenied }
        try await PHPhotoLibrary.shared().performChanges {
            for d in datas {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: d, options: nil)
            }
        }
    }

    static func tempFile(_ data: Data, name: String) -> URL {
        let safe = name.components(separatedBy: CharacterSet(charactersIn: "/\\?%*|\"<>:")).joined()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(safe.isEmpty ? "Aura" : safe)
        try? data.write(to: url, options: .atomic)
        return url
    }
}

/// Builds a configuration profile of Web Clips — one Home Screen icon per app, with your custom images.
///
/// Notes: profiles must be installed by the user (Settings → Profile Downloaded). Web Clips that point at
/// another app's URL scheme open that app; behaviour depends on the app supporting its scheme.
enum WebClipProfile {
    struct Clip {
        var label: String
        var url: String
        var iconPNG: Data
    }

    static func build(name: String, clips: [Clip], fullScreen: Bool = true) -> Data? {
        let identifier = "com.aura.customizer.iconpack.\(UUID().uuidString.prefix(8))"
        let payloads: [[String: Any]] = clips.enumerated().map { i, clip in
            [
                "PayloadType": "com.apple.webClip.managed",
                "PayloadVersion": 1,
                "PayloadIdentifier": "\(identifier).clip\(i)",
                "PayloadUUID": UUID().uuidString,
                "PayloadDisplayName": "Icon: \(clip.label)",
                "Label": clip.label,
                "URL": clip.url,
                "Icon": clip.iconPNG,
                "IsRemovable": true,
                "Precomposed": true,
                "FullScreen": fullScreen
            ]
        }
        let profile: [String: Any] = [
            "PayloadType": "Configuration",
            "PayloadVersion": 1,
            "PayloadIdentifier": identifier,
            "PayloadUUID": UUID().uuidString,
            "PayloadDisplayName": "\(name) Icons (Aura)",
            "PayloadDescription": "Adds \(clips.count) custom Home Screen icons made in Aura. Remove anytime in Settings → General → VPN & Device Management.",
            "PayloadOrganization": "Aura",
            "PayloadRemovalDisallowed": false,
            "PayloadContent": payloads
        ]
        return try? PropertyListSerialization.data(fromPropertyList: profile, format: .xml, options: 0)
    }
}

/// A portable bundle of designs + their images (.aura file, JSON).
struct AuraBundle: Codable {
    var version = 1
    var themes: [Theme] = []
    var widgets: [WidgetDesign] = []
    var iconPacks: [IconPack] = []
    var images: [String: Data] = [:]

    static func make(themes: [Theme], widgets: [WidgetDesign], packs: [IconPack]) -> Data? {
        var b = AuraBundle(themes: themes, widgets: widgets, iconPacks: packs)
        var ids = Set<String>()
        for t in themes {
            [t.background.photoID, t.island.imageID, t.charging.photoID].compactMap { $0 }.forEach { ids.insert($0) }
        }
        for w in widgets {
            w.photoIDs.forEach { ids.insert($0) }
            w.links.compactMap(\.imageID).forEach { ids.insert($0) }
        }
        for p in packs { p.icons.forEach { ids.insert($0.imageID) } }
        for id in ids { if let d = try? Data(contentsOf: SharedStore.imageURL(id)) { b.images[id] = d } }
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return try? enc.encode(b)
    }

    /// Merges a bundle into the library. Returns a summary.
    static func merge(_ data: Data, into lib: inout DesignLibrary) throws -> String {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let b = try dec.decode(AuraBundle.self, from: data)
        for (id, d) in b.images where !FileManager.default.fileExists(atPath: SharedStore.imageURL(id).path) {
            try? d.write(to: SharedStore.imageURL(id))
        }
        func upsert<T: Identifiable>(_ items: [T], into list: inout [T]) where T.ID == UUID {
            for item in items {
                if let i = list.firstIndex(where: { $0.id == item.id }) { list[i] = item } else { list.append(item) }
            }
        }
        upsert(b.themes.map { var t = $0; t.isPreset = false; return t }, into: &lib.themes)
        upsert(b.widgets, into: &lib.widgets)
        upsert(b.iconPacks, into: &lib.iconPacks)
        return "Imported \(b.themes.count) theme(s), \(b.widgets.count) widget(s), \(b.iconPacks.count) icon pack(s)"
    }
}

struct AuraFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json, UTType(filenameExtension: "aura") ?? .json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
