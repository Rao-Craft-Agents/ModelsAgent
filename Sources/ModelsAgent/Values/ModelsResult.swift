import Foundation

/// What a call answers: the files written, as absolute paths, and what they hold.
public struct ModelsResult: Codable, Sendable, Equatable {
    /// The first file written.
    public var path: String?
    /// Every file written: one a type, one a unify line.
    public var paths: [String]
    /// The types written, in the order the lines gave them.
    public var types: [String]
    /// The types that have a `preview` value.
    public var previews: [String]
    /// One sentence each: what the call left out and why.
    public var notes: [String]

    public init(path: String?, paths: [String], types: [String], previews: [String], notes: [String]) {
        self.path = path; self.paths = paths; self.types = types; self.previews = previews; self.notes = notes
    }
}
