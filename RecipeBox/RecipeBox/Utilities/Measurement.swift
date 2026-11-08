import Foundation

enum Dimension { case mass, volume, count }

/// Units recognised in ingredient lines. `factor` converts to grams (mass) or millilitres (volume).
enum CookUnit: String, CaseIterable {
    case mg, g, kg, oz, lb
    case ml, l, tsp, tbsp, cup, floz, pint, quart, gallon

    var dimension: Dimension {
        switch self {
        case .mg, .g, .kg, .oz, .lb: return .mass
        default: return .volume
        }
    }

    var factor: Double {
        switch self {
        case .mg: return 0.001
        case .g: return 1
        case .kg: return 1000
        case .oz: return 28.3495
        case .lb: return 453.592
        case .ml: return 1
        case .l: return 1000
        case .tsp: return 4.92892
        case .tbsp: return 14.7868
        case .cup: return 240
        case .floz: return 29.5735
        case .pint: return 473.176
        case .quart: return 946.353
        case .gallon: return 3785.41
        }
    }

    func symbol(plural: Bool) -> String {
        switch self {
        case .mg: return "mg"
        case .g: return "g"
        case .kg: return "kg"
        case .oz: return "oz"
        case .lb: return plural ? "lb" : "lb"
        case .ml: return "ml"
        case .l: return "L"
        case .tsp: return "tsp"
        case .tbsp: return "tbsp"
        case .cup: return plural ? "cups" : "cup"
        case .floz: return "fl oz"
        case .pint: return plural ? "pints" : "pint"
        case .quart: return plural ? "quarts" : "quart"
        case .gallon: return plural ? "gallons" : "gallon"
        }
    }

    static let aliases: [String: CookUnit] = [
        "mg": .mg, "milligram": .mg, "milligrams": .mg,
        "g": .g, "gr": .g, "gram": .g, "grams": .g, "gms": .g,
        "kg": .kg, "kgs": .kg, "kilogram": .kg, "kilograms": .kg, "kilo": .kg, "kilos": .kg,
        "oz": .oz, "ounce": .oz, "ounces": .oz,
        "lb": .lb, "lbs": .lb, "pound": .lb, "pounds": .lb,
        "ml": .ml, "milliliter": .ml, "milliliters": .ml, "millilitre": .ml, "millilitres": .ml, "mls": .ml,
        "l": .l, "liter": .l, "liters": .l, "litre": .l, "litres": .l,
        "tsp": .tsp, "tsps": .tsp, "teaspoon": .tsp, "teaspoons": .tsp, "t": .tsp,
        "tbsp": .tbsp, "tbsps": .tbsp, "tablespoon": .tbsp, "tablespoons": .tbsp, "tbs": .tbsp, "tbl": .tbsp, "T": .tbsp,
        "cup": .cup, "cups": .cup, "c": .cup,
        "fl oz": .floz, "floz": .floz, "fluid ounce": .floz, "fluid ounces": .floz,
        "pint": .pint, "pints": .pint, "pt": .pint,
        "quart": .quart, "quarts": .quart, "qt": .quart,
        "gallon": .gallon, "gallons": .gallon, "gal": .gallon
    ]
}

/// An ingredient line split into amount, unit and name, e.g. "1 1/2 cups flour, sifted".
struct ParsedIngredient: Equatable {
    var amount: Double?
    var amountMax: Double?
    var unit: CookUnit?
    /// Count words like "clove", "can" that are not convertible units.
    var countWord: String = ""
    var name: String
    var original: String

    var dimension: Dimension { unit?.dimension ?? .count }

    /// Amount in grams or millilitres (or raw count).
    var baseAmount: Double? {
        guard let a = amount else { return nil }
        return a * (unit?.factor ?? 1)
    }
}

enum IngredientParser {
    static let countWords: Set<String> = ["clove", "cloves", "can", "cans", "slice", "slices", "piece", "pieces",
                                          "pinch", "pinches", "dash", "dashes", "bunch", "bunches", "sprig", "sprigs",
                                          "stick", "sticks", "package", "packages", "pkg", "packet", "packets",
                                          "head", "heads", "jar", "jars", "bottle", "bottles", "handful", "handfuls",
                                          "large", "medium", "small", "whole", "fillet", "fillets", "breast", "breasts",
                                          "thigh", "thighs", "leaf", "leaves", "stalk", "stalks", "sheet", "sheets", "egg", "eggs"]

