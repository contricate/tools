import SwiftUI
import SwiftData
import UserNotifications
import UniformTypeIdentifiers

// MARK: - Toast

struct ToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message {
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: message) {
                        try? await Task.sleep(for: .seconds(2.2))
                        withAnimation { self.message = nil }
                    }
            }
        }
        .animation(.spring(duration: 0.35), value: message)
    }
}

extension View {
    func toast(_ message: Binding<String?>) -> some View { modifier(ToastModifier(message: message)) }
}

// MARK: - Small shared views

struct RecipeThumbnail: View {
    let recipe: Recipe
    let size: CGFloat

    var body: some View {
        Group {
            if let data = recipe.photoData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                CategoryPlaceholder(category: recipe.category, iconSize: size * 0.4)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CategoryPlaceholder: View {
    let category: String
    var iconSize: CGFloat = 40

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.12)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: Recipe.icon(for: category))
                .font(.system(size: iconSize))
                .foregroundStyle(Color.accentColor)
        }
    }
}

struct StarRating: View {
    @Binding var rating: Int
    var size: CGFloat = 20
    var editable = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(i <= rating ? Color.yellow : Color.secondary.opacity(0.5))
                    .onTapGesture {
                        guard editable else { return }
                        rating = (rating == i) ? 0 : i
                    }
            }
        }
        .sensoryFeedback(.selection, trigger: rating)
    }
}

// MARK: - Helpers

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        dateInterval(of: .weekOfYear, for: date)?.start ?? startOfDay(for: date)
    }
}

extension ShoppingItem {
    var parsed: ParsedIngredient {
        var p = IngredientParser.parse(name)
        if amount > 0 {
            p.amount = amount
            p.unit = CookUnit(rawValue: unit)
            if p.unit == nil { p.countWord = unit }
        }
        return p
    }

    var aisle: String { aisleOverride.isEmpty ? GroceryAisle.classify(baseName.isEmpty ? name : baseName) : aisleOverride }

    func apply(_ p: ParsedIngredient) {
        amount = p.amount ?? 0
        unit = p.unit?.rawValue ?? p.countWord
        baseName = IngredientParser.key(for: p.name)
        name = GroceryMath.describe(p)
    }

    /// Adds lines to the grocery list, combining with matching unchecked items when units are compatible.
    /// Returns how many lines were added or merged.
    @discardableResult
    static func add(_ lines: [String], from recipeTitle: String, in context: ModelContext) -> Int {
        let existing = ((try? context.fetch(FetchDescriptor<ShoppingItem>())) ?? []).filter { !$0.isChecked }
        var pool = existing
        var changed = 0
        for line in lines {
            let text = line.replacingOccurrences(of: " (estimated)", with: "")
                .replacingOccurrences(of: " — amount not given", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let p = IngredientParser.parse(text)
            let key = IngredientParser.key(for: p.name)
            if let match = pool.first(where: { GroceryMath.combine($0.parsed, p) != nil }),
               let merged = GroceryMath.combine(match.parsed, p) {
                match.apply(merged)
                if !recipeTitle.isEmpty && !match.fromRecipe.contains(recipeTitle) {
                    match.fromRecipe = match.fromRecipe.isEmpty ? recipeTitle : match.fromRecipe + ", " + recipeTitle
                }
                changed += 1
                continue
            }
            // Same ingredient without amounts (e.g. "salt") — don't add twice.
            if p.amount == nil, pool.contains(where: { $0.amount == 0 && IngredientParser.key(for: $0.parsed.name) == key && !key.isEmpty }) {
                continue
            }
            let item = ShoppingItem(name: text, fromRecipe: recipeTitle)
            if p.amount != nil { item.apply(p) } else { item.baseName = key }
            context.insert(item)
            pool.append(item)
            changed += 1
        }
        return changed
    }
}

final class NotificationHelper: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationHelper()

    func activate() {
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func schedule(id: String, title: String, body: String, after seconds: Int) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, seconds)), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func cancel(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    // Show timer alerts even while the app is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

// MARK: - Backup file

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum Backup {
    static func export(_ recipes: [Recipe]) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(BackupFile(recipes: recipes.map(RecipeBackup.init)))
    }

    /// Returns how many recipes were added.
    static func restore(from url: URL, into context: ModelContext, existing: [Recipe]) throws -> Int {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var titles = Set(existing.map { $0.title.lowercased() })
        guard let file = try? decoder.decode(BackupFile.self, from: data) else {
            // Also accept standard schema.org Recipe JSON files.
            let obj = try JSONSerialization.jsonObject(with: data)
            guard let imported = RecipeImporter.recipe(fromJSONObject: obj) else { throw CocoaError(.fileReadCorruptFile) }
            guard !titles.contains(imported.title.lowercased()) else { return 0 }
            var d = ImportSession.draft(from: imported)
            d.sourceKind = "file"
            d.platform = ""
            context.insert(d.makeRecipe())
            return 1
        }
        var added = 0
        for item in file.recipes where !titles.contains(item.title.lowercased()) {
            context.insert(item.makeRecipe())
            titles.insert(item.title.lowercased())
            added += 1
        }
        return added
    }
}

// MARK: - Camera

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
