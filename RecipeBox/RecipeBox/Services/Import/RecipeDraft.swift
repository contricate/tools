import Foundation

enum FieldStatus: String, Codable {
    case confirmed, estimated, unavailable

    var label: String {
        switch self {
        case .confirmed: return "From source"
        case .estimated: return "Estimated"
        case .unavailable: return "Not found"
        }
    }
}

enum Completeness: String { case complete, partial, none }

struct DraftLine: Identifiable, Hashable {
    let id = UUID()
    var text: String
    var status: FieldStatus = .confirmed
    var note: String = ""
}

struct DraftImage: Identifiable {
    enum Kind: String { case thumbnail, frame, dish, sourcePhoto, screenshot }
    let id = UUID()
    var data: Data
    var label: String
    var kind: Kind
}

/// A recipe that has been extracted or generated but not yet saved.
struct RecipeDraft {
    var title = ""
    var summary = ""
    var category = "Dinner"
    var cuisine = ""
    var difficulty = ""
    var tags: [String] = []
    var servings = 0
    var servingsStatus: FieldStatus = .unavailable
    var prepMinutes = 0
    var prepStatus: FieldStatus = .unavailable
    var cookMinutes = 0
    var cookStatus: FieldStatus = .unavailable
    var totalMinutes = 0
    var temperature = ""
    var temperatureStatus: FieldStatus = .unavailable
    var ingredients: [DraftLine] = []
    var steps: [DraftLine] = []
    var tips: [String] = []
    var warnings: [String] = []
    var completeness: Completeness = .none
    var sourceURL = ""
    var platform = ""
    /// video, web, ai, discover
    var sourceKind = "video"
    /// Shown prominently in the preview, e.g. "Similar recipe from TheMealDB — not extracted from your video".
    var originNote = ""
    var images: [DraftImage] = []
    var coverImageID: UUID?
    var evidence: [String] = []
    var searchQuery = ""
    var creator = ""

    var hasContent: Bool { !ingredients.isEmpty || !steps.isEmpty }

    var uncertainCount: Int {
        ingredients.filter { $0.status != .confirmed }.count + steps.filter { $0.status != .confirmed }.count
    }

    mutating func recomputeCompleteness() {
        if ingredients.count >= 2 && steps.count >= 2 && uncertainCount == 0 {
            completeness = .complete
        } else if hasContent {
            completeness = .partial
        } else {
            completeness = .none
        }
    }

    /// Converts to a saved Recipe. Uncertain items stay visibly marked.
    func makeRecipe() -> Recipe {
        let defaultServings = UserDefaults.standard.integer(forKey: SettingsKey.defaultServings)
        let r = Recipe(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Recipe" : title,
            summary: summary,
            category: Recipe.categories.contains(category) ? category : "Other",
            servings: servings > 0 ? servings : max(1, defaultServings),
            prepMinutes: prepMinutes,
            cookMinutes: cookMinutes > 0 ? cookMinutes : max(0, totalMinutes - prepMinutes),
            ingredients: ingredients.map { line in
                line.status == .estimated && !line.text.contains("(estimated)") ? line.text + " (estimated)" : line.text
            }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty },
            steps: steps.map { line in
                line.status == .estimated && !line.text.hasPrefix("[Estimated]") ? "[Estimated] " + line.text : line.text
            }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty },
            notes: tips.joined(separator: "\n"))
        r.cuisine = cuisine
        r.difficulty = difficulty
        r.tags = tags
        r.temperature = temperature
        r.sourceURL = sourceURL
        r.sourceKind = sourceKind
        r.sourcePlatform = platform
        r.importedAt = sourceKind == "manual" ? nil : Date()
        var w = warnings
        if servingsStatus != .confirmed && servings == 0 { w.append("Servings weren't stated in the source; set to \(r.servings) by default.") }
        if servingsStatus == .estimated { w.append("Servings are estimated.") }
        if prepStatus == .estimated || cookStatus == .estimated { w.append("Some times are estimated.") }
        if !originNote.isEmpty { w.insert(originNote, at: 0) }
        r.importWarnings = w
        if let cover = images.first(where: { $0.id == coverImageID }) {
            r.photoData = cover.data
        }
        return r
    }
}
