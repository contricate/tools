import Foundation

struct EvidenceItem {
    var label: String
    var text: String
}

/// Uses Claude to reconstruct a recipe from all gathered evidence, marking what is confirmed vs. estimated.
enum AIRecipeExtractor {
    static let statusSchema: [String: Any] = ["type": "string", "enum": ["confirmed", "estimated", "unavailable"]]

    static var schema: [String: Any] {
        let line: [String: Any] = [
            "type": "object", "additionalProperties": false,
            "required": ["quantity", "item", "status", "source"],
            "properties": [
                "quantity": ["type": "string", "description": "Amount and unit exactly as stated, or empty if not stated"],
                "item": ["type": "string"],
                "status": statusSchema,
                "source": ["type": "string", "description": "Where this came from, e.g. caption, transcript, image 2, linked page"]
            ]
        ]
        let step: [String: Any] = [
            "type": "object", "additionalProperties": false,
            "required": ["text", "status", "source"],
            "properties": ["text": ["type": "string"], "status": statusSchema, "source": ["type": "string"]]
        ]
        return [
            "type": "object", "additionalProperties": false,
            "required": ["recipeFound", "title", "description", "category", "cuisine", "tags",
                         "servings", "servingsStatus", "prepMinutes", "prepStatus", "cookMinutes", "cookStatus",
                         "totalMinutes", "temperature", "temperatureStatus", "ingredients", "steps", "tips", "warnings",
                         "finishedDishImageIndex", "searchQuery"],
            "properties": [
                "recipeFound": ["type": "string", "enum": ["complete", "partial", "none"]],
                "title": ["type": "string"],
                "description": ["type": "string"],
                "category": ["type": "string", "enum": Recipe.defaultCategories],
                "cuisine": ["type": "string"],
                "tags": ["type": "array", "items": ["type": "string"]],
                "servings": ["type": "integer", "description": "0 if unknown"],
                "servingsStatus": statusSchema,
                "prepMinutes": ["type": "integer", "description": "0 if unknown"],
                "prepStatus": statusSchema,
                "cookMinutes": ["type": "integer", "description": "0 if unknown"],
                "cookStatus": statusSchema,
                "totalMinutes": ["type": "integer", "description": "0 if unknown"],
                "temperature": ["type": "string", "description": "e.g. 200°C / 400°F, or empty"],
                "temperatureStatus": statusSchema,
                "ingredients": ["type": "array", "items": line],
                "steps": ["type": "array", "items": step],
                "tips": ["type": "array", "items": ["type": "string"]],
                "warnings": ["type": "array", "items": ["type": "string"]],
                "finishedDishImageIndex": ["type": "integer", "description": "Index of an image that clearly shows the finished dish, or -1"],
                "searchQuery": ["type": "string", "description": "Short dish name to search for this recipe elsewhere"]
            ]
        ]
    }

    static let system = """
    You extract cooking recipes from evidence gathered about a cooking video or post: its caption/description, \
    captions or transcript, text recognized in video images (OCR), images themselves, and recipe pages the creator linked.

    Rules — accuracy matters more than completeness:
    - The creator's description/caption frequently contains the full ingredient list and method. Read it carefully first and \
    treat it as the primary source; use the transcript, on-screen text and images to fill gaps or resolve conflicts \
    (if they disagree, prefer the description and add a warning).
    - Use ONLY the evidence provided. Never invent ingredients, quantities, temperatures, times or steps.
    - status "confirmed": explicitly stated in the evidence (text, transcript, or clearly legible text in an image).
    - status "estimated": a reasonable inference from the evidence (e.g. an ingredient clearly visible but not named, \
    a step implied by the transcript, a quantity read from a blurry image). Say why in "source".
    - status "unavailable": not in the evidence. For an ingredient whose amount isn't stated, keep the item, set quantity to "" \
    and status "unavailable". Do not guess amounts.
    - Use 0 for unknown numbers with status "unavailable".
    - recipeFound: "complete" if ingredients with amounts and full method are present; "partial" if only some; "none" if the \
    evidence contains no real recipe information (e.g. just a title).
    - warnings: specific gaps a cook must know, e.g. "Amounts for 3 ingredients weren't given", "Oven temperature not mentioned", \
    "Steps reconstructed from the spoken transcript".
    - Write steps as clear instructions, keeping the creator's own amounts, times and temperatures.
    - title: the dish name (not the video's clickbait title).
    - finishedDishImageIndex: only if an image clearly shows the finished dish; else -1.
    - Ignore sponsorship text, hashtags, links to products and calls to follow/subscribe.
    """