    static func parse(_ line: String) -> ParsedIngredient {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "•-*▪◦·–—✅✔️☐"))
            .trimmingCharacters(in: .whitespaces)
        var result = ParsedIngredient(amount: nil, amountMax: nil, unit: nil, name: trimmed, original: line)
        let chars = Array(trimmed)
        guard let q = IngredientScaler.parseQuantity(chars) else { return result }
        result.amount = q.value
        var rest = String(chars[q.length...])

        // Range "2-3" / "2 to 3"
        let rangeRegex = try? NSRegularExpression(pattern: #"^\s*(?:-|–|to)\s*"#)
        if let m = rangeRegex?.firstMatch(in: rest, range: NSRange(rest.startIndex..., in: rest)),
           let r = Range(m.range, in: rest) {
            let after = Array(rest[r.upperBound...])
            if let q2 = IngredientScaler.parseQuantity(after) {
                result.amountMax = q2.value
                rest = String(after[q2.length...])
            }
        }
        rest = rest.trimmingCharacters(in: .whitespaces)

        // Unit (try two-word units first, e.g. "fl oz")
        let words = rest.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        if words.count >= 2 {
            let two = (words[0] + " " + words[1]).lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
            if let u = CookUnit.aliases[two] {
                result.unit = u
                result.name = words.dropFirst(2).joined(separator: " ")
                return finish(result)
            }
        }
        if let first = words.first {
            let raw = first.trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
            // Case-sensitive "T" (tablespoon) vs "t" (teaspoon) before lowercasing.
            if raw == "T" || raw == "t" {
                result.unit = CookUnit.aliases[raw]
                result.name = words.dropFirst().joined(separator: " ")
                return finish(result)
            }
            let lower = raw.lowercased()
            if let u = CookUnit.aliases[lower], lower != "c" || words.count > 1 {
                result.unit = u
                result.name = words.dropFirst().joined(separator: " ")
                return finish(result)
            }
            // Glued units like "200g" are handled by parseQuantity stopping at "g".
            if countWords.contains(lower) && words.count > 1 {
                result.countWord = lower
                result.name = words.dropFirst().joined(separator: " ")
                return finish(result)
            }
        }
        result.name = rest
        return finish(result)
    }

    private static func finish(_ p: ParsedIngredient) -> ParsedIngredient {
        var r = p
        var n = r.name.trimmingCharacters(in: .whitespaces)
        if n.lowercased().hasPrefix("of ") { n = String(n.dropFirst(3)) }
        r.name = n
        return r
    }

    private static let descriptors: Set<String> = ["fresh", "freshly", "chopped", "minced", "diced", "sliced", "grated",
        "shredded", "finely", "roughly", "thinly", "large", "small", "medium", "whole", "ground", "crushed", "peeled",
        "softened", "melted", "cold", "warm", "room", "temperature", "packed", "heaping", "level", "optional",
        "to", "taste", "divided", "plus", "more", "for", "serving", "garnish", "about", "approximately", "cubed",
        "boneless", "skinless", "raw", "cooked", "unsalted", "salted", "extra", "virgin", "organic", "ripe", "and", "or"]

    /// A simplified key used to decide whether two grocery lines are "the same ingredient".
    static func key(for name: String) -> String {
        var s = name.lowercased()
        if let paren = s.firstIndex(of: "(") { s = String(s[..<paren]) }
        if let comma = s.firstIndex(of: ",") { s = String(s[..<comma]) }
        let words = s.split(whereSeparator: { !$0.isLetter }).map(String.init)
            .filter { !descriptors.contains($0) }
            .map(singular)
        return words.joined(separator: " ")
    }

    static func singular(_ w: String) -> String {
        if w.count > 4 && w.hasSuffix("oes") { return String(w.dropLast(2)) }
        if w.count > 4 && w.hasSuffix("ies") { return String(w.dropLast(3)) + "y" }
        if w.count > 3 && w.hasSuffix("s") && !w.hasSuffix("ss") { return String(w.dropLast()) }
        return w
    }

    /// Readable name for grocery list, without prep words ("garlic, minced" → "garlic").
    static func displayName(for name: String) -> String {
        var s = name
        if let comma = s.firstIndex(of: ",") { s = String(s[..<comma]) }
        s = s.trimmingCharacters(in: .whitespaces)
        return s.isEmpty ? name : s
    }
}

enum UnitConverter {
    /// Formats a number nicely: fractions for spoons/cups, whole numbers for grams, etc.
    static func format(_ v: Double, unit: CookUnit?) -> String {
        guard let unit else { return IngredientScaler.format(v) }
        switch unit {
        case .g, .ml, .mg:
            if v >= 100 { return String(Int((v / 5).rounded() * 5)) }
            if v >= 10 { return String(Int(v.rounded())) }
            return trim(v, 1)
        case .kg, .l:
            return trim(v, 2)
        case .oz, .lb, .floz:
            return v >= 10 ? String(Int(v.rounded())) : IngredientScaler.format(v)
        default:
            return IngredientScaler.format(v)
        }
    }

    static func trim(_ v: Double, _ places: Int) -> String {
        let s = String(format: "%.\(places)f", v)
        var out = s
        while out.contains(".") && (out.hasSuffix("0") || out.hasSuffix(".")) { out.removeLast() }
        return out
    }

