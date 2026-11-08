import AppIntents
import Foundation

struct ThemeEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Theme"
    static var defaultQuery = ThemeQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    init(id: String, name: String) { self.id = id; self.name = name }
    init(_ t: Theme) { id = t.id.uuidString; name = t.name }
}

struct ThemeQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [ThemeEntity] {
        SharedStore.load().themes.filter { identifiers.contains($0.id.uuidString) }.map(ThemeEntity.init)
    }
    func suggestedEntities() async throws -> [ThemeEntity] {
        SharedStore.load().themes.map(ThemeEntity.init)
    }
    func entities(matching string: String) async throws -> [ThemeEntity] {
        SharedStore.load().themes.filter { $0.name.localizedCaseInsensitiveContains(string) }.map(ThemeEntity.init)
    }
}

struct DesignEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Widget Design"
    static var defaultQuery = DesignQuery()
    var id: String
    var name: String
    var layout: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)", subtitle: "\(layout)") }

    init(_ d: WidgetDesign) { id = d.id.uuidString; name = d.name; layout = d.layout.label }
}

struct DesignQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [DesignEntity] {
        SharedStore.load().widgets.filter { identifiers.contains($0.id.uuidString) }.map(DesignEntity.init)
    }
    func suggestedEntities() async throws -> [DesignEntity] {
        SharedStore.load().widgets.map(DesignEntity.init)
    }
}
