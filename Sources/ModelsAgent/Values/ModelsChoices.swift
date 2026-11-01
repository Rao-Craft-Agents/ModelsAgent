import Foundation

/// Who may see a call's types.
public enum ModelsAccess: String, Codable, Sendable, CaseIterable {
    /// The app's own module: the default.
    case `internal`
    /// A package's types, seen by the app that imports it.
    case `public`
}

/// How a type's fields are named in JSON.
public enum ModelsCoding: String, Codable, Sendable, CaseIterable {
    /// As they are named in Swift: the default.
    case exact
    /// snake_case: `displayName` is `display_name`.
    case snake
}
