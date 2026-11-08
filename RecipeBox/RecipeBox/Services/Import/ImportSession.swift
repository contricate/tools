import Foundation
import SwiftData
import SwiftUI

/// Runs one import: gathers evidence from the link (and anything the user added), extracts the recipe,
/// and records the attempt in Import History. Nothing is saved to the cookbook until the user accepts.
@MainActor
@Observable
final class ImportSession {
    enum StepState: Equatable { case running, done(String), skipped(String), failed(String) }

    struct Step: Identifiable {
        let id = UUID()
        var label: String
        var state: StepState
    }

    enum Phase: Equatable { case input, running, result, noRecipe }

    var phase: Phase = .input
    var steps: [Step] = []
    var draft = RecipeDraft()
    var platform: VideoPlatform?
    var evidence: VideoEvidence?
    var gatheredText = ""
    var images: [DraftImage] = []
    var problem: String?
    var record: ImportRecord?
    var duplicate: Recipe?

    // Extra material the user can provide.
    var userText = ""
    var userScreenshots: [Data] = []
    var userVideo: MediaAnalyzer.Analysis?

    private var task: Task<Void, Never>?

    // MARK: Step log

    private func begin(_ label: String) -> UUID {
        let s = Step(label: label, state: .running)
        withAnimation(.snappy) { steps.append(s) }
        return s.id
    }

    private func end(_ id: UUID, _ state: StepState) {
        if let i = steps.firstIndex(where: { $0.id == id }) {
            withAnimation(.snappy) { steps[i].state = state }
        }
    }

    // MARK: Run

    func checkDuplicate(link: String, recipes: [Recipe]) {
        duplicate = nil
        guard let url = VideoPlatform.cleanURL(from: link) else { return }
        let key = VideoPlatform.normalize(url)
        duplicate = recipes.first { r in
            guard let u = URL(string: r.sourceURL), !r.sourceURL.isEmpty else { return false }
            return VideoPlatform.normalize(u) == key
        }
    }

    func start(link: String, context: ModelContext) {
        task?.cancel()
        task = Task { await run(link: link, context: context) }
    }

    func cancel() {
        task?.cancel()
        phase = .input
        steps = []
    }

