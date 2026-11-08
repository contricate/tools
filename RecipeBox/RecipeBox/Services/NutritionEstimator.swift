import SwiftUI

/// Nutrition per 100 g (approximate values based on USDA FoodData Central averages).
struct Nutrients {
    var kcal = 0.0, protein = 0.0, carbs = 0.0, fat = 0.0, satFat = 0.0, fiber = 0.0, sugar = 0.0, sodium = 0.0 // sodium in mg

    static func + (a: Nutrients, b: Nutrients) -> Nutrients {
        Nutrients(kcal: a.kcal + b.kcal, protein: a.protein + b.protein, carbs: a.carbs + b.carbs, fat: a.fat + b.fat,
                  satFat: a.satFat + b.satFat, fiber: a.fiber + b.fiber, sugar: a.sugar + b.sugar, sodium: a.sodium + b.sodium)
    }

    func scaled(_ f: Double) -> Nutrients {
        Nutrients(kcal: kcal * f, protein: protein * f, carbs: carbs * f, fat: fat * f,
                  satFat: satFat * f, fiber: fiber * f, sugar: sugar * f, sodium: sodium * f)
    }
}

enum NutritionEstimator {
    struct Food {
        let keys: [String]
        let n: Nutrients
        /// grams in one cup (for volume measures); nil if not normally measured by volume
        let gPerCup: Double?
        /// grams in one piece (for counted items)
        let gEach: Double?
    }

    private static func f(_ keys: [String], _ kcal: Double, _ p: Double, _ c: Double, _ fat: Double, _ sat: Double,
                          _ fib: Double, _ sug: Double, _ na: Double, cup: Double? = nil, each: Double? = nil) -> Food {
        Food(keys: keys, n: Nutrients(kcal: kcal, protein: p, carbs: c, fat: fat, satFat: sat, fiber: fib, sugar: sug, sodium: na),
             gPerCup: cup, gEach: each)
    }

