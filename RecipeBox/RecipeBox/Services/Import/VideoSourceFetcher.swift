import Foundation

/// Everything publicly readable about a link, gathered before analysis.
struct VideoEvidence {
    var platform: VideoPlatform
    var url: URL
    var resolvedURL: URL
    var title = ""
    var creator = ""
    var description = ""
    var transcript = ""
    var transcriptSource = ""
    var imageURLs: [(url: URL, label: String, kind: DraftImage.Kind)] = []
    var linkedURLs: [URL] = []
    /// A full recipe found as structured data on a linked or the given web page.
    var structuredRecipe: ImportedRecipe?
    var structuredRecipeSource = ""
    var blockedReason: String?
    var notes: [String] = []

    var hasText: Bool { !(title + description + transcript).trimmingCharacters(in: .whitespaces).isEmpty }
}

enum HTTP {
    static let safariUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"

    static func get(_ url: URL, accept: String = "*/*", timeout: TimeInterval = 20) async throws -> (Data, HTTPURLResponse) {
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.setValue(safariUA, forHTTPHeaderField: "User-Agent")
        req.setValue(accept, forHTTPHeaderField: "Accept")
        req.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }

    static func json(_ url: URL) async throws -> Any {
        let (data, resp) = try await get(url, accept: "application/json")
        guard (200..<300).contains(resp.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONSerialization.jsonObject(with: data)
    }

    static func html(_ url: URL) async throws -> (String, URL) {
        let (data, resp) = try await get(url, accept: "text/html,application/xhtml+xml")
        guard (200..<400).contains(resp.statusCode) else { throw URLError(.badServerResponse) }
        let s = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        return (s, resp.url ?? url)
    }

    static func image(_ url: URL) async -> Data? {
        guard let (data, resp) = try? await get(url, accept: "image/*"),
              (200..<300).contains(resp.statusCode), data.count > 2000,
              let jpeg = ImageUtil.downscaledJPEG(data, maxSide: 1280) else { return nil }
        return jpeg
    }

    static func encode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&=?+"))) ?? s
    }
}

/// Reads <meta property="og:..."> and similar tags.
enum MetaTags {
    static func parse(_ html: String) -> [String: String] {
        var out: [String: String] = [:]
        guard let tagRegex = try? NSRegularExpression(pattern: #"<meta\s+[^>]*>"#, options: [.caseInsensitive]) else { return out }
        let ns = html as NSString
        for m in tagRegex.matches(in: html, range: NSRange(location: 0, length: min(ns.length, 400_000))) {
            let tag = ns.substring(with: m.range)
            guard let key = attr("property", tag) ?? attr("name", tag), let content = attr("content", tag) else { continue }
            let k = key.lowercased()
            if out[k] == nil { out[k] = RecipeImporter.clean(content) }
        }
        return out
    }

    private static func attr(_ name: String, _ tag: String) -> String? {
        guard let r = try? NSRegularExpression(pattern: "\(name)\\s*=\\s*(\"([^\"]*)\"|'([^']*)')", options: [.caseInsensitive]) else { return nil }
        let ns = tag as NSString
        guard let m = r.firstMatch(in: tag, range: NSRange(location: 0, length: ns.length)) else { return nil }
        for i in [2, 3] where m.range(at: i).location != NSNotFound { return ns.substring(with: m.range(at: i)) }
        return nil
    }

    /// Instagram/Facebook descriptions look like `123 likes, 4 comments - user on May 1: "caption"`.
    static func captionFromSocialDescription(_ desc: String) -> String {
        if let start = desc.range(of: ": \u{201C}") ?? desc.range(of: ": \"") {
            var cap = String(desc[start.upperBound...])
            if cap.hasSuffix("\u{201D}") || cap.hasSuffix("\"") { cap.removeLast() }
            if cap.hasSuffix("\u{201D}.") || cap.hasSuffix("\".") { cap.removeLast(2) }
            return cap
        }
        return desc
    }
}

enum VideoSourceFetcher {
    struct Options {
        var fetchCaptions = true
        var followLinks = true
    }

