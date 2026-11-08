import Foundation
import SwiftData

@Model
final class Recipe {
    var title: String = ""
    var summary: String = ""
    var category: String = "Dinner"
    var servings: Int = 4
    var prepMinutes: Int = 0
    var cookMinutes: Int = 0
    var ingredients: [String] = []
    var steps: [String] = []
    var notes: String = ""
    var sourceURL: String = ""
    var isFavorite: Bool = false
    var rating: Int = 0
    @Attribute(.externalStorage) var photoData: Data?
    var createdAt: Date = Date()
    var lastCooked: Date?
    var timesCooked: Int = 0
    @Relationship(deleteRule: .cascade, inverse: \MealPlanEntry.recipe)
    var planEntries: [MealPlanEntry]? = []

    // v3 additions (all have defaults so existing data migrates automatically)
    var uid: String = ""
    var tags: [String] = []
    var cuisine: String = ""
    var difficulty: String = ""
    var temperature: String = ""
    /// manual, web, video, ai, discover, file
    var sourceKind: String = "manual"
    var sourcePlatform: String = ""
    var importedAt: Date?
    var lastViewed: Date?
    var importWarnings: [String] = []
    @Relationship(deleteRule: .nullify, inverse: \RecipeCollection.recipes)
    var collections: [RecipeCollection]? = []
    @Relationship(deleteRule: .cascade, inverse: \CookNote.recipe)
    var cookNotes: [CookNote]? = []
    @Relationship(deleteRule: .cascade, inverse: \CookPhoto.recipe)
    var cookPhotos: [CookPhoto]? = []

    init(title: String,
         summary: String = "",
         category: String = "Dinner",
         servings: Int = 4,
         prepMinutes: Int = 0,
         cookMinutes: Int = 0,
         ingredients: [String] = [],
         steps: [String] = [],
         notes: String = "") {
        self.title = title
        self.summary = summary
        self.category = category
        self.servings = servings
        self.prepMinutes = prepMinutes
        self.cookMinutes = cookMinutes
        self.ingredients = ingredients
        self.steps = steps
        self.notes = notes
        self.createdAt = Date()
        self.uid = UUID().uuidString
    }

    var totalMinutes: Int { prepMinutes + cookMinutes }

    var shareText: String {
        var text = "\(title)\n"
        if !summary.isEmpty { text += "\(summary)\n" }
        text += "\nServes \(servings)"
        if totalMinutes > 0 { text += " · \(Recipe.format(minutes: totalMinutes))" }
        text += "\n\nIngredients:\n"
        text += ingredients.map { "• \($0)" }.joined(separator: "\n")
        text += "\n\nSteps:\n"
        text += steps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        if !notes.isEmpty { text += "\n\nNotes:\n\(notes)" }
        return text
    }

    static func format(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h) hr" : "\(h) hr \(m) min"
    }

    static let defaultCategories = ["Breakfast", "Lunch", "Dinner", "Appetizer", "Side", "Dessert", "Baking", "Drink", "Snack", "Other"]

    /// Built-in categories plus the user's own (managed in Settings).
    static var categories: [String] {
        let custom = UserDefaults.standard.stringArray(forKey: SettingsKey.customCategories) ?? []
        return defaultCategories + custom.filter { !defaultCategories.contains($0) }
    }

    static let suggestedTags = ["Quick Meals", "High Protein", "Budget Friendly", "Comfort Food", "Healthy",
                                "Meal Prep", "Vegetarian", "Vegan", "Gluten Free", "Spicy", "Kid Friendly", "One Pot"]

    static let difficulties = ["Easy", "Medium", "Hard"]

    var sourceLabel: String {
        switch sourceKind {
        case "video": return sourcePlatform.isEmpty ? "Imported from video" : "Imported from \(sourcePlatform)"
        case "web": return "Imported from website"
        case "ai": return "AI-generated recipe"
        case "discover": return "Saved from TheMealDB"
        case "file": return "Imported from file"
        default: return "Your recipe"
        }
    }

    var sourceIcon: String {
        switch sourceKind {
        case "video": return "play.rectangle.fill"
        case "web": return "globe"
        case "ai": return "sparkles"
        case "discover": return "safari"
        case "file": return "doc"
        default: return "person.crop.circle"
        }
    }

    static func icon(for category: String) -> String {
        switch category {
        case "Breakfast": return "sun.horizon"
        case "Lunch": return "takeoutbag.and.cup.and.straw"
        case "Dinner": return "fork.knife"
        case "Appetizer": return "leaf"
        case "Side": return "carrot"
        case "Dessert": return "birthday.cake"
        case "Baking": return "oven"
        case "Drink": return "cup.and.saucer"
        case "Snack": return "popcorn"
        default: return "book"
        }
    }

    /// Plain-text version used for AI prompts.
    var promptText: String {
        var t = "Title: \(title)\n"
        if !summary.isEmpty { t += "Description: \(summary)\n" }
        t += "Category: \(category)\nServings: \(servings)\n"
        if prepMinutes > 0 { t += "Prep time: \(prepMinutes) min\n" }
        if cookMinutes > 0 { t += "Cook time: \(cookMinutes) min\n" }
        if !temperature.isEmpty { t += "Temperature: \(temperature)\n" }
        t += "\nIngredients:\n" + ingredients.map { "- \($0)" }.joined(separator: "\n")
        t += "\n\nSteps:\n" + steps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        if !notes.isEmpty { t += "\n\nNotes: \(notes)" }
        return t
    }
}