    // Order matters: more specific names first.
    static let foods: [Food] = [
        f(["chicken breast"], 120, 22.5, 0, 2.6, 0.6, 0, 0, 45, each: 175),
        f(["chicken thigh"], 177, 19.7, 0, 10.9, 3, 0, 0, 84, each: 110),
        f(["ground chicken"], 143, 17.4, 0, 8.1, 2.3, 0, 0, 60),
        f(["chicken"], 165, 21, 0, 9, 2.5, 0, 0, 70, each: 175),
        f(["ground turkey", "turkey"], 150, 19, 0, 8, 2.2, 0, 0, 70),
        f(["ground beef", "minced beef", "beef mince"], 254, 17.2, 0, 20, 7.8, 0, 0, 66),
        f(["steak", "beef"], 217, 26, 0, 12, 4.8, 0, 0, 60),
        f(["bacon"], 417, 13, 1.4, 39.7, 13, 0, 0, 1500, each: 12),
        f(["sausage"], 301, 12, 2, 27, 9, 0, 1, 750, each: 75),
        f(["ham"], 145, 21, 1.5, 5.5, 1.8, 0, 1.3, 1200),
        f(["pork"], 242, 27, 0, 14, 5, 0, 0, 62),
        f(["lamb"], 282, 16.6, 0, 23.4, 10, 0, 0, 59),
        f(["salmon"], 208, 20, 0, 13, 3.1, 0, 0, 59, each: 170),
        f(["tuna"], 116, 25.5, 0, 0.8, 0.2, 0, 0, 330),
        f(["shrimp", "prawn"], 99, 24, 0.2, 0.3, 0.1, 0, 0, 111),
        f(["cod", "white fish", "tilapia", "fish"], 96, 20, 0, 1.7, 0.4, 0, 0, 60, each: 170),
        f(["tofu"], 76, 8, 1.9, 4.8, 0.7, 0.3, 0.6, 7, cup: 250),
        f(["egg white"], 52, 10.9, 0.7, 0.2, 0, 0, 0.7, 166, each: 33),
        f(["egg"], 143, 12.6, 0.7, 9.5, 3.1, 0, 0.4, 142, each: 50),
        f(["heavy cream", "double cream", "whipping cream", "heavy whipping"], 340, 2.8, 2.7, 36, 23, 0, 2.9, 27, cup: 238),
        f(["sour cream"], 198, 2.4, 4.6, 19.4, 10, 0, 3.5, 31, cup: 230),
        f(["cream cheese"], 342, 6, 4.1, 34, 19, 0, 3.2, 321, cup: 232),
        f(["greek yogurt"], 97, 9, 3.9, 5, 2.4, 0, 3.6, 35, cup: 245),
        f(["yogurt", "yoghurt"], 61, 3.5, 4.7, 3.3, 2.1, 0, 4.7, 46, cup: 245),
        f(["buttermilk"], 40, 3.3, 4.8, 0.9, 0.5, 0, 4.8, 105, cup: 245),
        f(["milk"], 61, 3.2, 4.8, 3.3, 1.9, 0, 5, 43, cup: 244),
        f(["parmesan"], 431, 38, 4, 29, 17, 0, 0.9, 1529, cup: 100),
        f(["mozzarella"], 280, 28, 3.1, 17, 10, 0, 1, 627, cup: 113),
        f(["cheddar", "cheese"], 403, 25, 1.3, 33, 21, 0, 0.5, 621, cup: 113),
        f(["feta"], 264, 14, 4, 21, 15, 0, 4, 917, cup: 150),
        f(["ricotta"], 174, 11, 3, 13, 8.3, 0, 0.3, 84, cup: 246),
        f(["butter"], 717, 0.9, 0.1, 81, 51, 0, 0.1, 643, cup: 227),
        f(["olive oil", "vegetable oil", "canola oil", "oil"], 884, 0, 0, 100, 14, 0, 0, 2, cup: 216),
        f(["coconut milk"], 197, 2, 2.8, 21, 18.9, 0, 3.3, 13, cup: 240),
        f(["all-purpose flour", "plain flour", "flour"], 364, 10, 76, 1, 0.2, 2.7, 0.3, 2, cup: 125),
        f(["brown sugar"], 380, 0, 98, 0, 0, 0, 97, 28, cup: 220),
        f(["powdered sugar", "icing sugar"], 389, 0, 100, 0, 0, 0, 98, 2, cup: 120),
        f(["sugar"], 387, 0, 100, 0, 0, 0, 100, 1, cup: 200),
        f(["honey"], 304, 0.3, 82, 0, 0, 0.2, 82, 4, cup: 340),
        f(["maple syrup"], 260, 0, 67, 0.1, 0, 0, 60, 12, cup: 315),
        f(["chocolate chip", "chocolate"], 535, 4.9, 61, 30, 18, 6, 52, 24, cup: 170),
        f(["cocoa"], 228, 19.6, 58, 13.7, 8, 37, 1.8, 21, cup: 86),
        f(["oats", "oatmeal", "rolled oats"], 389, 16.9, 66, 6.9, 1.2, 10.6, 1, 2, cup: 80),
        f(["brown rice"], 362, 7.5, 76, 2.7, 0.5, 3.4, 0.7, 4, cup: 190),
        f(["rice"], 365, 7.1, 80, 0.7, 0.2, 1.3, 0.1, 5, cup: 185),
        f(["quinoa"], 368, 14, 64, 6, 0.7, 7, 0, 5, cup: 170),
        f(["spaghetti", "pasta", "penne", "macaroni", "noodle", "fettuccine", "linguine"], 371, 13, 75, 1.5, 0.3, 3.2, 2.7, 6, cup: 100),
        f(["bread crumb", "breadcrumb", "panko"], 395, 13, 72, 5, 1.1, 4.5, 6, 732, cup: 108),
        f(["tortilla"], 306, 8, 50, 8, 3, 3.5, 2, 740, each: 45),
        f(["bread"], 265, 9, 49, 3.2, 0.7, 2.7, 5, 491, each: 30),
        f(["potato"], 77, 2, 17, 0.1, 0, 2.2, 0.8, 6, cup: 150, each: 213),
        f(["sweet potato"], 86, 1.6, 20, 0.1, 0, 3, 4.2, 55, cup: 133, each: 130),
        f(["onion", "shallot"], 40, 1.1, 9.3, 0.1, 0, 1.7, 4.2, 4, cup: 160, each: 110),
        f(["garlic"], 149, 6.4, 33, 0.5, 0.1, 2.1, 1, 17, each: 3),
        f(["carrot"], 41, 0.9, 9.6, 0.2, 0, 2.8, 4.7, 69, cup: 128, each: 61),
        f(["celery"], 16, 0.7, 3, 0.2, 0, 1.6, 1.3, 80, cup: 101, each: 40),
        f(["bell pepper", "capsicum"], 26, 1, 6, 0.3, 0, 2.1, 4.2, 4, cup: 149, each: 120),
        f(["tomato paste"], 82, 4.3, 19, 0.5, 0.1, 4.1, 12, 59, cup: 262),
        f(["tomato sauce", "passata", "crushed tomato", "diced tomato", "canned tomato"], 29, 1.4, 6.5, 0.2, 0, 1.5, 4, 280, cup: 245),
        f(["tomato"], 18, 0.9, 3.9, 0.2, 0, 1.2, 2.6, 5, cup: 180, each: 123),
        f(["spinach"], 23, 2.9, 3.6, 0.4, 0.1, 2.2, 0.4, 79, cup: 30),
        f(["kale"], 49, 4.3, 8.8, 0.9, 0.1, 3.6, 2.3, 38, cup: 21),
        f(["lettuce"], 15, 1.4, 2.9, 0.2, 0, 1.3, 0.8, 28, cup: 47),
        f(["broccoli"], 34, 2.8, 6.6, 0.4, 0, 2.6, 1.7, 33, cup: 91),
        f(["cauliflower"], 25, 1.9, 5, 0.3, 0.1, 2, 1.9, 30, cup: 107),
        f(["zucchini", "courgette"], 17, 1.2, 3.1, 0.3, 0.1, 1, 2.5, 8, cup: 124, each: 196),
        f(["mushroom"], 22, 3.1, 3.3, 0.3, 0, 1, 2, 5, cup: 70),
        f(["cucumber"], 15, 0.7, 3.6, 0.1, 0, 0.5, 1.7, 2, cup: 119, each: 300),
        f(["corn"], 86, 3.3, 19, 1.4, 0.3, 2, 6.3, 15, cup: 154),
        f(["peas"], 81, 5.4, 14, 0.4, 0.1, 5.7, 5.7, 5, cup: 145),
        f(["green bean"], 31, 1.8, 7, 0.2, 0, 2.7, 3.3, 6, cup: 100),
        f(["avocado"], 160, 2, 8.5, 14.7, 2.1, 6.7, 0.7, 7, cup: 150, each: 150),
        f(["lemon juice", "lime juice"], 22, 0.4, 6.9, 0.2, 0, 0.3, 2.5, 1, cup: 244),
        f(["lemon", "lime"], 29, 1.1, 9.3, 0.3, 0, 2.8, 2.5, 2, each: 60),
        f(["banana"], 89, 1.1, 23, 0.3, 0.1, 2.6, 12, 1, cup: 150, each: 118),
        f(["apple"], 52, 0.3, 14, 0.2, 0, 2.4, 10, 1, cup: 125, each: 182),
        f(["blueberr", "strawberr", "raspberr", "berries", "berry"], 50, 0.8, 12, 0.4, 0, 2.5, 8, 1, cup: 145),
        f(["black bean", "kidney bean", "chickpea", "cannellini", "beans", "lentil"], 120, 8, 21, 0.5, 0.1, 7, 0.5, 240, cup: 172),
        f(["peanut butter"], 588, 25, 20, 50, 10, 6, 9, 459, cup: 258),
        f(["almond", "walnut", "pecan", "cashew", "peanut", "nuts"], 607, 20, 21, 54, 6, 8, 4.4, 5, cup: 140),
        f(["chicken broth", "chicken stock", "beef broth", "beef stock", "vegetable broth", "vegetable stock", "broth", "stock"], 6, 0.6, 0.4, 0.2, 0.1, 0, 0.3, 343, cup: 240),
        f(["soy sauce"], 53, 8, 4.9, 0.6, 0.1, 0.8, 0.4, 5493, cup: 255),
        f(["mayonnaise", "mayo"], 680, 1, 0.6, 75, 11.7, 0, 0.6, 635, cup: 220),
        f(["ketchup"], 101, 1, 27, 0.1, 0, 0.3, 22, 907, cup: 240),
        f(["mustard"], 60, 3.7, 5.8, 3.3, 0.2, 4, 0.9, 1135, cup: 250),
        f(["vinegar"], 18, 0, 0.04, 0, 0, 0, 0.04, 2, cup: 240),
        f(["salt"], 0, 0, 0, 0, 0, 0, 0, 38758, cup: 292),
        f(["baking soda"], 0, 0, 0, 0, 0, 0, 0, 27360, cup: 220),
        f(["baking powder"], 53, 0, 28, 0, 0, 0.2, 0, 10600, cup: 220),
        f(["water", "ice"], 0, 0, 0, 0, 0, 0, 0, 0, cup: 237),
        f(["vanilla"], 288, 0.1, 12.7, 0.1, 0, 0, 12.7, 9, cup: 208)
    ]