    /// Picks a sensible unit for a base amount (grams or ml) in the target system.
    static func best(base: Double, dimension: Dimension, system: MeasurementSystem) -> (Double, CookUnit) {
        switch (dimension, system) {
        case (.mass, .metric):
            return base >= 1000 ? (base / 1000, .kg) : (base, .g)
        case (.mass, _):
            let oz = base / CookUnit.oz.factor
            return oz >= 16 ? (base / CookUnit.lb.factor, .lb) : (oz, .oz)
        case (.volume, .metric):
            if base < 15 { return (base / CookUnit.tsp.factor, .tsp) }
            if base < 45 { return (base / CookUnit.tbsp.factor, .tbsp) }
            return base >= 1000 ? (base / 1000, .l) : (base, .ml)
        case (.volume, _):
            if base < 14 { return (base / CookUnit.tsp.factor, .tsp) }
            if base < 59 { return (base / CookUnit.tbsp.factor, .tbsp) }
            if base >= 1900 { return (base / CookUnit.quart.factor, .quart) }
            return (base / CookUnit.cup.factor, .cup)
        default:
            return (base, .g)
        }
    }

    /// Rewrites an ingredient line into metric or imperial. Lines without a convertible unit are unchanged.
    static func convert(_ line: String, to system: MeasurementSystem) -> String {
        guard system != .original else { return line }
        let p = IngredientParser.parse(line)
        guard let unit = p.unit, let amount = p.amount else { return line }
        let isMetricUnit: Bool = [.g, .kg, .mg, .ml, .l].contains(unit)
        // Spoons are used everywhere; leave them alone.
        if unit == .tsp || unit == .tbsp { return line }
        if system == .metric && isMetricUnit { return line }
        if system == .imperial && !isMetricUnit { return line }
        let (v, u) = best(base: amount * unit.factor, dimension: unit.dimension, system: system)
        var out = "\(format(v, unit: u)) \(u.symbol(plural: v > 1))"
        if let mx = p.amountMax {
            let (v2, _) = best(base: mx * unit.factor, dimension: unit.dimension, system: system)
            let conv = v2 * (u.factor > 0 ? 1 : 1)
            out = "\(format(v, unit: u))–\(format(conv, unit: u)) \(u.symbol(plural: true))"
        }
        return p.name.isEmpty ? out : "\(out) \(p.name)"
    }

    static func fToC(_ f: Double) -> Double { (f - 32) * 5 / 9 }
    static func cToF(_ c: Double) -> Double { c * 9 / 5 + 32 }

    /// Converts temperatures written in text, e.g. "Bake at 350°F" → "Bake at 175°C".
    static func convertTemperatures(in text: String, to system: MeasurementSystem) -> String {
        guard system != .original,
              let regex = try? NSRegularExpression(pattern: #"(\d{2,3})\s*°?\s*(F|C|degrees F|degrees C|fahrenheit|celsius)\b"#,
                                                   options: [.caseInsensitive]) else { return text }
        let ns = text as NSString
        var result = text
        for m in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).reversed() {
            guard let value = Double(ns.substring(with: m.range(at: 1))) else { continue }
            let unit = ns.substring(with: m.range(at: 2)).lowercased()
            let isF = unit.hasPrefix("f") || unit.hasSuffix("f")
            let replacement: String
            if system == .metric && isF {
                let c = fToC(value)
                replacement = "\(Int((c / 5).rounded() * 5))°C"
            } else if system == .imperial && !isF {
                let f = cToF(value)
                replacement = "\(Int((f / 5).rounded() * 5))°F"
            } else { continue }
            if let r = Range(m.range, in: result) { result.replaceSubrange(r, with: replacement) }
        }
        return result
    }
}

/// Merges grocery quantities only when it is safe to do so.
enum GroceryMath {
    /// Returns the combined line if both describe the same ingredient in compatible units.
    static func combine(_ a: ParsedIngredient, _ b: ParsedIngredient) -> ParsedIngredient? {
        guard IngredientParser.key(for: a.name) == IngredientParser.key(for: b.name),
              !IngredientParser.key(for: a.name).isEmpty,
              let x = a.amount, let y = b.amount,
              a.amountMax == nil, b.amountMax == nil else { return nil }
        switch (a.unit, b.unit) {
        case let (ua?, ub?) where ua.dimension == ub.dimension:
            var r = a
            r.amount = (x * ua.factor + y * ub.factor) / ua.factor
            return r
        case (nil, nil) where a.countWord == b.countWord || IngredientParser.singular(a.countWord) == IngredientParser.singular(b.countWord):
            var r = a
            r.amount = x + y
            return r
        default:
            return nil
        }
    }

    static func describe(_ p: ParsedIngredient) -> String {
        guard let a = p.amount else { return p.original.trimmingCharacters(in: .whitespaces) }
        let name = IngredientParser.displayName(for: p.name)
        if let u = p.unit {
            return "\(UnitConverter.format(a, unit: u)) \(u.symbol(plural: a > 1)) \(name)"
        }
        let adjectives: Set<String> = ["large", "medium", "small", "whole"]
        let word: String
        if p.countWord.isEmpty { word = "" }
        else if adjectives.contains(p.countWord) { word = p.countWord + " " }
        else { word = (a > 1 ? pluralize(p.countWord) : IngredientParser.singular(p.countWord)) + " " }
        return "\(IngredientScaler.format(a)) \(word)\(name)"
    }

    private static func pluralize(_ w: String) -> String {
        if w.hasSuffix("s") { return w }
        if w.hasSuffix("ch") || w.hasSuffix("sh") { return w + "es" }
        return w + "s"
    }
}
