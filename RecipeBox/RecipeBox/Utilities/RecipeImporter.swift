import Foundation

struct ImportedRecipe {
    var title = ""
    var summary = ""
    var category = "Dinner"
    var servings = 0
    var prepMinutes = 0
    var cookMinutes = 0
    var ingredients: [String] = []
    var steps: [String] = []
    var sourceURL = ""
    var photoData: Data?
    var imageURL: String?
}

enum RecipeImportError: LocalizedError {
    case badURL
    case noRecipe
    case network(String)

    var errorDescription: String? {
        switch self {
        case .badURL: return "That doesn't look like a valid web link."
        case .noRecipe: return "Couldn't find a recipe on that page. Try the page that shows the full recipe."
        case .network(let msg): return "Couldn't load the page: \(msg)"
        }
    }
}

/// Reads recipes from web pages using the schema.org "Recipe" data that most recipe sites include.
enum RecipeImporter {
    static func fetch(_ input: String) async throws -> ImportedRecipe {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.lowercased().hasPrefix("http") { text = "https://" + text }
        guard let url = URL(string: text), url.host != nil else { throw RecipeImportError.badURL }

        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(for: request)
        } catch {
            throw RecipeImportError.network(error.localizedDescription)
        }
        let html = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        guard var recipe = parse(html: html) else { throw RecipeImportError.noRecipe }
        recipe.sourceURL = url.absoluteString

