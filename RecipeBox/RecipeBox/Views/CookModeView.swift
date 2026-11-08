import SwiftUI

struct CookModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TimerStore.self) private var timers
    @Environment(AppRouter.self) private var router
    let recipe: Recipe
    let factor: Double

    @AppStorage(SettingsKey.cookKeepAwake) private var keepAwake = true
    @AppStorage(SettingsKey.cookTextSize) private var textSizeRaw = CookTextSize.large.rawValue
    @AppStorage(SettingsKey.cookShowStepIngredients) private var showStepIngredients = true
    @AppStorage(SettingsKey.measurementSystem) private var systemRaw = MeasurementSystem.original.rawValue

    @State private var page = 0
    @State private var gathered: Set<Int> = []
    @State private var showIngredients = false
    @State private var confirmExit = false
    @State private var resumed = false

    private var lastPage: Int { recipe.steps.count + 1 }
    private var textSize: CGFloat { (CookTextSize(rawValue: textSizeRaw) ?? .large).points }
    private var system: MeasurementSystem { MeasurementSystem(rawValue: systemRaw) ?? .original }

    private func ingredientText(_ line: String) -> String {
        UnitConverter.convert(IngredientScaler.scale(line, by: factor), to: system)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressHeader
                TabView(selection: $page) {
                    ingredientsPage.tag(0)
                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                        stepPage(index: index, text: step).tag(index + 1)
                    }
                    donePage.tag(lastPage)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: page)

                if !timers.timers.isEmpty { TimerStrip().padding(.vertical, 8) }
                navButtons
            }
            .navigationTitle(recipe.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { requestExit() } label: { Image(systemName: "xmark.circle.fill").font(.title3) }
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Close cooking mode")
                        .keyboardShortcut(.escape, modifiers: [])
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showIngredients = true } label: { Image(systemName: "list.bullet.clipboard") }
                        .accessibilityLabel("Ingredient checklist")
                }
            }
            .sheet(isPresented: $showIngredients) { checklistSheet.sheetStyle() }
            .confirmationDialog("Leave Cooking Mode?", isPresented: $confirmExit, titleVisibility: .visible) {
                Button("Save Progress & Leave") { saveProgress(); close() }
                Button("Finish & Clear Progress", role: .destructive) { CookProgress.clear(recipe.uid); close() }
            } message: {
                Text("Your place and checked ingredients can be saved so you can pick up where you left off. Timers keep running.")
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: page)
        .onAppear {
            if keepAwake { UIApplication.shared.isIdleTimerDisabled = true }
            if let p = CookProgress.load(recipe.uid), !resumed {
                page = min(p.page, lastPage)
                gathered = Set(p.gathered)
                resumed = true
            }
            if UserDefaults.standard.bool(forKey: SettingsKey.timerAlerts) { NotificationHelper.shared.requestPermission() }
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: page) { _, _ in saveProgress() }
        .onChange(of: gathered) { _, _ in saveProgress() }
        .interactiveDismissDisabled()
    }

    private func requestExit() {
        if page > 0 && page < lastPage { confirmExit = true } else { close() }
    }

    private func close() {
        router.cookRecipe = nil
        dismiss()
    }

    private func saveProgress() {
        guard page > 0 || !gathered.isEmpty, page < lastPage else { return }
        CookProgress.save(CookProgress(page: page, gathered: Array(gathered), savedAt: Date()), uid: recipe.uid)
    }

    // MARK: Header

    private var progressHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(0...lastPage, id: \.self) { i in
                    Capsule()
                        .fill(i <= page ? Color.accentColor : Color(.tertiarySystemFill))
                        .frame(height: 5)
                        .onTapGesture { page = i }
                }
            }
            HStack {
                Text(page == 0 ? "Ingredients" : page == lastPage ? "Finished" : "Step \(page) of \(recipe.steps.count)")
                Spacer()
                if resumed && page > 0 && page < lastPage { Text("Resumed").foregroundStyle(Color.accentColor) }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
    }

    // MARK: Pages

    private var ingredientsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Gather your ingredients").font(.title.bold())
                Text("Tap each one as you set it out\(factor != 1 ? " · scaled ×\(UnitConverter.trim(factor, 2))" : "").")
                    .foregroundStyle(.secondary)
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, item in
                    ingredientRow(index: index, text: ingredientText(item), font: .title3)
                }
            }
            .padding(24)
        }
    }

    private func ingredientRow(index: Int, text: String, font: Font) -> some View {
        Button {
            if gathered.contains(index) { gathered.remove(index) } else { gathered.insert(index) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: gathered.contains(index) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(gathered.contains(index) ? Color.accentColor : .secondary)
                Text(text)
                    .font(font)
                    .strikethrough(gathered.contains(index))
                    .foregroundStyle(gathered.contains(index) ? .secondary : .primary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: gathered.contains(index))
    }

    /// Ingredients whose main word appears in the step text.
    private func ingredientsUsed(in step: String) -> [(Int, String)] {
        let lower = step.lowercased()
        return recipe.ingredients.enumerated().compactMap { i, line in
            let key = IngredientParser.key(for: IngredientParser.parse(line).name)
            let words = key.split(separator: " ").map(String.init).filter { $0.count > 2 }
            guard let main = words.last ?? words.first else { return nil }
            return lower.contains(main) ? (i, line) : nil
        }
    }

    private func stepPage(index: Int, text: String) -> some View {
        let stepText = UnitConverter.convertTemperatures(in: text, to: system)
        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("STEP \(index + 1)")
                    .font(.caption.weight(.heavy)).tracking(1.4)
                    .foregroundStyle(Color.accentColor)
                Text(stepText)
                    .font(.system(size: textSize, weight: .medium, design: .rounded))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                let found = TimerDetector.find(in: text)
                if !found.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(found, id: \.self) { f in
                            Button {
                                timers.start(label: "Step \(index + 1): \(f.label)", recipeTitle: recipe.title, seconds: f.seconds)
                            } label: {
                                Label("Start \(f.label) timer", systemImage: "timer")
                                    .font(.headline)
                                    .padding(.horizontal, 16).padding(.vertical, 12)
                                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                            }
                            .sensoryFeedback(.start, trigger: timers.timers.count)
                        }
                    }
                }

                if showStepIngredients {
                    let used = ingredientsUsed(in: text)
                    if !used.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("For this step").font(.subheadline.bold()).foregroundStyle(.secondary)
                            ForEach(used, id: \.0) { i, line in
                                ingredientRow(index: i, text: ingredientText(line), font: .body)
                            }
                        }
                        .card()
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var donePage: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "party.popper.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.bounce, value: page == lastPage)
            Text("All done!").font(.largeTitle.bold())
            Text("Enjoy your \(recipe.title).")
                .font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button {
                recipe.timesCooked += 1
                recipe.lastCooked = Date()
                CookProgress.clear(recipe.uid)
                close()
            } label: {
                Label("I Made This!", systemImage: "checkmark.seal.fill").font(.headline).frame(maxWidth: 280)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top)
            Button("Close Without Logging") { CookProgress.clear(recipe.uid); close() }
                .font(.subheadline)
            Spacer()
        }
        .padding()
    }

    private var checklistSheet: some View {
        NavigationStack {
            List {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { i, line in
                    ingredientRow(index: i, text: ingredientText(line), font: .body)
                }
            }
            .navigationTitle("Ingredients")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showIngredients = false } } }
        }
        .presentationDetents([.medium, .large])
    }

    private var navButtons: some View {
        HStack(spacing: 12) {
            Button { page = max(0, page - 1) } label: {
                Label("Back", systemImage: "chevron.left").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(page == 0)
            .keyboardShortcut(.leftArrow, modifiers: [])

            Button { page = min(lastPage, page + 1) } label: {
                Label(page == 0 ? "Start" : page == recipe.steps.count ? "Finish" : "Next", systemImage: "chevron.right")
                    .labelStyle(TrailingIconLabelStyle())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(page == lastPage)
            .keyboardShortcut(.rightArrow, modifiers: [])
        }
        .controlSize(.large)
        .padding()
    }
}

struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.title
            configuration.icon
        }
    }
}