    static func fetch(_ url: URL, options: Options, progress: @escaping (String) -> Void) async -> VideoEvidence {
        let platform = VideoPlatform.detect(url)
        var ev = VideoEvidence(platform: platform, url: url, resolvedURL: url)
        switch platform {
        case .youtube, .youtubeShorts: await youtube(&ev, options: options, progress: progress)
        case .tiktok: await tiktok(&ev, progress: progress)
        case .vimeo: await vimeo(&ev, progress: progress)
        case .reddit: await reddit(&ev, progress: progress)
        case .website: await website(&ev, progress: progress)
        case .instagram, .facebook, .pinterest, .x: await openGraph(&ev, progress: progress)
        }

        if options.followLinks && ev.structuredRecipe == nil {
            await followLinks(&ev, progress: progress)
        }
        return ev
    }

    // MARK: YouTube

    private static func youtube(_ ev: inout VideoEvidence, options: Options, progress: (String) -> Void) async {
        guard let id = VideoPlatform.youtubeID(from: ev.url) else {
            ev.blockedReason = "This doesn't look like a link to a single YouTube video."
            return
        }
        let watch = URL(string: "https://www.youtube.com/watch?v=\(id)")!
        progress("Reading YouTube video details")
        if let o = try? await HTTP.json(URL(string: "https://www.youtube.com/oembed?format=json&url=\(HTTP.encode(watch.absoluteString))")!) as? [String: Any] {
            ev.title = o["title"] as? String ?? ""
            ev.creator = o["author_name"] as? String ?? ""
        }
        for name in ["maxresdefault", "hqdefault"] {
            if let u = URL(string: "https://i.ytimg.com/vi/\(id)/\(name).jpg") {
                ev.imageURLs.append((u, "Video thumbnail", .thumbnail))
            }
        }
        for (i, name) in ["hq1", "hq2", "hq3"].enumerated() {
            if let u = URL(string: "https://i.ytimg.com/vi/\(id)/\(name).jpg") {
                ev.imageURLs.append((u, "Video frame \(i + 1) (YouTube still)", .frame))
            }
        }

        progress("Reading the video description")
        guard let (html, _) = try? await HTTP.html(watch),
              let player = extractJSON(after: "ytInitialPlayerResponse = ", in: html) else {
            ev.notes.append("YouTube's page couldn't be read, so only the title was used.")
            return
        }
        if let details = player["videoDetails"] as? [String: Any] {
            if ev.title.isEmpty { ev.title = details["title"] as? String ?? "" }
            if ev.creator.isEmpty { ev.creator = details["author"] as? String ?? "" }
            ev.description = details["shortDescription"] as? String ?? ""
        }
        if (player["playabilityStatus"] as? [String: Any])?["status"] as? String == "LOGIN_REQUIRED" {
            ev.notes.append("YouTube requires sign-in for this video; only public details were used.")
        }

        guard options.fetchCaptions else { return }
        progress("Looking for captions")
        let tracks = (((player["captions"] as? [String: Any])?["playerCaptionsTracklistRenderer"] as? [String: Any])?["captionTracks"] as? [[String: Any]]) ?? []
        if tracks.isEmpty {
            ev.notes.append("This video has no public captions.")
            return
        }
        func score(_ t: [String: Any]) -> Int {
            let lang = (t["languageCode"] as? String ?? "").lowercased()
            let auto = (t["kind"] as? String) == "asr"
            return (lang.hasPrefix("en") ? 10 : 0) + (auto ? 0 : 5)
        }
        let best = tracks.max { score($0) < score($1) }!
        guard let base = best["baseUrl"] as? String, let capURL = URL(string: base + "&fmt=json3") else { return }
        if let obj = try? await HTTP.json(capURL) as? [String: Any],
           let events = obj["events"] as? [[String: Any]] {
            let text = events.compactMap { e -> String? in
                (e["segs"] as? [[String: Any]])?.compactMap { $0["utf8"] as? String }.joined()
            }.joined(separator: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "  ", with: " ")
                .trimmingCharacters(in: .whitespaces)
            if text.count > 20 {
                ev.transcript = String(text.prefix(30_000))
                let lang = best["languageCode"] as? String ?? ""
                ev.transcriptSource = (best["kind"] as? String) == "asr" ? "YouTube auto-generated captions (\(lang))" : "YouTube captions (\(lang))"
                return
            }
        }
        ev.notes.append("Captions exist but YouTube didn't allow them to be downloaded.")
    }