@Model
final class RecipeCollection {
    var name: String = ""
    var icon: String = "folder"
    var createdAt: Date = Date()
    var recipes: [Recipe]? = []

    init(name: String, icon: String = "folder") {
        self.name = name
        self.icon = icon
        self.createdAt = Date()
    }

    static let icons = ["folder", "star", "heart", "flame", "leaf", "fork.knife", "birthday.cake", "cup.and.saucer",
                        "takeoutbag.and.cup.and.straw", "gift", "sun.max", "moon.stars", "person.2", "globe"]
}

/// A personal note or modification written about a recipe.
@Model
final class CookNote {
    var text: String = ""
    /// "note" or "change"
    var kind: String = "note"
    var date: Date = Date()
    var recipe: Recipe?

    init(text: String, kind: String = "note") {
        self.text = text
        self.kind = kind
        self.date = Date()
    }
}

/// A photo the user took of their own version of the dish.
@Model
final class CookPhoto {
    @Attribute(.externalStorage) var data: Data?
    var date: Date = Date()
    var recipe: Recipe?

    init(data: Data) {
        self.data = data
        self.date = Date()
    }
}

/// One attempt to import a recipe from a link.
@Model
final class ImportRecord {
    var url: String = ""
    var normalizedURL: String = ""
    var platform: String = ""
    var date: Date = Date()
    /// complete, partial, none, failed
    var status: String = "failed"
    /// pending, accepted, rejected
    var outcome: String = "pending"
    var errorMessage: String = ""
    var recipeTitle: String = ""
    var recipeUID: String = ""

    init(url: String, normalizedURL: String, platform: String) {
        self.url = url
        self.normalizedURL = normalizedURL
        self.platform = platform
        self.date = Date()
    }
}

/// A saved weekly meal plan that can be applied to any week.
@Model
final class SavedMealPlan {
    var name: String = ""
    var createdAt: Date = Date()
    var slotsData: Data = Data()

    init(name: String, slots: [SavedMealSlot]) {
        self.name = name
        self.createdAt = Date()
        self.slotsData = (try? JSONEncoder().encode(slots)) ?? Data()
    }

    var slots: [SavedMealSlot] {
        (try? JSONDecoder().decode([SavedMealSlot].self, from: slotsData)) ?? []
    }
}

struct SavedMealSlot: Codable, Hashable {
    var dayOffset: Int
    var meal: String
    var recipeUID: String
    var recipeTitle: String
}

@Model
final class ShoppingItem {
    var name: String = ""
    var isChecked: Bool = false
    var fromRecipe: String = ""
    var createdAt: Date = Date()
    // v3: structured quantity so matching items can be combined
    var amount: Double = 0
    var unit: String = ""
    var baseName: String = ""
    var aisleOverride: String = ""

    init(name: String, fromRecipe: String = "") {
        self.name = name
        self.fromRecipe = fromRecipe
        self.createdAt = Date()
    }
}

@Model
final class MealPlanEntry {
    var date: Date = Date()
    var meal: String = "Dinner"
    var recipe: Recipe?
    var createdAt: Date = Date()

    init(date: Date, meal: String, recipe: Recipe?) {
        self.date = Calendar.current.startOfDay(for: date)
        self.meal = meal
        self.recipe = recipe
        self.createdAt = Date()
    }

    static let meals = ["Breakfast", "Lunch", "Dinner", "Snack"]
}

/// Plain Codable copy of a recipe, used for backup files.
struct RecipeBackup: Codable {
    var title: String
    var summary: String
    var category: String
    var servings: Int
    var prepMinutes: Int
    var cookMinutes: Int
    var ingredients: [String]
    var steps: [String]
    var notes: String
    var sourceURL: String
    var isFavorite: Bool
    var rating: Int
    var photoData: Data?
    var createdAt: Date
    var lastCooked: Date?
    var timesCooked: Int
    var tags: [String]?
    var cuisine: String?
    var difficulty: String?
    var temperature: String?
    var sourceKind: String?
    var sourcePlatform: String?
    var importedAt: Date?
    var importWarnings: [String]?

    init(_ r: Recipe) {
        title = r.title; summary = r.summary; category = r.category
        servings = r.servings; prepMinutes = r.prepMinutes; cookMinutes = r.cookMinutes
        ingredients = r.ingredients; steps = r.steps; notes = r.notes
        sourceURL = r.sourceURL; isFavorite = r.isFavorite; rating = r.rating
        photoData = r.photoData; createdAt = r.createdAt
        lastCooked = r.lastCooked; timesCooked = r.timesCooked
        tags = r.tags; cuisine = r.cuisine; difficulty = r.difficulty; temperature = r.temperature
        sourceKind = r.sourceKind; sourcePlatform = r.sourcePlatform
        importedAt = r.importedAt; importWarnings = r.importWarnings
    }

