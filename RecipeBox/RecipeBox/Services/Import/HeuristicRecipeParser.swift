import Foundation

/// Rule-based recipe extraction from captions/descriptions. Used when AI is off or unavailable.
enum HeuristicRecipeParser {
    struct Output {
        var ingredients: [String] = []
        var steps: [String] = []
        var servings: Int?
        var prepMinutes: Int?
        var cookMinutes: Int?
        var temperature: String?
        var tips: [String] = []
    }

    private static let ingredientHeaders = ["ingredient", "you'll need", "you will need", "what you need", "you need", "shopping list", "for the "]
    private static let stepHeaders = ["instruction", "method", "direction", "steps", "how to make", "how to", "preparation", "procedure", "to make"]
    private static let tipHeaders = ["tip", "note", "notes"]

    static func normalizedLines(_ text: String) -> [String] {
        var t = text.replacingOccurrences(of: "\r", with: "\n")
        // Put numbered steps written on one line ("1. Mix 2. Bake") on separate lines.
        t = t.replacingOccurrences(of: #"(?<=[.!?)])\s+(?=\d{1,2}[.)]\s)"#, with: "\n", options: .regularExpression)
        // Bullet characters used as separators in single-line captions.
        for sep in [" • ", " ▪️ ", " ✅ ", " 🔸 ", " 🔹 ", " ▫️ ", " | "] { t = t.replacingOccurrences(of: sep, with: "\n") }
        return t.split(whereSeparator: \.isNewline)
            .map { stripBullet(String($0)) }
            .filter { !$0.isEmpty }
    }

    static func stripBullet(_ s: String) -> String {
        var line = s.trimmingCharacters(in: .whitespaces)
        while let f = line.first, "•-*▪◦·–—✅✔☑️🔸🔹▫️➡️👉✨🥄🧂".contains(f) || f.unicodeScalars.first.map({ $0.properties.isEmojiPresentation }) == true {
            line.removeFirst()
            line = line.trimmingCharacters(in: .whitespaces)
        }
        return line
    }

    private static func isHeader(_ line: String, _ headers: [String]) -> (Bool, String) {
        let lower = line.lowercased()
        for h in headers where lower.hasPrefix(h) {
            if let colon = line.firstIndex(of: ":") {
                let rest = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                return (true, rest)
            }
            return (line.count < 40, "")
        }
        return (false, "")
    }

    private static func isHashtagLine(_ s: String) -> Bool {
        let words = s.split(separator: " ")
        return !words.isEmpty && words.filter { $0.hasPrefix("#") || $0.hasPrefix("@") }.count * 2 >= words.count
    }

    static func stripNumbering(_ s: String) -> String {
        s.replacingOccurrences(of: #"^(step\s*)?\d{1,2}\s*[.):-]\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
    }

    static func startsWithQuantity(_ s: String) -> Bool {
        IngredientScaler.parseQuantity(Array(s)) != nil
    }

    static func parse(_ text: String) -> Output {
        var out = Output()
        enum Section { case none, ingredients, steps, tips }
        var section = Section.none
        var sawHeader = false

        for raw in normalizedLines(text) {
            if isHashtagLine(raw) { continue }
            let (ingH, ingRest) = isHeader(raw, ingredientHeaders)
            if ingH {
                section = .ingredients; sawHeader = true
                if !ingRest.isEmpty { out.ingredients += splitInlineList(ingRest) }
                continue
            }
            let (stepH, stepRest) = isHeader(raw, stepHeaders)
            if stepH {
                section = .steps; sawHeader = true
                if !stepRest.isEmpty { out.steps.append(stripNumbering(stepRest)) }
                continue
            }
            let (tipH, tipRest) = isHeader(raw, tipHeaders)
            if tipH {
                section = .tips
                if !tipRest.isEmpty { out.tips.append(tipRest) }
                continue
            }
            switch section {
            case .ingredients:
                if raw.count < 120 { out.ingredients.append(raw) } else { section = .none }
            case .steps:
                out.steps.append(stripNumbering(raw))
            case .tips:
                out.tips.append(raw)
            case .none:
                if !sawHeader {
                    if raw.range(of: #"^(step\s*)?\d{1,2}\s*[.)]\s+\S"#, options: [.regularExpression, .caseInsensitive]) != nil,
                       raw.count > 15 {
                        out.steps.append(stripNumbering(raw))
                    } else if startsWithQuantity(raw), raw.count < 80, raw.contains(where: \.isLetter) {
                        out.ingredients.append(raw)
                    }
                }
            }
        }

        let lower = text.lowercased()
        out.servings = firstInt(#"(?:serves|servings?|makes|yields?)\s*:?\s*(\d{1,2})"#, in: lower)
            ?? firstInt(#"(\d{1,2})\s*(?:servings|portions|people)"#, in: lower)
        out.prepMinutes = firstInt(#"prep(?:aration)?(?: time)?\s*:?\s*(\d{1,3})\s*(?:min|minutes)"#, in: lower)
        out.cookMinutes = firstInt(#"(?:cook|bake|baking|cooking)(?: time)?\s*:?\s*(\d{1,3})\s*(?:min|minutes)"#, in: lower)
        if let r = try? NSRegularExpression(pattern: #"\d{3}\s*°\s*[FC]|\d{3}\s*degrees\s*[FC]?|\d{2,3}\s*°\s*C"#, options: .caseInsensitive) {
            let ns = text as NSString
            if let m = r.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) {
                out.temperature = ns.substring(with: m.range)
            }
        }
        out.ingredients = dedupe(out.ingredients)
        out.steps = dedupe(out.steps.filter { $0.count > 3 })
        return out
    }

    static func splitInlineList(_ s: String) -> [String] {
        s.components(separatedBy: CharacterSet(charactersIn: ",;"))
            .map { stripBullet($0) }
            .filter { !$0.isEmpty && $0.count < 100 }
    }

    private static func firstInt(_ pattern: String, in text: String) -> Int? {
        guard let r = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        guard let m = r.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)), m.numberOfRanges > 1 else { return nil }
        return Int(ns.substring(with: m.range(at: 1)))
    }

    private static func dedupe(_ a: [String]) -> [String] {
        var seen = Set<String>()
        return a.filter { seen.insert($0.lowercased()).inserted }
    }
}