    /// Spices/herbs: negligible nutrition, counted as covered so they don't reduce confidence.
    static let negligible = ["pepper", "paprika", "cumin", "cinnamon", "oregano", "thyme", "basil", "parsley", "cilantro",
                             "rosemary", "chili powder", "chilli", "nutmeg", "bay lea", "garlic powder", "onion powder",
                             "seasoning", "spice", "herb", "ginger", "turmeric", "curry powder", "dill", "mint", "zest", "red pepper flakes", "chives"]

    struct Estimate {
        var total = Nutrients()
        var matched: [String] = []
        var unmatched: [String] = []
        var noAmount: [String] = []
        var countedLines = 0
        var totalLines = 0

        var coverage: Double { totalLines == 0 ? 0 : Double(countedLines) / Double(totalLines) }
        /// Only show numbers when most ingredients could be measured.
        var isReliable: Bool { totalLines > 0 && coverage >= 0.7 && total.kcal > 0 }
    }

    /// Finds the table entry whose name matches best (longest key, matched at a word start).
    static func food(for name: String) -> Food? {
        let n = " " + name.lowercased().replacingOccurrences(of: "-", with: " ")
        var best: (Food, Int)?
        for f in foods {
            for k in f.keys where n.contains(" " + k) {
                if k.count > (best?.1 ?? 0) { best = (f, k.count) }
            }
        }
        return best?.0
    }

