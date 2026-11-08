import SwiftUI
import SwiftData

struct CollectionsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RecipeCollection.name) private var collections: [RecipeCollection]
    @State private var showingNew = false

    var body: some View {
        ScrollView {
            if collections.isEmpty {
                ContentUnavailableView {
                    Label("No collections yet", systemImage: "folder")
                } description: {
                    Text("Group recipes into folders like “Weeknight Dinners” or “Holiday Baking”.")
                } actions: {
                    Button("New Collection") { showingNew = true }.buttonStyle(.borderedProminent)
                }
                .padding(.top, 60)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 14)], spacing: 14) {
                ForEach(collections) { c in
                    NavigationLink(value: c) { CollectionTile(collection: c) }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Delete Collection", systemImage: "trash", role: .destructive) { context.delete(c) }
                        }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Collections")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingNew = true } label: { Image(systemName: "folder.badge.plus") }
                    .accessibilityLabel("New collection")
            }
        }
        .sheet(isPresented: $showingNew) { NewCollectionSheet().sheetStyle() }
    }
}

struct CollectionTile: View {
    let collection: RecipeCollection

    var body: some View {
        let recipes = collection.recipes ?? []
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                let photos = recipes.compactMap(\.photoData).prefix(4)
                if photos.isEmpty {
                    RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.15))
                    Image(systemName: collection.icon).font(.largeTitle).foregroundStyle(Color.accentColor)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)], spacing: 2) {
                        ForEach(Array(photos.enumerated()), id: \.offset) { _, d in
                            if let ui = UIImage(data: d) {
                                Color.clear.aspectRatio(1, contentMode: .fit)
                                    .overlay { Image(uiImage: ui).resizable().scaledToFill() }.clipped()
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .frame(height: 130)
            Label(collection.name, systemImage: collection.icon).font(.headline).lineLimit(1)
            Text("\(recipes.count) recipe\(recipes.count == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
        }
        .card(padding: 10)
    }
}

struct CollectionDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var collection: RecipeCollection
    @State private var renaming = false
    @State private var confirmDelete = false

    var body: some View {
        let recipes = (collection.recipes ?? []).sorted { $0.title < $1.title }
        ScrollView {
            if recipes.isEmpty {
                ContentUnavailableView("Empty collection", systemImage: collection.icon,
                                       description: Text("Open any recipe and choose ⋯ → Add to Collection."))
                    .padding(.top, 60)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 14)], spacing: 14) {
                ForEach(recipes) { r in
                    NavigationLink(value: r) { RecipeCard(recipe: r) }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Remove from Collection", systemImage: "folder.badge.minus") {
                                collection.recipes?.removeAll { $0.persistentModelID == r.persistentModelID }
                            }
                        }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(collection.name)
        .toolbar {
            Menu {
                Button("Rename", systemImage: "pencil") { renaming = true }
                Picker("Icon", selection: $collection.icon) {
                    ForEach(RecipeCollection.icons, id: \.self) { Label($0, systemImage: $0).tag($0) }
                }
                Button("Delete Collection", systemImage: "trash", role: .destructive) { confirmDelete = true }
            } label: { Image(systemName: "ellipsis.circle") }
        }
        .alert("Rename Collection", isPresented: $renaming) {
            TextField("Name", text: $collection.name)
            Button("Done") {}
        }
        .confirmationDialog("Delete this collection? Recipes are kept.", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Collection", role: .destructive) {
                context.delete(collection)
                dismiss()
            }
        }
    }
}

struct NewCollectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    var addRecipe: Recipe? = nil
    @State private var name = ""
    @State private var icon = "folder"

    var body: some View {
        NavigationStack {
            Form {
                TextField("Collection name", text: $name)
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                        ForEach(RecipeCollection.icons, id: \.self) { i in
                            Image(systemName: i)
                                .font(.title3)
                                .frame(width: 40, height: 40)
                                .background(icon == i ? Color.accentColor.opacity(0.2) : .clear, in: Circle())
                                .onTapGesture { icon = i }
                        }
                    }
                }
            }
            .navigationTitle("New Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let c = RecipeCollection(name: name.trimmingCharacters(in: .whitespaces), icon: icon)
                        context.insert(c)
                        if let r = addRecipe { c.recipes = [r] }
                        dismiss()
                    }
                    .bold()
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct CollectionPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \RecipeCollection.name) private var collections: [RecipeCollection]
    let recipe: Recipe
    @State private var showingNew = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(collections) { c in
                    let isIn = (c.recipes ?? []).contains { $0.persistentModelID == recipe.persistentModelID }
                    Button {
                        if isIn {
                            c.recipes?.removeAll { $0.persistentModelID == recipe.persistentModelID }
                        } else {
                            if c.recipes == nil { c.recipes = [] }
                            c.recipes?.append(recipe)
                        }
                    } label: {
                        HStack {
                            Label(c.name, systemImage: c.icon).foregroundStyle(.primary)
                            Spacer()
                            if isIn { Image(systemName: "checkmark").foregroundStyle(Color.accentColor) }
                        }
                    }
                }
                Button { showingNew = true } label: { Label("New Collection…", systemImage: "folder.badge.plus") }
            }
            .navigationTitle("Collections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.bold() } }
            .sheet(isPresented: $showingNew) { NewCollectionSheet(addRecipe: recipe).sheetStyle() }
        }
        .presentationDetents([.medium, .large])
    }
}