    /// Extracts a balanced JSON object that follows a marker in page source.
    static func extractJSON(after marker: String, in html: String) -> [String: Any]? {
        guard let r = html.range(of: marker) else { return nil }
        var depth = 0
        var inString = false
        var escaped = false
        var end: String.Index?
        let start = r.upperBound
        guard start < html.endIndex, html[start] == "{" else { return nil }
        var i = start
        while i < html.endIndex {
            let c = html[i]
            if inString {
                if escaped { escaped = false }
                else if c == "\\" { escaped = true }
                else if c == "\"" { inString = false }
            } else {
                if c == "\"" { inString = true }
                else if c == "{" { depth += 1 }
                else if c == "}" {
                    depth -= 1
                    if depth == 0 { end = i; break }
                }
            }
            i = html.index(after: i)
        }
        guard let end else { return nil }
        let json = String(html[start...end])
        return (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any]
    }

    // MARK: TikTok

    private static func tiktok(_ ev: inout VideoEvidence, progress: (String) -> Void) async {
        progress("Resolving TikTok link")
        // Short links (vm.tiktok.com) redirect to the full video URL.
        if let (_, resp) = try? await HTTP.get(ev.url, accept: "text/html"), let final = resp.url {
            ev.resolvedURL = final
        }
        progress("Reading TikTok caption")
        let api = URL(string: "https://www.tiktok.com/oembed?url=\(HTTP.encode(ev.resolvedURL.absoluteString))")!
        guard let o = try? await HTTP.json(api) as? [String: Any], o["title"] != nil || o["author_name"] != nil else {
            ev.blockedReason = "TikTok didn't return details for this video. It may be private, deleted, or region-restricted."
            return
        }
        ev.description = o["title"] as? String ?? ""
        ev.creator = o["author_name"] as? String ?? ""
        ev.title = firstLine(ev.description)
        if let t = o["thumbnail_url"] as? String, let u = URL(string: t) {
            ev.imageURLs.append((u, "Video cover image", .thumbnail))
        }
        ev.notes.append("TikTok doesn't offer public transcripts. If the recipe is only spoken, add the video file or screenshots.")
    }

    // MARK: Vimeo

    private static func vimeo(_ ev: inout VideoEvidence, progress: (String) -> Void) async {
        progress("Reading Vimeo details")
        let api = URL(string: "https://vimeo.com/api/oembed.json?url=\(HTTP.encode(ev.url.absoluteString))")!
        guard let o = try? await HTTP.json(api) as? [String: Any] else {
            ev.blockedReason = "Vimeo didn't return details for this video (it may be private)."
            return
        }
        ev.title = o["title"] as? String ?? ""
        ev.creator = o["author_name"] as? String ?? ""
        ev.description = RecipeImporter.clean(o["description"] as? String ?? "")
        if let t = o["thumbnail_url"] as? String, let u = URL(string: t) {
            ev.imageURLs.append((u, "Video thumbnail", .thumbnail))
        }
    }

    // MARK: Reddit

