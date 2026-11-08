import SwiftUI
import SwiftData

private struct DayTarget: Identifiable {
    let date: Date
    let meal: String
    var replacing: MealPlanEntry?
    var id: String { "\(date.timeIntervalSince1970)-\(meal)" }
}

private struct MoveTarget: Identifiable {
    let entry: MealPlanEntry
    let copy: Bool
    var id: PersistentIdentifier { entry.persistentModelID }
}

/// Drag payloads are plain strings: "recipe:<uid>" or "entry:<id>".
enum PlanDrag {
    static func encode(_ entry: MealPlanEntry) -> String {
        let data = (try? JSONEncoder().encode(entry.persistentModelID)) ?? Data()
        return "entry:" + data.base64EncodedString()
    }

    static func entry(from s: String, in context: ModelContext) -> MealPlanEntry? {
        guard s.hasPrefix("entry:"), let data = Data(base64Encoded: String(s.dropFirst(6))),
              let id = try? JSONDecoder().decode(PersistentIdentifier.self, from: data) else { return nil }
        return context.model(for: id) as? MealPlanEntry
    }
}

struct MealPlanView: View {
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toasts
    @Query(sort: \MealPlanEntry.date) private var entries: [MealPlanEntry]
    @Query(sort: \Recipe.title) private var recipes: [Recipe]
    @Query(sort: \SavedMealPlan.createdAt, order: .reverse) private var savedPlans: [SavedMealPlan]
    @State private var weekStart = Calendar.current.startOfWeek(for: Date())
    @State private var adding: DayTarget?
    @State private var moving: MoveTarget?
    @State private var confirmClear = false
    @State private var naming = false
    @State private var planName = ""
    @State private var showingTemplates = false
    @State private var dropHighlight: String?