    static func extract(evidence: [EvidenceItem], images: [DraftImage]) async throws -> RecipeDraft {
        var content: [[String: Any]] = []
        var text = "EVIDENCE GATHERED:\n"
        for e in evidence where !e.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            text += "\n=== \(e.label) ===\n\(e.text.prefix(25_000))\n"
        }
        content.append(ClaudeClient.text(text))
        for (i, img) in images.prefix(8).enumerated() {
            guard let small = ImageUtil.downscaledJPEG(img.data, maxSide: 900) else { continue }
            content.append(ClaudeClient.text("Image \(i): \(img.label)"))
            content.append(ClaudeClient.image(small))
        }
        content.append(ClaudeClient.text("Extract the recipe following the rules."))
        let obj = try await ClaudeClient.structured(system: system, content: content, schema: schema, effort: "medium")
        return draft(from: obj, images: images)
    }

    static func status(_ v: Any?) -> FieldStatus { FieldStatus(rawValue: v as? String ?? "") ?? .unavailable }

    static func draft(from o: [String: Any], images: [DraftImage]) -> RecipeDraft {
        var d = RecipeDraft()
        d.title = o["title"] as? String ?? ""
        d.summary = o["description"] as? String ?? ""
        d.category = o["category"] as? String ?? "Dinner"
        d.cuisine = o["cuisine"] as? String ?? ""
        d.tags = (o["tags"] as? [String] ?? []).filter { Recipe.suggestedTags.contains($0) }
        d.servings = o["servings"] as? Int ?? 0
        d.servingsStatus = d.servings > 0 ? status(o["servingsStatus"]) : .unavailable
        d.prepMinutes = o["prepMinutes"] as? Int ?? 0
        d.prepStatus = d.prepMinutes > 0 ? status(o["prepStatus"]) : .unavailable
        d.cookMinutes = o["cookMinutes"] as? Int ?? 0
        d.cookStatus = d.cookMinutes > 0 ? status(o["cookStatus"]) : .unavailable
        d.totalMinutes = o["totalMinutes"] as? Int ?? 0
        d.temperature = o["temperature"] as? String ?? ""
        d.temperatureStatus = d.temperature.isEmpty ? .unavailable : status(o["temperatureStatus"])
        for i in o["ingredients"] as? [[String: Any]] ?? [] {
            let q = (i["quantity"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            let item = (i["item"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            guard !item.isEmpty else { continue }
            var st = status(i["status"])
            var text = q.isEmpty ? item : "\(q) \(item)"
            if q.isEmpty && st == .confirmed { st = .unavailable }
            if q.isEmpty { text += " — amount not given" }
            d.ingredients.append(DraftLine(text: text, status: q.isEmpty ? .unavailable : st, note: i["source"] as? String ?? ""))
        }
        for s in o["steps"] as? [[String: Any]] ?? [] {
            let t = (s["text"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty else { continue }
            d.steps.append(DraftLine(text: t, status: status(s["status"]), note: s["source"] as? String ?? ""))
        }
        d.tips = o["tips"] as? [String] ?? []
        d.warnings = o["warnings"] as? [String] ?? []
        d.searchQuery = o["searchQuery"] as? String ?? d.title
        let idx = o["finishedDishImageIndex"] as? Int ?? -1
        if idx >= 0 && idx < images.count { d.coverImageID = images[idx].id }
        switch o["recipeFound"] as? String {
        case "complete": d.completeness = d.uncertainCount == 0 ? .complete : .partial
        case "partial": d.completeness = .partial
        default: d.completeness = d.hasContent ? .partial : .none
        }
        return d
    }
}
