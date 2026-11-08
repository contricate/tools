import Foundation

/// Client for TheMealDB's free public API (real recipes with photos). https://www.themealdb.com/api.php
enum MealDB {
    struct Meal: Identifiable, Hashable {
        let id: String
        var name: String
        var thumb: String
        var category = ""
        var area = ""
        var instructions = ""
        var tags: [String] = []
        var youtube = ""
        var source = ""
        var ingredients: [String] = []

        var thumbURL: URL? { URL(string: thumb) }
        var isDetailed: Bool { !ingredients.isEmpty }
    }

    private static let base = "https://www.themealdb.com/api/json/v1/1/"

    private static func meals(_ path: String) async throws -> [Meal] {
        guard let url = URL(string: base + path) else { return [] }
        let obj = try await HTTP.json(url) as? [String: Any]
        guard let arr = obj?["meals"] as? [[String: Any]] else { return [] }
        return arr.compactMap(parse)
    }

    static func parse(_ m: [String: Any]) -> Meal? {
        guard let id = m["idMeal"] as? String, let name = m["strMeal"] as? String else { return nil }
        var meal = Meal(id: id, name: name, thumb: m["strMealThumb"] as? String ?? "")
        meal.category = m["strCategory"] as? String ?? ""
        meal.area = m["strArea"] as? String ?? ""
        meal.instructions = m["strInstructions"] as? String ?? ""
        meal.tags = (m["strTags"] as? String ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        meal.youtube = m["strYoutube"] as? String ?? ""
        meal.source = m["strSource"] as? String ?? ""
        for i in 1...20 {
            let ing = (m["strIngredient\(i)"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            let measure = (m["strMeasure\(i)"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            if !ing.isEmpty { meal.ingredients.append(measure.isEmpty ? ing : "\(measure) \(ing)") }
        }
        return meal
    }

    static func search(_ q: String) async throws -> [Meal] {
        try await meals("search.php?s=\(HTTP.encode(q))")
    }
    static func byCategory(_ c: String) async throws -> [Meal] { try await meals("filter.php?c=\(HTTP.encode(c))") }
    static func byArea(_ a: String) async throws -> [Meal] { try await meals("filter.php?a=\(HTTP.encode(a))") }
    static func byIngredient(_ i: String) async throws -> [Meal] {
        try await meals("filter.php?i=\(HTTP.encode(i.lowercased().replacingOccurrences(of: " ", with: "_")))")
    }
    static func lookup(_ id: String) async throws -> Meal? { try await meals("lookup.php?i=\(id)").first }
    static func random() async throws -> Meal? { try await meals("random.php").first }

    static func areas() async throws -> [String] {
        let obj = try await HTTP.json(URL(string: base + "list.php?a=list")!) as? [String: Any]
        return (obj?["meals"] as? [[String: Any]] ?? []).compactMap { $0["strArea"] as? String }.filter { $0 != "Unknown" }
    }

    static let categories = ["Breakfast", "Chicken", "Beef", "Pasta", "Seafood", "Vegetarian", "Vegan", "Dessert", "Side", "Starter", "Lamb", "Pork", "Goat", "Miscellaneous"]

    /// Searches by each meaningful word too, since TheMealDB matches names only.
    static func fuzzySearch(_ query: String) async -> [Meal] {
        var results: [Meal] = []
        if let r = try? await search(query) { results += r }
        if results.count < 3 {
            let stop: Set<String> = ["the", "best", "easy", "recipe", "with", "and", "how", "make", "to", "my", "homemade", "quick", "simple", "of", "a"]
            for w in query.lowercased().split(separator: " ").map(String.init) where w.count > 3 && !stop.contains(w) {
                if let r = try? await search(w) { results += r }
                if results.count >= 8 { break }
            }
        }
        var seen = Set<String>()
        return results.filter { seen.insert($0.id).inserted }
    }

    static func draft(from meal: Meal) async -> RecipeDraft {
        var full = meal
        if !meal.isDetailed, let m = try? await lookup(meal.id) { full = m }
        var d = RecipeDraft()
        d.title = full.name
        d.summary = [full.area, full.category].filter { !$0.isEmpty }.joined(separator: " · ")
        d.cuisine = full.area
        d.category = mapCategory(full.category)
        d.ingredients = full.ingredients.map { DraftLine(text: $0, status: .confirmed) }
        d.steps = splitInstructions(full.instructions).map { DraftLine(text: $0, status: .confirmed) }
        d.sourceURL = full.source.isEmpty ? "https://www.themealdb.com/meal/\(full.id)" : full.source
        d.sourceKind = "discover"
        d.platform = "TheMealDB"
        d.evidence = ["Recipe from TheMealDB (community recipe database)"]
        d.warnings = ["Servings and times aren't listed by TheMealDB — please check before cooking."]
        if let u = full.thumbURL, let img = await HTTP.image(u) {
            let i = DraftImage(data: img, label: "Photo from TheMealDB", kind: .sourcePhoto)
            d.images = [i]
            d.coverImageID = i.id
        }
        d.recomputeCompleteness()
        return d
    }

    static func splitInstructions(_ s: String) -> [String] {
        s.components(separatedBy: CharacterSet.newlines)
            .map { HeuristicRecipeParser.stripNumbering($0.trimmingCharacters(in: .whitespaces)) }
            .map { $0.replacingOccurrences(of: #"^step\s*\d+\s*"#, with: "", options: [.regularExpression, .caseInsensitive]) }
            .filter { $0.count > 3 }
    }

    static func mapCategory(_ c: String) -> String {
        switch c {
        case "Dessert": return "Dessert"
        case "Breakfast": return "Breakfast"
        case "Side": return "Side"
        case "Starter": return "Appetizer"
        case "Miscellaneous": return "Other"
        default: return "Dinner"
        }
    }
}

/// AI-powered web search for recipe pages (uses Claude's web search tool) and dish identification.
enum AIRecipeSearch {
    struct WebResult: Identifiable, Hashable {
        let id = UUID()
        var title: String
        var url: URL
        var site: String
        var reason: String
    }

    static func findRecipePages(query: String, context: String) async throws -> [WebResult] {
        let system = """
        You find web pages that contain a full written recipe. Search the web, then answer with ONLY a JSON object: \
        {"results":[{"title":"...","url":"https://...","site":"example.com","reason":"why it matches"}]}. \
        Include at most 5 results. Only include URLs that appeared in your search results — never make up URLs. \
        Prefer the original creator's own website if the context names a creator.
        """
        let prompt = "Find recipe pages for: \(query)\n\nContext from the video (may be partial):\n\(context.prefix(3000))"
        let tools: [[String: Any]] = [["type": "web_search_20260209", "name": "web_search", "max_uses": 4]]
        let r = try await ClaudeClient.send(system: system, messages: [ClaudeClient.user([ClaudeClient.text(prompt)])],
                                            tools: tools, effort: "low")
        // Only accept URLs that the search tool actually returned.
        var seenURLs = Set<String>()
        for block in r.content where block["type"] as? String == "web_search_tool_result" {
            for item in block["content"] as? [[String: Any]] ?? [] {
                if let u = item["url"] as? String { seenURLs.insert(u) }
            }
        }
        guard let obj = ClaudeClient.parseJSONObject(r.text), let arr = obj["results"] as? [[String: Any]] else { return [] }
        func norm(_ s: String) -> String { s.hasSuffix("/") ? String(s.dropLast()) : s }
        let verified = Set(seenURLs.map(norm))
        return arr.compactMap { item in
            guard let s = item["url"] as? String, let u = URL(string: s), verified.contains(norm(s)) else { return nil }
            return WebResult(title: item["title"] as? String ?? u.host ?? s, url: u,
                             site: item["site"] as? String ?? u.host ?? "", reason: item["reason"] as? String ?? "")
        }
    }

    struct DishGuess {
        var name: String
        var confidence: String
        var visibleIngredients: [String]
        var notes: String
    }

    static func identifyDish(_ image: Data) async throws -> DishGuess {
        let schema: [String: Any] = [
            "type": "object", "additionalProperties": false,
            "required": ["dishName", "confidence", "visibleIngredients", "notes"],
            "properties": [
                "dishName": ["type": "string"],
                "confidence": ["type": "string", "enum": ["high", "medium", "low"]],
                "visibleIngredients": ["type": "array", "items": ["type": "string"]],
                "notes": ["type": "string"]
            ]
        ]
        guard let small = ImageUtil.downscaledJPEG(image, maxSide: 1000) else { throw ClaudeError.badResponse }
        let o = try await ClaudeClient.structured(
            system: "Identify the dish in the photo. Only list ingredients that are actually visible. Be honest about uncertainty.",
            content: [ClaudeClient.image(small), ClaudeClient.text("What dish is this?")], schema: schema, effort: "low")
        return DishGuess(name: o["dishName"] as? String ?? "", confidence: o["confidence"] as? String ?? "low",
                         visibleIngredients: o["visibleIngredients"] as? [String] ?? [], notes: o["notes"] as? String ?? "")
    }
}