    func makeRecipe() -> Recipe {
        let r = Recipe(title: title, summary: summary, category: category, servings: servings,
                       prepMinutes: prepMinutes, cookMinutes: cookMinutes,
                       ingredients: ingredients, steps: steps, notes: notes)
        r.sourceURL = sourceURL; r.isFavorite = isFavorite; r.rating = rating
        r.photoData = photoData; r.createdAt = createdAt
        r.lastCooked = lastCooked; r.timesCooked = timesCooked
        r.tags = tags ?? []; r.cuisine = cuisine ?? ""; r.difficulty = difficulty ?? ""
        r.temperature = temperature ?? ""; r.sourceKind = sourceKind ?? "file"
        r.sourcePlatform = sourcePlatform ?? ""; r.importedAt = importedAt
        r.importWarnings = importWarnings ?? []
        return r
    }
}

struct BackupFile: Codable {
    var version: Int = 1
    var exportedAt: Date = Date()
    var recipes: [RecipeBackup]
}

enum SampleRecipes {
    static func insert(into context: ModelContext) {
        let pancakes = Recipe(
            title: "Fluffy Pancakes",
            summary: "Classic weekend breakfast pancakes.",
            category: "Breakfast", servings: 4, prepMinutes: 10, cookMinutes: 15,
            ingredients: ["1 1/2 cups all-purpose flour", "3 1/2 tsp baking powder", "1 tbsp sugar", "1/4 tsp salt", "1 1/4 cups milk", "1 egg", "3 tbsp melted butter"],
            steps: ["Whisk flour, baking powder, sugar and salt in a bowl.", "Make a well in the center and pour in milk, egg and melted butter; mix until just combined.", "Heat a lightly oiled pan over medium-high heat.", "Pour 1/4 cup batter per pancake and cook until bubbles form, then flip and brown the other side."],
            notes: "Don't overmix — a few lumps are fine.")
        let pasta = Recipe(
            title: "Garlic Butter Pasta",
            summary: "Quick weeknight pasta with garlic, butter and parmesan.",
            category: "Dinner", servings: 2, prepMinutes: 5, cookMinutes: 15,
            ingredients: ["8 oz spaghetti", "4 tbsp butter", "4 cloves garlic, minced", "1/2 cup grated parmesan", "Salt and pepper", "Fresh parsley, chopped"],
            steps: ["Cook spaghetti in salted water until al dente. Reserve 1/2 cup pasta water.", "Melt butter in a pan and cook garlic for 1 minute until fragrant.", "Toss in pasta, parmesan and a splash of pasta water.", "Season with salt and pepper and top with parsley."])
        let cookies = Recipe(
            title: "Chocolate Chip Cookies",
            summary: "Chewy in the middle, crisp on the edges.",
            category: "Baking", servings: 24, prepMinutes: 15, cookMinutes: 11,
            ingredients: ["2 1/4 cups flour", "1 tsp baking soda", "1 tsp salt", "1 cup butter, softened", "3/4 cup sugar", "3/4 cup brown sugar", "2 eggs", "2 tsp vanilla", "2 cups chocolate chips"],
            steps: ["Preheat oven to 375°F (190°C).", "Mix flour, baking soda and salt.", "Beat butter and sugars until creamy, then beat in eggs and vanilla.", "Gradually mix in the flour mixture, then stir in chocolate chips.", "Drop spoonfuls onto a baking sheet and bake 9–11 minutes."])
        cookies.isFavorite = true
        cookies.rating = 5
        cookies.temperature = "375°F / 190°C"
        cookies.tags = ["Comfort Food"]
        pasta.tags = ["Quick Meals", "Budget Friendly"]
        pasta.rating = 4
        pancakes.tags = ["Quick Meals"]
        let chicken = Recipe(
            title: "Lemon Garlic Chicken & Rice",
            summary: "One-pan chicken thighs with fluffy lemony rice.",
            category: "Dinner", servings: 4, prepMinutes: 10, cookMinutes: 35,
            ingredients: ["600 g chicken thighs", "1 cup long-grain rice", "2 cups chicken broth", "3 cloves garlic, minced", "1 lemon, zested and juiced", "2 tbsp butter", "1/2 cup grated parmesan", "Salt and pepper"],
            steps: ["Season chicken with salt and pepper and brown in butter for 5 minutes per side. Remove.", "Cook garlic for 1 minute, then stir in rice, broth, lemon zest and juice.", "Nestle chicken on top, cover and simmer for 20 minutes until rice is tender and chicken reaches 165°F (74°C).", "Rest 5 minutes, sprinkle with parmesan and serve."])
        chicken.tags = ["High Protein", "One Pot", "Meal Prep"]
        chicken.temperature = "Chicken to 165°F / 74°C"
        for r in [pancakes, pasta, cookies, chicken] { context.insert(r) }
    }
}