    func run(link: String, context: ModelContext) async {
        steps = []
        images = []
        problem = nil
        gatheredText = ""
        draft = RecipeDraft()
        phase = .running
        let defaults = UserDefaults.standard
        let useAI = defaults.bool(forKey: SettingsKey.importUseAI) && ClaudeClient.isConfigured
        let useOCR = defaults.bool(forKey: SettingsKey.importOCR)

        var evidenceItems: [EvidenceItem] = []
        var url: URL?
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. The link
        if !trimmed.isEmpty {
            let s = begin("Checking the link")
            guard let u = VideoPlatform.cleanURL(from: trimmed) else {
                end(s, .failed("That isn't a valid link"))
                problem = "That doesn't look like a valid link. Copy the share link from the app (Share → Copy Link) and paste it here."
                phase = .noRecipe
                return
            }
            url = u
            let p = VideoPlatform.detect(u)
            platform = p
            end(s, .done(p.rawValue))

            let rec = ImportRecord(url: u.absoluteString, normalizedURL: VideoPlatform.normalize(u), platform: p.rawValue)
            context.insert(rec)
            record = rec

            var stepID = begin("Reading \(p.rawValue) details")
            let options = VideoSourceFetcher.Options(fetchCaptions: defaults.bool(forKey: SettingsKey.importFetchCaptions),
                                                     followLinks: defaults.bool(forKey: SettingsKey.importFollowLinks))
            let fetchStep = stepID
            let ev = await VideoSourceFetcher.fetch(u, options: options) { [weak self] msg in
                Task { @MainActor in
                    guard let self, let i = self.steps.firstIndex(where: { $0.id == fetchStep }) else { return }
                    self.steps[i].label = msg
                }
            }
            if Task.isCancelled { return }
            evidence = ev
            if let blocked = ev.blockedReason {
                end(stepID, .failed(blocked))
            } else {
                var found: [String] = []
                if !ev.title.isEmpty { found.append("title") }
                if !ev.description.isEmpty { found.append("description") }
                if !ev.transcript.isEmpty { found.append("captions") }
                if ev.structuredRecipe != nil { found.append("linked recipe") }
                end(stepID, found.isEmpty ? .skipped("No text available") : .done("Found " + found.joined(separator: ", ")))
            }
            if !ev.title.isEmpty { evidenceItems.append(EvidenceItem(label: "Video title", text: ev.title)) }
            if !ev.creator.isEmpty { evidenceItems.append(EvidenceItem(label: "Creator", text: ev.creator)) }
            if !ev.description.isEmpty { evidenceItems.append(EvidenceItem(label: "Caption / description", text: ev.description)) }
            if !ev.transcript.isEmpty { evidenceItems.append(EvidenceItem(label: ev.transcriptSource, text: ev.transcript)) }

            // 2. Images
            if !ev.imageURLs.isEmpty {
                stepID = begin("Downloading thumbnail and frames")
                var gotThumbnail = false
                for item in ev.imageURLs.prefix(6) {
                    if item.kind == .thumbnail && gotThumbnail { continue }
                    if let data = await HTTP.image(item.url) {
                        images.append(DraftImage(data: data, label: item.label, kind: item.kind))
                        if item.kind == .thumbnail { gotThumbnail = true }
                    }
                }
                end(stepID, images.isEmpty ? .skipped("Images not available") : .done("\(images.count) image\(images.count == 1 ? "" : "s")"))
            }

            // 3. A full recipe published on a page (the site itself, or a page the creator linked)
            if let structured = ev.structuredRecipe {
                let s2 = begin("Reading recipe from \(ev.structuredRecipeSource)")
                var d = Self.draft(from: structured)
                d.platform = p.rawValue
                d.creator = ev.creator
                if p == .website {
                    d.sourceKind = "web"
                    d.evidence = ["Structured recipe data published on \(ev.structuredRecipeSource)"]
                } else {
                    d.sourceKind = "video"
                    d.sourceURL = u.absoluteString
                    d.evidence = ["Recipe page linked in the creator's description: \(ev.structuredRecipeSource)"]
                    d.tips.append("Full recipe: \(structured.sourceURL)")
                }
                d.images = images
                d.coverImageID = images.first(where: { $0.kind == .sourcePhoto })?.id ?? images.first?.id
                end(s2, .done("\(d.ingredients.count) ingredients, \(d.steps.count) steps"))
                finish(d, context: context)
                return
            }
        }

        // 4. Material the user added
        if !userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            evidenceItems.append(EvidenceItem(label: "Text provided by the user (transcript/description)", text: userText))
        }
        for (i, shot) in userScreenshots.enumerated() {
            images.append(DraftImage(data: shot, label: "Your screenshot \(i + 1)", kind: .screenshot))
        }
        if let v = userVideo {
            if !v.transcript.isEmpty { evidenceItems.append(EvidenceItem(label: "On-device transcript of the video's audio", text: v.transcript)) }
            if !v.onScreenText.isEmpty { evidenceItems.append(EvidenceItem(label: "Text shown on screen in the video (OCR)", text: v.onScreenText)) }
            for (i, f) in v.frames.enumerated() where i % max(1, v.frames.count / 4) == 0 {
                images.append(DraftImage(data: f, label: "Frame from your video", kind: .frame))
            }
        }

        // 5. On-screen text in images
        if useOCR && !images.isEmpty {
            let s = begin("Reading text in images")
            let ocr = await TextRecognizer.text(in: images.filter { $0.kind != .sourcePhoto }.map(\.data))
            if ocr.count > 10 {
                evidenceItems.append(EvidenceItem(label: "Text recognized in the images (OCR, may contain errors)", text: ocr))
                end(s, .done("\(ocr.split(separator: "\n").count) lines of text"))
            } else {
                end(s, .skipped("No readable text"))
            }
        }
        if Task.isCancelled { return }

        gatheredText = evidenceItems.map { "\($0.label):\n\($0.text)" }.joined(separator: "\n\n")
        let hasEvidence = !evidenceItems.isEmpty || !images.isEmpty
        guard hasEvidence else {
            problem = evidence?.blockedReason ?? "There was nothing to analyze. Paste a link, or add screenshots, the video file, or the caption text."
            markRecord(status: "failed", error: problem ?? "")
            phase = .noRecipe
            return
        }

