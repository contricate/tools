import Foundation

/// Scales the leading quantity of an ingredient line, e.g. "1 1/2 cups flour" x2 -> "3 cups flour".
enum IngredientScaler {
    static let unicodeFractions: [Character: Double] = [
        "½": 0.5, "⅓": 1.0 / 3, "⅔": 2.0 / 3, "¼": 0.25, "¾": 0.75,
        "⅛": 0.125, "⅜": 0.375, "⅝": 0.625, "⅞": 0.875, "⅕": 0.2, "⅖": 0.4, "⅗": 0.6, "⅘": 0.8, "⅙": 1.0 / 6, "⅚": 5.0 / 6
    ]

    static func scale(_ line: String, by factor: Double) -> String {
        guard abs(factor - 1) > 0.0001 else { return line }
        let chars = Array(line)
        var lead = 0
        while lead < chars.count, chars[lead] == " " { lead += 1 }
        let body = Array(chars[lead...])
        guard let first = parseQuantity(body) else { return line }
        var rest = Array(body[first.length...])
        var result = format(first.value * factor)

        // Ranges like "2-3" or "2 – 3"
        var j = 0
        while j < rest.count, rest[j] == " " { j += 1 }
        if j < rest.count, rest[j] == "-" || rest[j] == "–" {
            var k = j + 1
            while k < rest.count, rest[k] == " " { k += 1 }
            let after = Array(rest[k...])
            if let second = parseQuantity(after) {
                result += "–" + format(second.value * factor)
                rest = Array(after[second.length...])
            }
        }
        return result + String(rest)
    }

    private static func isDigit(_ ch: Character) -> Bool { ch.isASCII && ch.isNumber }

    private static func readDigits(_ c: [Character], _ start: Int, allowDot: Bool = false) -> (String, Int) {
        var i = start
        var s = ""
        while i < c.count, isDigit(c[i]) || (allowDot && c[i] == "." && !s.isEmpty && !s.contains(".")) {
            s.append(c[i]); i += 1
        }
        if s.hasSuffix(".") { s.removeLast(); i -= 1 }
        return (s, i)
    }

    static func parseQuantity(_ c: [Character]) -> (value: Double, length: Int)? {
        guard !c.isEmpty else { return nil }
        if let f = unicodeFractions[c[0]] { return (f, 1) }
        let (num, i) = readDigits(c, 0, allowDot: true)
        guard !num.isEmpty, let whole = Double(num) else { return nil }

        // Plain fraction: "1/2"
        if i < c.count, c[i] == "/" {
            let (den, j) = readDigits(c, i + 1)
            if let d = Double(den), d != 0 { return (whole / d, j) }
            return nil
        }
        // Mixed with unicode: "1½"
        if i < c.count, let f = unicodeFractions[c[i]] { return (whole + f, i + 1) }
        // Mixed with space: "1 1/2" or "1 ½"
        if i < c.count, c[i] == " ", i + 1 < c.count {
            if let f = unicodeFractions[c[i + 1]] { return (whole + f, i + 2) }
            let (n2, j) = readDigits(c, i + 1)
            if !n2.isEmpty, j < c.count, c[j] == "/" {
                let (d2, k) = readDigits(c, j + 1)
                if let a = Double(n2), let b = Double(d2), b != 0 { return (whole + a / b, k) }
            }
        }
        return (whole, i)
    }

    static func format(_ v: Double) -> String {
        if v >= 20 { return String(Int(v.rounded())) }
        var whole = Int(v)
        let frac = v - Double(whole)
        let options: [(Double, String)] = [
            (0, ""), (0.125, "⅛"), (0.25, "¼"), (1.0 / 3, "⅓"), (0.375, "⅜"), (0.5, "½"),
            (0.625, "⅝"), (2.0 / 3, "⅔"), (0.75, "¾"), (0.875, "⅞"), (1, "")
        ]
        var best = options[0]
        for o in options where abs(o.0 - frac) < abs(best.0 - frac) { best = o }
        if best.0 == 1 { whole += 1 }
        if best.1.isEmpty { return whole == 0 ? "⅛" : "\(whole)" }
        return whole == 0 ? best.1 : "\(whole)\(best.1)"
    }
}

/// Finds times mentioned in a cooking step, e.g. "bake for 25-30 minutes".
enum TimerDetector {
    struct Found: Hashable {
        let label: String
        let seconds: Int
    }

    private static let regex = try? NSRegularExpression(
        pattern: #"(\d+(?:\.\d+)?)(?:\s*(?:-|–|to)\s*(\d+(?:\.\d+)?))?\s*(hours?|hrs?|minutes?|mins?|seconds?|secs?)\b"#,
        options: [.caseInsensitive])

    static func find(in text: String) -> [Found] {
        guard let regex else { return [] }
        let ns = text as NSString
        var results: [Found] = []
        for m in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let a = Double(ns.substring(with: m.range(at: 1))) ?? 0
            var b: Double? = nil
            if m.range(at: 2).location != NSNotFound { b = Double(ns.substring(with: m.range(at: 2))) }
            let unit = ns.substring(with: m.range(at: 3)).lowercased()
            let mult: Double = unit.hasPrefix("h") ? 3600 : (unit.hasPrefix("s") ? 1 : 60)
            let value = b ?? a
            let seconds = Int(value * mult)
            guard seconds > 0 else { continue }
            let found = Found(label: ns.substring(with: m.range), seconds: seconds)
            if !results.contains(found) { results.append(found) }
        }
        return results
    }

    static func format(seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