    private static func reddit(_ ev: inout VideoEvidence, progress: (String) -> Void) async {
        progress("Reading Reddit post")
        if let (_, resp) = try? await HTTP.get(ev.url, accept: "text/html"), let final = resp.url { ev.resolvedURL = final }
        var comps = URLComponents(url: ev.resolvedURL, resolvingAgainstBaseURL: false)
        comps?.query = nil
        var path = comps?.path ?? ""
        while path.hasSuffix("/") { path.removeLast() }
        comps?.path = path + ".json"
        guard let jsonURL = comps?.url,
              let arr = try? await HTTP.json(jsonURL) as? [[String: Any]],
              let post = (((arr.first?["data"] as? [String: Any])?["children"] as? [[String: Any]])?.first?["data"]) as? [String: Any] else {
            await openGraph(&ev, progress: progress)
            return
        }
        ev.title = post["title"] as? String ?? ""
        ev.creator = post["author"] as? String ?? ""
        ev.description = RecipeImporter.clean(post["selftext"] as? String ?? "")
        if let link = post["url"] as? String, let u = URL(string: link), VideoPlatform.detect(u) == .website {
            ev.linkedURLs.append(u)
        }
        if let preview = ((post["preview"] as? [String: Any])?["images"] as? [[String: Any]])?.first,
           let src = (preview["source"] as? [String: Any])?["url"] as? String,
           let u = URL(string: src.replacingOccurrences(of: "&amp;", with: "&")) {
            ev.imageURLs.append((u, "Post image", .thumbnail))
        }
        // The top comments often contain the recipe ("recipe in comments").
        if arr.count > 1, let comments = ((arr[1]["data"] as? [String: Any])?["children"] as? [[String: Any]]) {
            let op = ev.creator
            let opComments = comments.compactMap { $0["data"] as? [String: Any] }
                .filter { ($0["author"] as? String) == op }
                .compactMap { $0["body"] as? String }
            if !opComments.isEmpty {
                ev.description += "\n\nComment by the original poster:\n" + opComments.joined(separator: "\n\n")
            }
        }
    }

    // MARK: Websites

    private static func website(_ ev: inout VideoEvidence, progress: (String) -> Void) async {
        progress("Reading the web page")
        guard let (html, final) = try? await HTTP.html(ev.url) else {
            ev.blockedReason = "The page couldn't be loaded. Check the link, or the site may block apps."
            return
        }
        ev.resolvedURL = final
        if var r = RecipeImporter.parse(html: html) {
            r.sourceURL = final.absoluteString
            ev.structuredRecipe = r
            ev.structuredRecipeSource = final.host ?? "the page"
            ev.title = r.title
            if let img = r.imageURL, let u = URL(string: img, relativeTo: final) {
                ev.imageURLs.append((u.absoluteURL, "Photo from \(final.host ?? "the recipe page")", .sourcePhoto))
            }
            return
        }
        applyMeta(MetaTags.parse(html), to: &ev, base: final)
        ev.description += "\n" + visibleText(html).prefix(12_000)
    }

    // MARK: Instagram / Facebook / Pinterest / X

    private static func openGraph(_ ev: inout VideoEvidence, progress: (String) -> Void) async {
        progress("Reading \(ev.platform.rawValue) preview")
        guard let (html, final) = try? await HTTP.html(ev.url) else {
            ev.blockedReason = "\(ev.platform.rawValue) didn't allow this post to be read without logging in."
            return
        }
        ev.resolvedURL = final
        let meta = MetaTags.parse(html)
        let loginWall = final.path.contains("login") || final.path.contains("accounts") ||
            (meta["og:description"] == nil && meta["description"] == nil)
        if loginWall {
            ev.blockedReason = "\(ev.platform.rawValue) requires login to view this post's caption, so the app can't read it."
            return
        }
        applyMeta(meta, to: &ev, base: final)
        if ev.platform == .instagram || ev.platform == .facebook {
            ev.description = MetaTags.captionFromSocialDescription(ev.description)
            if ev.description.count < 160 {
                ev.notes.append("\(ev.platform.rawValue) only shares a short preview of the caption publicly; it may be cut off.")
            }
        }
        if ev.platform == .pinterest, let r = try? NSRegularExpression(pattern: #""link"\s*:\s*"(https?:[^"]+)""#) {
            let ns = html as NSString
            for m in r.matches(in: html, range: NSRange(location: 0, length: min(ns.length, 500_000))).prefix(3) {
                let s = ns.substring(with: m.range(at: 1)).replacingOccurrences(of: "\\/", with: "/")
                if let u = URL(string: s), VideoPlatform.detect(u) == .website, !(u.host ?? "").contains("pinterest") {
                    ev.linkedURLs.append(u)
                }
            }
        }
    }