        // 6. Extraction
        var d = RecipeDraft()
        if useAI {
            let s = begin("Analyzing with AI (\(ClaudeClient.model.label))")
            do {
                d = try await AIRecipeExtractor.extract(evidence: evidenceItems, images: images)
                end(s, .done(d.completeness == .complete ? "Recipe found" : d.completeness == .partial ? "Partial recipe" : "No recipe found"))
            } catch {
                end(s, .failed(error.localizedDescription))
                d = heuristicDraft(evidenceItems)
                d.warnings.insert("AI analysis failed (\(error.localizedDescription)); these results come from built-in text rules.", at: 0)
            }
        } else {
            let s = begin("Organizing text into a recipe")
            d = heuristicDraft(evidenceItems)
            end(s, .done(d.hasContent ? "\(d.ingredients.count) ingredients, \(d.steps.count) steps" : "No recipe structure found"))
            if !ClaudeClient.isConfigured {
                d.warnings.append("AI analysis is off (no API key), so results come from simple text rules. Add a key in Settings for better extraction.")
            }
        }
        if Task.isCancelled { return }
        d.images = images
        if d.coverImageID == nil {
            d.coverImageID = images.first(where: { $0.kind == .sourcePhoto })?.id ?? images.first(where: { $0.kind == .thumbnail })?.id
        }
        d.platform = platform?.rawValue ?? (userVideo != nil ? "Video file" : "Screenshots")
        d.sourceURL = url?.absoluteString ?? ""
        d.sourceKind = "video"
        d.creator = evidence?.creator ?? ""
        if d.title.isEmpty { d.title = evidence?.title ?? "" }
        if d.searchQuery.isEmpty { d.searchQuery = d.title }
        d.evidence = evidenceItems.map(\.label) + (images.isEmpty ? [] : ["\(images.count) image\(images.count == 1 ? "" : "s")"])
        if let notes = evidence?.notes { d.warnings += notes.filter { !$0.isEmpty } }
        finish(d, context: context)
    }

    private func heuristicDraft(_ items: [EvidenceItem]) -> RecipeDraft {
        let text = items.filter { !$0.label.contains("title") && $0.label != "Creator" }.map(\.text).joined(separator: "\n")
        let h = HeuristicRecipeParser.parse(text)
        var d = RecipeDraft()
        d.title = evidence.map { VideoSourceFetcher.firstLine($0.title) } ?? ""
        d.ingredients = h.ingredients.map { line in
            DraftLine(text: line, status: HeuristicRecipeParser.startsWithQuantity(line) ? .confirmed : .unavailable,
                      note: "Found in the text")
        }
        d.steps = h.steps.map { DraftLine(text: $0, status: .confirmed, note: "Found in the text") }
        if let s = h.servings { d.servings = s; d.servingsStatus = .confirmed }
        if let p = h.prepMinutes { d.prepMinutes = p; d.prepStatus = .confirmed }
        if let c = h.cookMinutes { d.cookMinutes = c; d.cookStatus = .confirmed }
        if let t = h.temperature { d.temperature = t; d.temperatureStatus = .confirmed }
        d.tips = h.tips
        if d.ingredients.contains(where: { $0.status == .unavailable }) {
            d.warnings.append("Some ingredients have no amount in the source.")
        }
        if d.steps.isEmpty && !d.ingredients.isEmpty { d.warnings.append("No step-by-step method was found.") }
        d.recomputeCompleteness()
        return d
    }

    private func finish(_ d: RecipeDraft, context: ModelContext) {
        var d = d
        if d.completeness != .none && !d.hasContent { d.completeness = .none }
        draft = d
        if d.completeness == .none {
            problem = evidence?.blockedReason ?? "The app couldn't find a recipe in this video's available information."
            markRecord(status: "none", error: problem ?? "")
            phase = .noRecipe
        } else {
            markRecord(status: d.completeness.rawValue, error: "")
            phase = .result
        }
    }

    private func markRecord(status: String, error: String) {
        record?.status = status
        record?.errorMessage = error
        record?.recipeTitle = draft.title
    }

    // MARK: Decisions

    func accept(_ draft: RecipeDraft, context: ModelContext) -> Recipe {
        let r = draft.makeRecipe()
        context.insert(r)
        record?.outcome = "accepted"
        record?.recipeUID = r.uid
        record?.recipeTitle = r.title
        try? context.save()
        return r
    }

    func reject() {
        record?.outcome = "rejected"
        reset()
    }

    func reset() {
        phase = .input
        steps = []
        draft = RecipeDraft()
        images = []
        evidence = nil
        problem = nil
        record = nil
    }

    // MARK: Helpers

    nonisolated static func draft(from r: ImportedRecipe) -> RecipeDraft {
        var d = RecipeDraft()
        d.title = r.title
        d.summary = r.summary
        d.category = r.category
        d.servings = r.servings
        d.servingsStatus = r.servings > 0 ? .confirmed : .unavailable
        d.prepMinutes = r.prepMinutes
        d.prepStatus = r.prepMinutes > 0 ? .confirmed : .unavailable
        d.cookMinutes = r.cookMinutes
        d.cookStatus = r.cookMinutes > 0 ? .confirmed : .unavailable
        d.ingredients = r.ingredients.map { DraftLine(text: $0, status: .confirmed) }
        d.steps = r.steps.map { DraftLine(text: $0, status: .confirmed) }
        d.sourceURL = r.sourceURL
        d.recomputeCompleteness()
        if d.completeness == .partial && d.ingredients.count >= 2 && d.steps.count >= 1 { d.completeness = .complete }
        return d
    }
}