    static func grams(_ p: ParsedIngredient, food: Food) -> Double? {
        guard let amount = p.amount else { return nil }
        let a = p.amountMax.map { (amount + $0) / 2 } ?? amount
        if let u = p.unit {
            switch u.dimension {
            case .mass: return a * u.factor
            case .volume:
                guard let cup = food.gPerCup else { return a * u.factor } // assume density of water
                return a * u.factor / CookUnit.cup.factor * cup
            case .count: return nil
            }
        }
        let word = p.countWord
        if word.hasPrefix("clove") { return a * 3 }
        if word.hasPrefix("pinch") || word.hasPrefix("dash") { return a * 0.4 }
        if word.hasPrefix("can") { return a * 400 }
        if word.hasPrefix("stick"), food.keys.contains("butter") { return a * 113 }
        if word.hasPrefix("slice") { return a * (food.keys.contains("bacon") ? 12 : 28) }
        if let each = food.gEach { return a * each }
        return nil
    }

    static func estimate(_ lines: [String]) -> Estimate {
        var e = Estimate()
        for line in lines {
            let lower = line.lowercased()
            if lower.contains("to taste") || lower.contains("for serving") || lower.contains("optional") || lower.contains("garnish") {
                continue
            }
            e.totalLines += 1
            let p = IngredientParser.parse(line)
            if negligible.contains(where: { lower.contains($0) }) && food(for: p.name)?.keys.first != "bell pepper" {
                e.countedLines += 1
                continue
            }
            guard let food = food(for: p.name.isEmpty ? line : p.name) else {
                e.unmatched.append(line)
                continue
            }
            guard let g = grams(p, food: food) else {
                e.noAmount.append(line)
                continue
            }
            e.total = e.total + food.n.scaled(g / 100)
            e.matched.append(line)
            e.countedLines += 1
        }
        return e
    }
}

