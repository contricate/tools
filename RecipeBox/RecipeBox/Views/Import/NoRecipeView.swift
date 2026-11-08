import SwiftUI
import PhotosUI

/// Shown when no recipe could be extracted. Explains why and offers real alternatives —
/// any recipe chosen here is clearly labelled as coming from a different source.
struct NoRecipeView: View {
    @Bindable var session: ImportSession
    let link: String
    var onRetry: () -> Void
    var onManual: () -> Void
    var onBack: () -> Void

    @State private var query = ""
    @State private var mealResults: [MealDB.Meal] = []
    @State private var webResults: [AIRecipeSearch.WebResult] = []
    @State private var searchingMeals = false
    @State private var searchingWeb = false
    @State private var webError: String?
    @State private var loadingCandidate: String?
    @State private var dishItem: PhotosPickerItem?
    @State private var dishGuess: AIRecipeSearch.DishGuess?
    @State private var identifying = false
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                explanation
                if session.draft.hasContent || !(session.evidence?.title.isEmpty ?? true) { foundSoFar }
                addMore
                searchSection
                if ClaudeClient.isConfigured { dishSection }
                manualSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            if query.isEmpty {
                let q = session.draft.searchQuery.isEmpty ? (session.evidence?.title ?? "") : session.draft.searchQuery
                query = VideoSourceFetcher.firstLine(q)
            }
            if !query.isEmpty && mealResults.isEmpty { searchMeals() }
        }
    }

    private var explanation: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "magnifyingglass.circle.fill").font(.largeTitle).foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text("Couldn't identify the recipe automatically").font(.headline)
                Text(session.problem ?? "The video's public information doesn't include a recipe.")
                    .font(.subheadline).foregroundStyle(.secondary)
                if let notes = session.evidence?.notes, !notes.isEmpty {
                    ForEach(notes, id: \.self) { Text("• \($0)").font(.caption).foregroundStyle(.secondary) }
                }
            }
        }
        .card()
    }

    private var foundSoFar: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "What was found")
            HStack(alignment: .top, spacing: 12) {
                if let img = session.images.first, let ui = UIImage(data: img.data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                        .frame(width: 70, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                VStack(alignment: .leading, spacing: 4) {
                    if let e = session.evidence {
                        Text(e.title.isEmpty ? "Untitled video" : e.title).font(.subheadline.bold())
                        if !e.creator.isEmpty { Text("by \(e.creator)").font(.caption).foregroundStyle(.secondary) }
                        if !e.description.isEmpty {
                            Text(e.description).font(.caption).foregroundStyle(.secondary).lineLimit(4)
                        }
                    }
                    if session.draft.hasContent {
                        Button("Review partial recipe (\(session.draft.ingredients.count) ingredients)") {
                            session.phase = .result
                        }
                        .font(.caption.bold())
                    }
                }
            }
            .card(padding: 12)
        }
    }

    private var addMore: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Give the app more to work with")
            Button(action: onBack) {
                HStack(spacing: 12) {
                    Image(systemName: "photo.stack").font(.title3).foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add screenshots, the video file, or the caption").font(.subheadline.weight(.medium))
                        Text("Text in screenshots is read on device; video audio is transcribed on device.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
                .card(padding: 12)
            }
            .buttonStyle(.plain)
        }
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Find the recipe elsewhere",
                          subtitle: "Results are separate recipes — compare them with the video before saving.")
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Dish name", text: $query).onSubmit { searchMeals() }
                Button("Search") { searchMeals() }.font(.subheadline.bold()).disabled(query.isEmpty)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DS.smallCorner))

            if let errorText { Text(errorText).font(.caption).foregroundStyle(.red) }

            // TheMealDB
            if searchingMeals {
                ScrollView(.horizontal) { HStack { ForEach(0..<3, id: \.self) { _ in SkeletonCard(height: 200).frame(width: 160) } } }
            } else if !mealResults.isEmpty {
                Text("Similar recipes from TheMealDB").font(.subheadline.bold())
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(mealResults.prefix(10)) { meal in
                            Button { choose(meal) } label: { MealCard(meal: meal, loading: loadingCandidate == meal.id) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            } else if !query.isEmpty {
                Text("No similar recipes in TheMealDB for “\(query)”.").font(.caption).foregroundStyle(.secondary)
            }

            // Web search (AI)
            if ClaudeClient.isConfigured {
                Button { searchWeb() } label: {
                    HStack {
                        Label("Search the web for this recipe", systemImage: "globe")
                        Spacer()
                        if searchingWeb { ProgressView() }
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .disabled(searchingWeb || query.isEmpty)
                if let webError { Text(webError).font(.caption).foregroundStyle(.red) }
                ForEach(webResults) { r in
                    Button { choose(r) } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "doc.richtext").foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.title).font(.subheadline.weight(.medium)).foregroundStyle(.primary).multilineTextAlignment(.leading)
                                Text(r.site).font(.caption).foregroundStyle(.secondary)
                                if !r.reason.isEmpty { Text(r.reason).font(.caption2).foregroundStyle(.secondary) }
                            }
                            Spacer()
                            if loadingCandidate == r.url.absoluteString { ProgressView() }
                        }
                        .card(padding: 10)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let u = URL(string: "https://www.google.com/search?q=\(q)+recipe") {
                Link(destination: u) { Label("Search in your browser", systemImage: "safari") }
                    .font(.subheadline)
            }
        }
    }

    private var dishSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Identify the dish from a photo",
                          subtitle: "Use a screenshot of the finished dish to name it, then search for recipes.")
            PhotosPicker(selection: $dishItem, matching: .images) {
                HStack {
                    Label("Choose a photo of the dish", systemImage: "camera.viewfinder")
                    Spacer()
                    if identifying { ProgressView() }
                }
                .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            if let g = dishGuess {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Looks like: \(g.name)").font(.subheadline.bold())
                    Text("Confidence: \(g.confidence)").font(.caption).foregroundStyle(.secondary)
                    if !g.visibleIngredients.isEmpty {
                        Text("Visible: " + g.visibleIngredients.joined(separator: ", ")).font(.caption)
                    }
                    Text("This is an identification only, not the creator's recipe.").font(.caption2).foregroundStyle(.orange)
                }
                .card(padding: 12)
            }
        }
        .onChange(of: dishItem) { _, item in
            guard let item else { return }
            identifying = true
            Task {
                defer { identifying = false }
                guard let d = try? await item.loadTransferable(type: Data.self) else { return }
                do {
                    let g = try await AIRecipeSearch.identifyDish(d)
                    dishGuess = g
                    query = g.name
                    searchMeals()
                } catch { errorText = error.localizedDescription }
            }
        }
    }

    private var manualSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Or write it yourself")
            HStack {
                Button(action: onManual) { Label("Enter Recipe Manually", systemImage: "square.and.pencil") }
                    .buttonStyle(.borderedProminent)
                Button(action: onRetry) { Label("Try Again", systemImage: "arrow.clockwise") }
                    .buttonStyle(.bordered)
            }
        }
    }

    // MARK: Actions

    private func searchMeals() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        searchingMeals = true
        errorText = nil
        Task {
            mealResults = await MealDB.fuzzySearch(q)
            searchingMeals = false
        }
    }

    private func searchWeb() {
        searchingWeb = true
        webError = nil
        Task {
            do {
                let context = [session.evidence?.title ?? "", session.evidence?.creator ?? "", session.evidence?.description ?? ""]
                    .joined(separator: "\n")
                webResults = try await AIRecipeSearch.findRecipePages(query: query, context: context)
                if webResults.isEmpty { webError = "No recipe pages found." }
            } catch { webError = error.localizedDescription }
            searchingWeb = false
        }
    }

    private func choose(_ meal: MealDB.Meal) {
        loadingCandidate = meal.id
        Task {
            var d = await MealDB.draft(from: meal)
            d.originNote = "Similar recipe from TheMealDB — not extracted from your video. Compare it before saving."
            d.sourceKind = "discover"
            loadingCandidate = nil
            session.draft = d
            session.phase = .result
        }
    }

    private func choose(_ r: AIRecipeSearch.WebResult) {
        loadingCandidate = r.url.absoluteString
        Task {
            defer { loadingCandidate = nil }
            do {
                let imported = try await RecipeImporter.fetch(r.url.absoluteString)
                var d = ImportSession.draft(from: imported)
                d.sourceKind = "web"
                d.platform = "Website"
                d.originNote = "Recipe from \(r.site), found by web search — not extracted from your video. Compare it before saving."
                if let p = imported.photoData {
                    let img = DraftImage(data: p, label: "Photo from \(r.site)", kind: .sourcePhoto)
                    d.images = [img]
                    d.coverImageID = img.id
                }
                d.evidence = ["Structured recipe data on \(r.site)"]
                session.draft = d
                session.phase = .result
            } catch {
                webError = "\(r.site): \(error.localizedDescription)"
            }
        }
    }
}

struct MealCard: View {
    let meal: MealDB.Meal
    var loading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: meal.thumbURL.flatMap { URL(string: $0.absoluteString + "/preview") } ?? meal.thumbURL) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: Rectangle().fill(Color(.tertiarySystemFill))
                }
            }
            .frame(width: 160, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay { if loading { ProgressView().padding(8).background(.thinMaterial, in: Circle()) } }
            Text(meal.name).font(.subheadline.weight(.semibold)).lineLimit(2).foregroundStyle(.primary)
            Text([meal.area, meal.category].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(width: 160, alignment: .leading)
    }
}
