import Foundation

/// What a run says as it goes.
public enum ModelsFrame: Sendable {
    /// The lines were read: how many types and unify lines.
    case read(types: Int, unify: Int)
    /// The files are written.
    case written(ModelsResult)

    public var result: ModelsResult? {
        if case .written(let result) = self { return result }
        return nil
    }
}