/// Nutrition card used on recipe pages and import previews.
struct NutritionSummaryView: View {
    let ingredients: [String]
    let servings: Int
    var servingsKnown = true
    @State private var perServing = true
    @State private var showDetails = false

    var body: some View {
        let e = NutritionEstimator.estimate(ingredients)
        let n = perServing ? e.total.scaled(1 / Double(max(1, servings))) : e.total
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nutrition").font(.title3.bold())
                Badge(text: "Estimated", icon: "function", color: .secondary)
                Spacer()
                if e.isReliable {
                    Picker("", selection: $perServing) {
                        Text("Per serving").tag(true)
                        Text("Whole recipe").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 210)
                }
            }
            if e.isReliable {
                HStack(spacing: 0) {
                    macro("Calories", "\(Int(n.kcal.rounded()))", "kcal", .orange)
                    macro("Protein", "\(Int(n.protein.rounded()))", "g", .red)
                    macro("Carbs", "\(Int(n.carbs.rounded()))", "g", .blue)
                    macro("Fat", "\(Int(n.fat.rounded()))", "g", .yellow)
                }
                VStack(spacing: 6) {
                    row("Saturated fat", n.satFat, "g")
                    row("Fibre", n.fiber, "g")
                    row("Sugar", n.sugar, "g")
                    row("Sodium", n.sodium, "mg")
                }
                .font(.subheadline)
                Text("≈ Estimated from \(e.countedLines) of \(e.totalLines) ingredients using average values\(perServing && !servingsKnown ? ", assuming \(servings) servings" : ""). Not verified — actual values vary by brand and preparation.")
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                Text(e.totalLines == 0
                     ? "Add ingredients with amounts to see an estimate."
                     : "Not enough information for a reliable estimate (\(e.countedLines) of \(e.totalLines) ingredients could be measured). No numbers are shown rather than guessing.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if !e.noAmount.isEmpty || !e.unmatched.isEmpty {
                DisclosureGroup("Not included (\(e.noAmount.count + e.unmatched.count))", isExpanded: $showDetails) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(e.noAmount, id: \.self) { Text("• \($0) — no amount").font(.caption) }
                        ForEach(e.unmatched, id: \.self) { Text("• \($0) — not in nutrition table").font(.caption) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.caption)
            }
        }
        .card()
    }

    private func macro(_ label: String, _ value: String, _ unit: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold().monospacedDigit()).foregroundStyle(color)
            Text(unit).font(.caption2).foregroundStyle(.secondary)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func row(_ label: String, _ v: Double, _ unit: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text("\(v < 10 && unit == "g" ? String(format: "%.1f", v) : String(Int(v.rounded()))) \(unit)").monospacedDigit()
        }
    }
}