        if let imageURL = recipe.imageURL, let iurl = URL(string: imageURL, relativeTo: url) {
            if let (imgData, _) = try? await URLSession.shared.data(from: iurl.absoluteURL) {
                recipe.photoData = ImageUtil.downscaledJPEG(imgData)
            }
        }
        return recipe
    }

    static func parse(html: String) -> ImportedRecipe? {
        guard let regex = try? NSRegularExpression(
            pattern: #"<script[^>]*application/ld\+json[^>]*>(.*?)</script>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return nil }
        let ns = html as NSString
        for match in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            let jsonText = ns.substring(with: match.range(at: 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let jsonData = jsonText.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: jsonData, options: [.fragmentsAllowed]),
                  let dict = findRecipe(in: obj, depth: 0) else { continue }
            return build(from: dict)
        }
        return nil
    }

    /// Reads a schema.org Recipe from an already-parsed JSON object (e.g. a .json recipe file).
    static func recipe(fromJSONObject obj: Any) -> ImportedRecipe? {
        findRecipe(in: obj, depth: 0).map(build)
    }

    private static func isRecipeType(_ t: Any?) -> Bool {
        if let s = t as? String { return s.lowercased() == "recipe" }
        if let a = t as? [Any] { return a.contains { ($0 as? String)?.lowercased() == "recipe" } }
        return false
    }

    private static func findRecipe(in obj: Any, depth: Int) -> [String: Any]? {
        guard depth < 8 else { return nil }
        if let d = obj as? [String: Any] {
            if isRecipeType(d["@type"]) { return d }
            for (_, v) in d {
                if v is [String: Any] || v is [Any], let found = findRecipe(in: v, depth: depth + 1) { return found }
            }
        } else if let a = obj as? [Any] {
            for v in a { if let found = findRecipe(in: v, depth: depth + 1) { return found } }
        }
        return nil
    }

    private static func build(from d: [String: Any]) -> ImportedRecipe {
        var r = ImportedRecipe()
        r.title = clean(d["name"] as? String ?? "Imported Recipe")
        r.summary = clean(d["description"] as? String ?? "")
        if r.summary.count > 300 { r.summary = String(r.summary.prefix(297)) + "…" }
        r.ingredients = strings(d["recipeIngredient"] ?? d["ingredients"]).map(clean).filter { !$0.isEmpty }
        r.steps = instructions(d["recipeInstructions"]).map(clean).filter { !$0.isEmpty }
        r.servings = yield(d["recipeYield"]) ?? 0
        r.prepMinutes = minutes(d["prepTime"] as? String)
        r.cookMinutes = minutes(d["cookTime"] as? String)
        if r.prepMinutes == 0 && r.cookMinutes == 0 {
            r.cookMinutes = minutes(d["totalTime"] as? String)
        }
        r.category = category(from: strings(d["recipeCategory"]).joined(separator: " ") + " " + r.title)
        r.imageURL = image(d["image"])
        return r
    }

    private static func strings(_ any: Any?) -> [String] {
        if let s = any as? String { return [s] }
        if let a = any as? [Any] { return a.flatMap { strings($0) } }
        return []
    }

    private static func instructions(_ any: Any?) -> [String] {
        if let s = any as? String {
            return s.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        if let a = any as? [Any] { return a.flatMap { instructions($0) } }
        if let d = any as? [String: Any] {
            if let items = d["itemListElement"] { return instructions(items) }
            if let t = d["text"] as? String { return [t] }
            if let n = d["name"] as? String { return [n] }
        }
        return []
    }

    private static func yield(_ any: Any?) -> Int? {
        if let n = any as? Int { return n > 0 ? n : nil }
        if let n = any as? Double { return n > 0 ? Int(n) : nil }
        if let a = any as? [Any] {
            for v in a { if let y = yield(v) { return y } }
            return nil
        }
        if let s = any as? String {
            let digits = s.split(whereSeparator: { !$0.isNumber })
            if let first = digits.first, let n = Int(first), n > 0, n < 500 { return n }
        }
        return nil
    }

    /// Parses ISO 8601 durations like "PT1H30M".
    static func minutes(_ iso: String?) -> Int {
        guard let iso = iso?.uppercased(), iso.hasPrefix("P") else { return 0 }
        var total = 0.0
        var number = ""
        var inTime = false
        for ch in iso.dropFirst() {
            if ch == "T" { inTime = true; continue }
            if ch.isNumber || ch == "." { number.append(ch); continue }
            let v = Double(number) ?? 0
            number = ""
            switch ch {
            case "D": total += v * 1440
            case "H": total += v * 60
            case "M": if inTime { total += v }
            case "S": total += v / 60
            default: break
            }
        }
        return Int(total.rounded())
    }

    private static func image(_ any: Any?) -> String? {
        if let s = any as? String { return s }
        if let a = any as? [Any] { return a.lazy.compactMap { image($0) }.first }
        if let d = any as? [String: Any] { return (d["url"] as? String) ?? (d["contentUrl"] as? String) }
        return nil
    }

    private static func category(from text: String) -> String {
        let t = text.lowercased()
        let map: [(String, [String])] = [
            ("Breakfast", ["breakfast", "brunch", "pancake", "waffle", "omelet"]),
            ("Dessert", ["dessert", "cake", "pie", "pudding", "ice cream", "brownie"]),
            ("Baking", ["baking", "bread", "cookie", "muffin", "scone", "biscuit"]),
            ("Drink", ["drink", "beverage", "cocktail", "smoothie", "lemonade"]),
            ("Appetizer", ["appetizer", "starter", "dip"]),
            ("Side", ["side dish", "side", "salad"]),
            ("Snack", ["snack"]),
            ("Lunch", ["lunch", "sandwich", "soup"]),
            ("Dinner", ["dinner", "main", "entree", "entrée"])
        ]
        for (cat, words) in map where words.contains(where: { t.contains($0) }) { return cat }
        return "Dinner"
    }

    static func clean(_ s: String) -> String {
        var out = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities = ["&amp;": "&", "&quot;": "\"", "&#39;": "'", "&#039;": "'", "&apos;": "'",
                        "&lt;": "<", "&gt;": ">", "&nbsp;": " ", "&#8217;": "’", "&#8216;": "‘",
                        "&#8220;": "“", "&#8221;": "”", "&#8211;": "–", "&#8212;": "—", "&frac12;": "½",
                        "&frac14;": "¼", "&frac34;": "¾", "&deg;": "°", "&#176;": "°"]
        for (k, v) in entities { out = out.replacingOccurrences(of: k, with: v) }
        out = out.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