    private static func applyMeta(_ meta: [String: String], to ev: inout VideoEvidence, base: URL) {
        if ev.title.isEmpty { ev.title = meta["og:title"] ?? meta["twitter:title"] ?? "" }
        let desc = meta["og:description"] ?? meta["description"] ?? meta["twitter:description"] ?? ""
        if desc.count > ev.description.count { ev.description = desc }
        if let img = meta["og:image"] ?? meta["twitter:image"], let u = URL(string: img, relativeTo: base) {
            ev.imageURLs.append((u.absoluteURL, "Preview image", .thumbnail))
        }
    }

    /// Strips tags/scripts to get readable page text (used only as extra evidence).
    static func visibleText(_ html: String) -> String {
        var s = html
        for pattern in [#"<script[\s\S]*?</script>"#, #"<style[\s\S]*?</style>"#, #"<nav[\s\S]*?</nav>"#,
                        #"<footer[\s\S]*?</footer>"#, #"<header[\s\S]*?</header>"#] {
            s = s.replacingOccurrences(of: pattern, with: " ", options: [.regularExpression, .caseInsensitive])
        }
        s = s.replacingOccurrences(of: #"<(br|/p|/li|/h\d|/div)[^>]*>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
        s = RecipeImporter.clean(s.replacingOccurrences(of: "\n", with: " ⏎ "))
        return s.replacingOccurrences(of: " ⏎ ", with: "\n").replacingOccurrences(of: "⏎", with: "\n")
    }

    // MARK: Linked recipe pages

    private static func followLinks(_ ev: inout VideoEvidence, progress: (String) -> Void) async {
        let text = ev.description + "\n" + ev.transcript
        var candidates = ev.linkedURLs
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let ns = text as NSString
            for m in detector.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                if let u = m.url, u.scheme?.hasPrefix("http") == true, VideoPlatform.detect(u) == .website {
                    let host = u.host ?? ""
                    let skip = ["linktr.ee", "amzn.to", "amazon.", "bit.ly/shop", "instagram", "patreon", "ltk.", "liketoknow", "spotify", "apple.com"]
                    if !skip.contains(where: { host.contains($0) }) { candidates.append(u) }
                }
            }
        }
        var seen = Set<String>()
        for u in candidates where seen.insert(u.absoluteString).inserted {
            if seen.count > 4 { break }
            progress("Checking linked page \(u.host ?? "")")
            guard let (html, final) = try? await HTTP.html(u), var r = RecipeImporter.parse(html: html) else { continue }
            r.sourceURL = final.absoluteString
            ev.structuredRecipe = r
            ev.structuredRecipeSource = final.host ?? u.absoluteString
            if let img = r.imageURL, let iu = URL(string: img, relativeTo: final) {
                ev.imageURLs.append((iu.absoluteURL, "Photo from the linked recipe (\(final.host ?? ""))", .sourcePhoto))
            }
            return
        }
    }

    static func firstLine(_ s: String) -> String {
        let line = s.split(whereSeparator: \.isNewline).first.map(String.init) ?? s
        let noTags = line.split(separator: " ").filter { !$0.hasPrefix("#") && !$0.hasPrefix("@") }.joined(separator: " ")
        return String(noTags.prefix(90)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
