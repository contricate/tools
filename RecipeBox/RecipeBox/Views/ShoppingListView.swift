import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toasts
    @Query(sort: \ShoppingItem.createdAt) private var items: [ShoppingItem]
    @State private var newItem = ""
    @State private var editing: ShoppingItem?
    @State private var confirmClearAll = false
    @FocusState private var fieldFocused: Bool

    private var unchecked: [ShoppingItem] { items.filter { !$0.isChecked } }
    private var checked: [ShoppingItem] { items.filter { $0.isChecked } }
    private var aisles: [String] {
        let used = Set(unchecked.map(\.aisle))
        return GroceryAisle.order.filter { used.contains($0) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "plus.circle.fill").foregroundStyle(Color.accentColor).font(.title3)
                        TextField("Add item, e.g. 2 lb potatoes", text: $newItem)
                            .focused($fieldFocused)
                            .submitLabel(.done)
                            .onSubmit(add)
                    }
                    if !items.isEmpty {
                        HStack {
                            Text("\(unchecked.count) to buy · \(checked.count) in cart").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            ProgressView(value: Double(checked.count), total: Double(max(1, items.count)))
                                .frame(width: 90)
                        }
                    }
                }
                if items.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label("Your list is empty", systemImage: "cart")
                        } description: {
                            Text("Add items above, or open a recipe or your meal plan and add its ingredients.")
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                ForEach(aisles, id: \.self) { aisle in
                    let list = unchecked.filter { $0.aisle == aisle }
                    Section {
                        ForEach(list) { row($0) }
                            .onDelete { delete($0, from: list) }
                    } header: {
                        Label("\(aisle)", systemImage: GroceryAisle.icon(aisle))
                    }
                }
                if !checked.isEmpty {
                    Section {
                        ForEach(checked) { row($0) }
                            .onDelete { delete($0, from: checked) }
                    } header: {
                        HStack {
                            Text("In Cart (\(checked.count))")
                            Spacer()
                            Button("Clear") { clearChecked() }.font(.caption.bold()).textCase(nil)
                        }
                    }
                }
            }
            .animation(.snappy, value: items.map(\.isChecked))
            .navigationTitle("Groceries")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Clear Completed Items", systemImage: "checkmark.circle") { clearChecked() }
                            .disabled(checked.isEmpty)
                        ShareLink(item: shareText) { Label("Share List", systemImage: "square.and.arrow.up") }
                        Button("Copy List", systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = shareText
                            toasts.show("List copied")
                        }
                        Divider()
                        Button("Clear Everything", systemImage: "trash", role: .destructive) { confirmClearAll = true }
                            .disabled(items.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .confirmationDialog("Remove all \(items.count) items?", isPresented: $confirmClearAll, titleVisibility: .visible) {
                Button("Clear Everything", role: .destructive) { remove(items, message: "List cleared") }
            }
            .sheet(item: $editing) { item in GroceryItemEditor(item: item).themed() }
        }
    }

    private func row(_ item: ShoppingItem) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.snappy) { item.isChecked.toggle() }
            } label: {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isChecked ? Color.accentColor : .secondary)
                    .font(.title3)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isChecked ? "Uncheck \(item.name)" : "Check off \(item.name)")
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .strikethrough(item.isChecked)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
                if !item.fromRecipe.isEmpty {
                    Text(item.fromRecipe).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture { editing = item }
        .sensoryFeedback(.selection, trigger: item.isChecked)
        .swipeActions(edge: .leading) {
            Button { editing = item } label: { Label("Edit", systemImage: "pencil") }.tint(.blue)
        }
    }

    private var shareText: String {
        var text = "Grocery List"
        for aisle in aisles {
            text += "\n\n\(aisle.uppercased())\n"
            text += unchecked.filter { $0.aisle == aisle }.map { "☐ \($0.name)" }.joined(separator: "\n")
        }
        return text
    }

    private func add() {
        let t = newItem.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        ShoppingItem.add([t], from: "", in: context)
        newItem = ""
        fieldFocused = true
    }

    private func clearChecked() { remove(checked, message: "Cleared \(checked.count) item\(checked.count == 1 ? "" : "s")") }

    private func delete(_ offsets: IndexSet, from list: [ShoppingItem]) {
        remove(offsets.map { list[$0] }, message: offsets.count == 1 ? "Item removed" : "\(offsets.count) items removed")
    }

    /// Removes items with an Undo option.
    private func remove(_ list: [ShoppingItem], message: String) {
        let snapshot = list.map { ($0.name, $0.fromRecipe, $0.isChecked, $0.amount, $0.unit, $0.baseName, $0.aisleOverride) }
        for i in list { context.delete(i) }
        toasts.show(message, style: .info, actionTitle: "Undo") {
            for s in snapshot {
                let item = ShoppingItem(name: s.0, fromRecipe: s.1)
                item.isChecked = s.2; item.amount = s.3; item.unit = s.4; item.baseName = s.5; item.aisleOverride = s.6
                context.insert(item)
            }
        }
    }
}

struct GroceryItemEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var item: ShoppingItem
    @State private var text = ""
    @State private var aisle = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("e.g. 500 g chicken thighs", text: $text, axis: .vertical)
                }
                if item.amount > 0 {
                    Section("Quantity") {
                        Stepper(value: Binding(get: { item.amount }, set: { item.amount = max(0, $0); refreshName() }),
                                in: 0...10000, step: stepSize) {
                            Text("\(UnitConverter.format(item.amount, unit: CookUnit(rawValue: item.unit))) \(item.unit)")
                        }
                    }
                }
                Section("Aisle") {
                    Picker("Aisle", selection: $aisle) {
                        Text("Automatic").tag("")
                        ForEach(GroceryAisle.order, id: \.self) { Label($0, systemImage: GroceryAisle.icon($0)).tag($0) }
                    }
                }
                if !item.fromRecipe.isEmpty {
                    Section("From") { Text(item.fromRecipe) }
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let t = text.trimmingCharacters(in: .whitespaces)
                        if !t.isEmpty && t != item.name {
                            let p = IngredientParser.parse(t)
                            item.name = t
                            if p.amount != nil { item.apply(p) } else { item.amount = 0; item.unit = ""; item.baseName = IngredientParser.key(for: t) }
                        }
                        item.aisleOverride = aisle
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear { text = item.name; aisle = item.aisleOverride }
        }
        .presentationDetents([.medium, .large])
    }

    private var stepSize: Double {
        switch CookUnit(rawValue: item.unit) {
        case .g?, .ml?: return item.amount >= 100 ? 50 : 10
        case .kg?, .l?, .lb?: return 0.25
        default: return item.amount < 2 ? 0.25 : 1
        }
    }

    private func refreshName() {
        item.name = GroceryMath.describe(item.parsed)
        text = item.name
    }
}
