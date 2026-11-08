import SwiftUI

enum VideoPlatform: String, CaseIterable, Codable {
    case tiktok = "TikTok"
    case instagram = "Instagram"
    case facebook = "Facebook"
    case youtube = "YouTube"
    case youtubeShorts = "YouTube Shorts"
    case vimeo = "Vimeo"
    case pinterest = "Pinterest"
    case reddit = "Reddit"
    case x = "X"
    case website = "Website"

    var icon: String {
        switch self {
        case .tiktok: return "music.note"
        case .instagram: return "camera"
        case .facebook: return "f.square"
        case .youtube, .youtubeShorts: return "play.rectangle.fill"
        case .vimeo: return "play.circle"
        case .pinterest: return "pin"
        case .reddit: return "bubble.left.and.bubble.right"
        case .x: return "xmark"
        case .website: return "globe"
        }
    }

    var color: Color {
        switch self {
        case .tiktok: return .black
        case .instagram: return Color(red: 0.84, green: 0.2, blue: 0.5)
        case .facebook: return Color(red: 0.23, green: 0.35, blue: 0.6)
        case .youtube, .youtubeShorts: return .red
        case .vimeo: return Color(red: 0.1, green: 0.7, blue: 0.9)
        case .pinterest: return Color(red: 0.8, green: 0.1, blue: 0.15)
        case .reddit: return .orange
        case .x: return .gray
        case .website: return .blue
        }
    }

    /// What the app can legitimately read from this platform without logging in.
    var accessNote: String {
        switch self {
        case .youtube, .youtubeShorts:
            return "Title, description, thumbnails and public captions (when the uploader provides them)."
        case .tiktok:
            return "Caption, creator and cover image via TikTok's public embed API."
        case .instagram:
            return "Public preview text and image only. Instagram often requires login — if so, use screenshots or paste the caption."
        case .facebook:
            return "Public preview text only. Most Facebook videos require login — use screenshots or paste the description."
        case .vimeo:
            return "Title, description and thumbnail via Vimeo's public embed API."
        case .pinterest:
            return "Pin description and the recipe page it links to."
        case .reddit:
            return "Post title, text and linked page via Reddit's public JSON."
        case .x:
            return "Public preview text only (X usually requires login)."
        case .website:
            return "Structured recipe data from the page (works with most recipe sites)."
        }
    }

    static func detect(_ url: URL) -> VideoPlatform {
        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()
        func matches(_ domain: String) -> Bool { host == domain || host.hasSuffix("." + domain) }
        if matches("tiktok.com") { return .tiktok }
        if matches("instagram.com") || matches("instagr.am") { return .instagram }
        if matches("facebook.com") || matches("fb.watch") || matches("fb.com") { return .facebook }
        if matches("youtu.be") { return .youtube }
        if matches("youtube.com") || matches("youtube-nocookie.com") {
            return path.hasPrefix("/shorts") ? .youtubeShorts : .youtube
        }
        if matches("vimeo.com") { return .vimeo }
        if host.contains("pinterest.") || matches("pin.it") { return .pinterest }
        if matches("reddit.com") || matches("redd.it") { return .reddit }
        if matches("twitter.com") || matches("x.com") { return .x }
        return .website
    }

    /// YouTube video id from any common URL shape.
    static func youtubeID(from url: URL) -> String? {
        let host = (url.host ?? "").lowercased()
        let parts = url.path.split(separator: "/").map(String.init)
        if host.hasSuffix("youtu.be") { return parts.first }
        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let v = comps.queryItems?.first(where: { $0.name == "v" })?.value { return v }
        if parts.count >= 2, ["shorts", "embed", "live", "v"].contains(parts[0]) { return parts[1] }
        return nil
    }

    /// Normalises a link so the same video is recognised however it was shared.
    static func normalize(_ url: URL) -> String {
        let platform = detect(url)
        if platform == .youtube || platform == .youtubeShorts, let id = youtubeID(from: url) { return "youtube:\(id)" }
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        comps?.query = nil
        comps?.fragment = nil
        comps?.scheme = "https"
        comps?.host = comps?.host?.lowercased().replacingOccurrences(of: "www.", with: "").replacingOccurrences(of: "m.", with: "")
        var s = comps?.string ?? url.absoluteString
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }

    static func cleanURL(from input: String) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        // Pull the first link out of shared text like "Check this out! https://vm.tiktok.com/xyz"
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
           let m = detector.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let url = m.url, url.scheme?.hasPrefix("http") == true {
            return url
        }
        var t = text
        if !t.lowercased().hasPrefix("http") { t = "https://" + t }
        guard let url = URL(string: t), let host = url.host, host.contains(".") else { return nil }
        return url
    }
}
