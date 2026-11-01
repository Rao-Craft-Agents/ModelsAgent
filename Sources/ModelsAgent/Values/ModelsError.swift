import Foundation

/// What a call can say instead of writing.
public enum ModelsError: Error, Equatable, CustomStringConvertible {
    /// A line that is not understood, and why.
    case line(String, String)
    /// Several lines that are not understood: every reason, so all are fixed in one call.
    case lines([String])
    /// A unify line that cannot be written.
    case unify(String)
    /// A call with no lines.
    case nothing

    public var description: String {
        switch self {
        case .line(let line, let reason): return "`\(line)`: \(reason)"
        case .lines(let reasons): return "\(reasons.count) lines are not understood, so nothing was written:\n" + reasons.map { "- \($0)" }.joined(separator: "\n")
        case .unify(let reason): return reason
        case .nothing: return "the call gives no `entities` and no `unify` lines: say each type as one line"
        }
    }
}