    private var days: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private var weekEntries: [MealPlanEntry] {
        guard let end = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) else { return [] }
        return entries.filter { $0.date >= weekStart && $0.date < end && $0.recipe != nil }
    }

    private func entries(on day: Date, meal: String) -> [MealPlanEntry] {
        weekEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: day) && $0.meal == meal }
    }

    private var trayRecipes: [Recipe] {
        recipes.sorted { a, b in
            if a.isFavorite != b.isFavorite { return a.isFavorite }
            return (a.lastViewed ?? .distantPast) > (b.lastViewed ?? .distantPast)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    weekSwitcher
                    if !recipes.isEmpty { tray }
                    ForEach(days, id: \.self) { day in dayCard(day) }
                }
                .padding(.horizontal)
                .padding(.bottom, 90)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Meal Plan")
            .navigationDestination(for: Recipe.self) { RecipeDetailView(recipe: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Add Week to Groceries", systemImage: "cart.badge.plus") { addWeekToShopping() }
                            .disabled(weekEntries.isEmpty)
                        Divider()
                        Button("Save Week as Plan…", systemImage: "square.and.arrow.down") { planName = ""; naming = true }
                            .disabled(weekEntries.isEmpty)
                        Button("Use a Saved Plan…", systemImage: "doc.on.doc") { showingTemplates = true }
                            .disabled(savedPlans.isEmpty)
                        Divider()
                        Button("Clear This Week", systemImage: "trash", role: .destructive) { confirmClear = true }
                            .disabled(weekEntries.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $adding) { t in
                PickRecipeSheet(date: t.date, meal: t.meal, replacing: t.replacing).sheetStyle()
            }
            .sheet(item: $moving) { m in
                MoveMealSheet(entry: m.entry, copy: m.copy).sheetStyle()
            }
            .sheet(isPresented: $showingTemplates) { templatesSheet.sheetStyle() }
            .alert("Save Meal Plan", isPresented: $naming) {
                TextField("Name, e.g. Healthy Week", text: $planName)
                Button("Save") { saveTemplate() }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Remove all meals planned this week?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear Week", role: .destructive) {
                    let removed = weekEntries.compactMap { e in e.recipe.map { (e.date, e.meal, $0) } }
                    for e in weekEntries { context.delete(e) }
                    toasts.show("Week cleared", style: .info, actionTitle: "Undo") {
                        for (d, m, r) in removed { context.insert(MealPlanEntry(date: d, meal: m, recipe: r)) }
                    }
                }
            }
        }
    }

    // MARK: Header & tray

    private var weekSwitcher: some View {
        HStack {
            Button { shiftWeek(-1) } label: { Image(systemName: "chevron.left.circle.fill").font(.title2) }
                .accessibilityLabel("Previous week")
            Spacer()
            VStack(spacing: 2) {
                Text(weekTitle).font(.headline)
                let total = weekEntries.compactMap(\.recipe).reduce(0) { $0 + $1.totalMinutes }
                Text("\(weekEntries.count) meal\(weekEntries.count == 1 ? "" : "s")\(total > 0 ? " · ≈ \(Recipe.format(minutes: total)) cooking" : "")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .onTapGesture { withAnimation { weekStart = Calendar.current.startOfWeek(for: Date()) } }
            Spacer()
            Button { shiftWeek(1) } label: { Image(systemName: "chevron.right.circle.fill").font(.title2) }
                .accessibilityLabel("Next week")
        }
        .foregroundStyle(Color.accentColor)
        .padding(.top, 8)
    }

    private var tray: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Drag a recipe onto a meal").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(trayRecipes.prefix(25)) { r in
                        HStack(spacing: 6) {
                            RecipeThumbnail(recipe: r, size: 28)
                            Text(r.title).font(.caption.weight(.medium)).lineLimit(1)
                        }
                        .padding(.leading, 4).padding(.trailing, 10).padding(.vertical, 4)
                        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                        .draggable("recipe:\(r.uid)") {
                            Label(r.title, systemImage: "fork.knife").padding(8).background(.regularMaterial, in: Capsule())
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: Days

    private func dayCard(_ day: Date) -> some View {
        let isToday = Calendar.current.isDateInToday(day)
        let dayEntries = weekEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
        let minutes = dayEntries.compactMap(\.recipe).reduce(0) { $0 + $1.totalMinutes }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(day.formatted(.dateTime.weekday(.wide))).font(.headline)
                    .foregroundStyle(isToday ? Color.accentColor : .primary)
                Text(day.formatted(.dateTime.month(.abbreviated).day())).foregroundStyle(.secondary)
                if isToday { Badge(text: "TODAY") }
                Spacer()
                if minutes > 0 {
                    Label(Recipe.format(minutes: minutes), systemImage: "clock").font(.caption).foregroundStyle(.secondary)
                }
            }
            ForEach(MealPlanEntry.meals, id: \.self) { meal in
                slot(day: day, meal: meal)
            }
        }
        .card(padding: 14)
        .overlay(RoundedRectangle(cornerRadius: DS.corner).stroke(isToday ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1.5))
    }

    private func slot(day: Date, meal: String) -> some View {
        let key = "\(day.timeIntervalSince1970)-\(meal)"
        let list = entries(on: day, meal: meal)
        return HStack(alignment: .center, spacing: 8) {
            Text(meal == "Breakfast" ? "Bkfst" : meal)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(list) { entry in entryChip(entry) }
                    Button { adding = DayTarget(date: day, meal: meal) } label: {
                        Image(systemName: "plus")
                            .font(.caption.bold())
                            .frame(width: 30, height: 30)
                            .background(Color(.tertiarySystemFill), in: Circle())
                    }
                    .accessibilityLabel("Add \(meal) on \(day.formatted(.dateTime.weekday(.wide)))")
                }
            }
        }
        .padding(4)
        .background(dropHighlight == key ? Color.accentColor.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 10))
        .dropDestination(for: String.self) { items, _ in
            handleDrop(items, day: day, meal: meal)
        } isTargeted: { on in
            dropHighlight = on ? key : (dropHighlight == key ? nil : dropHighlight)
        }
    }

    @ViewBuilder private func entryChip(_ entry: MealPlanEntry) -> some View {
        if let r = entry.recipe {
            NavigationLink(value: r) {
                HStack(spacing: 6) {
                    RecipeThumbnail(recipe: r, size: 30)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(r.title).font(.caption.weight(.semibold)).lineLimit(1)
                        if r.totalMinutes > 0 {
                            Text(Recipe.format(minutes: r.totalMinutes)).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.leading, 3).padding(.trailing, 10).padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
            .draggable(PlanDrag.encode(entry)) {
                Label(r.title, systemImage: "fork.knife").padding(8).background(.regularMaterial, in: Capsule())
            }
            .contextMenu {
                Button("Replace…", systemImage: "arrow.triangle.2.circlepath") {
                    adding = DayTarget(date: entry.date, meal: entry.meal, replacing: entry)
                }
                Button("Copy to Another Day…", systemImage: "doc.on.doc") { moving = MoveTarget(entry: entry, copy: true) }
                Button("Move…", systemImage: "arrow.right.square") { moving = MoveTarget(entry: entry, copy: false) }
                Button("Remove", systemImage: "trash", role: .destructive) { remove(entry) }
            }
        }
    }

    // MARK: Actions

    private func handleDrop(_ items: [String], day: Date, meal: String) -> Bool {
        guard let s = items.first else { return false }
        if s.hasPrefix("recipe:") {
            let uid = String(s.dropFirst(7))
            guard let r = recipes.first(where: { $0.uid == uid }) else { return false }
            context.insert(MealPlanEntry(date: day, meal: meal, recipe: r))
            return true
        }
        if let e = PlanDrag.entry(from: s, in: context) {
            withAnimation(.snappy) {
                e.date = Calendar.current.startOfDay(for: day)
                e.meal = meal
            }
            return true
        }
        return false
    }

    private func remove(_ entry: MealPlanEntry) {
        guard let r = entry.recipe else { return }
        let (d, m) = (entry.date, entry.meal)
        context.delete(entry)
        toasts.show("Removed \(r.title)", style: .info, actionTitle: "Undo") {
            context.insert(MealPlanEntry(date: d, meal: m, recipe: r))
        }
    }

    private var weekTitle: String {
        let cal = Calendar.current
        if cal.isDate(weekStart, equalTo: Date(), toGranularity: .weekOfYear) { return "This Week" }
        if let next = cal.date(byAdding: .weekOfYear, value: 1, to: Date()),
           cal.isDate(weekStart, equalTo: next, toGranularity: .weekOfYear) { return "Next Week" }
        if let last = cal.date(byAdding: .weekOfYear, value: -1, to: Date()),
           cal.isDate(weekStart, equalTo: last, toGranularity: .weekOfYear) { return "Last Week" }
        return "Week of " + weekStart.formatted(.dateTime.month(.abbreviated).day())
    }

    private func shiftWeek(_ n: Int) {
        if let d = Calendar.current.date(byAdding: .weekOfYear, value: n, to: weekStart) {
            withAnimation { weekStart = d }
        }
    }

    private func addWeekToShopping() {
        var total = 0
        for e in weekEntries {
            if let r = e.recipe { total += ShoppingItem.add(r.ingredients, from: r.title, in: context) }
        }
        toasts.show(total == 0 ? "Everything's already on your list" : "Added \(total) items to Groceries 🛒")
    }

    private func saveTemplate() {
        let slots = weekEntries.compactMap { e -> SavedMealSlot? in
            guard let r = e.recipe else { return nil }
            let offset = Calendar.current.dateComponents([.day], from: weekStart, to: e.date).day ?? 0
            return SavedMealSlot(dayOffset: offset, meal: e.meal, recipeUID: r.uid, recipeTitle: r.title)
        }
        let name = planName.trimmingCharacters(in: .whitespaces)
        context.insert(SavedMealPlan(name: name.isEmpty ? "Plan from \(weekTitle)" : name, slots: slots))
        toasts.show("Meal plan saved")
    }

    private var templatesSheet: some View {
        NavigationStack {
            List {
                ForEach(savedPlans) { plan in
                    let slots = plan.slots
                    Button {
                        var added = 0
                        for s in slots {
                            guard let r = recipes.first(where: { $0.uid == s.recipeUID }),
                                  let d = Calendar.current.date(byAdding: .day, value: s.dayOffset, to: weekStart) else { continue }
                            context.insert(MealPlanEntry(date: d, meal: s.meal, recipe: r))
                            added += 1
                        }
                        showingTemplates = false
                        toasts.show(added == slots.count ? "Added \(added) meals" : "Added \(added) of \(slots.count) meals (some recipes were deleted)")
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(plan.name).font(.headline).foregroundStyle(.primary)
                            Text(slots.map(\.recipeTitle).prefix(4).joined(separator: ", ") + (slots.count > 4 ? "…" : ""))
                                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                }
                .onDelete { idx in for i in idx { context.delete(savedPlans[i]) } }
            }
            .navigationTitle("Saved Plans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingTemplates = false } } }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Choose a recipe for a day + meal (or to replace an existing entry).
struct PickRecipeSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Recipe.title) private var recipes: [Recipe]
    let date: Date
    @State var meal: String
    var replacing: MealPlanEntry?
    @State private var search = ""

    init(date: Date, meal: String = "Dinner", replacing: MealPlanEntry? = nil) {
        self.date = date
        self._meal = State(initialValue: meal)
        self.replacing = replacing
    }

    private var filtered: [Recipe] {
        search.isEmpty ? recipes : recipes.filter {
            $0.title.localizedCaseInsensitiveContains(search) || $0.tags.contains { $0.localizedCaseInsensitiveContains(search) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Meal", selection: $meal) {
                        ForEach(MealPlanEntry.meals, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section(replacing == nil ? "Choose a recipe" : "Replace with") {
                    if recipes.isEmpty {
                        Text("Add some recipes first.").foregroundStyle(.secondary)
                    }
                    ForEach(filtered) { recipe in
                        Button {
                            if let e = replacing {
                                e.recipe = recipe
                                e.meal = meal
                            } else {
                                context.insert(MealPlanEntry(date: date, meal: meal, recipe: recipe))
                            }
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                RecipeThumbnail(recipe: recipe, size: 44)
                                VStack(alignment: .leading) {
                                    Text(recipe.title).foregroundStyle(.primary)
                                    if recipe.totalMinutes > 0 {
                                        Text(Recipe.format(minutes: recipe.totalMinutes)).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if recipe.isFavorite { Image(systemName: "heart.fill").foregroundStyle(.pink) }
                            }
                        }
                    }
                }
            }
            .searchable(text: $search)
            .navigationTitle(date.formatted(.dateTime.weekday(.wide).month().day()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Copy or move a planned meal to another day/meal.
struct MoveMealSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let entry: MealPlanEntry
    let copy: Bool
    @State private var date = Date()
    @State private var meal = "Dinner"

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Day", selection: $date, displayedComponents: .date).datePickerStyle(.graphical)
                Picker("Meal", selection: $meal) {
                    ForEach(MealPlanEntry.meals, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .navigationTitle(copy ? "Copy Meal" : "Move Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(copy ? "Copy" : "Move") {
                        if copy {
                            context.insert(MealPlanEntry(date: date, meal: meal, recipe: entry.recipe))
                        } else {
                            entry.date = Calendar.current.startOfDay(for: date)
                            entry.meal = meal
                        }
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear { date = entry.date; meal = entry.meal }
        }
        .presentationDetents([.large])
    }
}

/// Choose a day to cook a given recipe.
struct PlanRecipeSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    var onDone: (String) -> Void = { _ in }
    @State private var date = Date()
    @State private var meal = "Dinner"

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Day", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                Picker("Meal", selection: $meal) {
                    ForEach(MealPlanEntry.meals, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .navigationTitle("Plan \(recipe.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        context.insert(MealPlanEntry(date: date, meal: meal, recipe: recipe))
                        onDone("Planned for \(date.formatted(.dateTime.weekday(.wide)))")
                        dismiss()
                    }
                    .bold()
                }
            }
        }
        .presentationDetents([.large])
    }
}
