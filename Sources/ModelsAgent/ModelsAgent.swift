//  WHAT: An app's own domain types, as a Granite agent package. A call gives one line a type (`Post: id String,
//        title String, score Int = 0`, `Sort: hot | new | top`) and, for a type made from another API's, one line
//        a mapping; the run writes a Swift file a type into the folder the call names, each Codable, Hashable,
//        Sendable and previewable, and answers where.
//  IN:   Input: the entity lines, the unify lines, the folder, public or internal, the JSON key style, the modules
//        to import, whether to write previews.
//  OUT:  ModelsResult: the files written, the types, which have previews, and what was left out.
//  PIN:  NO MODEL. Every file is made from the lines, the same way every time; a line that is not understood is
//        refused with its reason, and the call writes nothing until every line is understood and every file parses.

import Foundation
import GraniteAgents

public struct ModelsAgent: GraniteAgentPackage {
    public struct Input: Codable, Sendable {
        /// One line a type: `Post "a post": id String, title String, score Int = 0, author User?, tags [String]`,
        /// or an enum, `Sort: hot | new | top`.
        public var entities: [String]?
        /// One line a type made from another API's: `FederatedPost from LemmyPost: id = String(post.id), title = post.name`.
        public var unify: [String]?
        /// The folder the files go in, relative to the project; `Shared/Models` when left out.
        public var into: String?
        /// `public` for a package's types; `internal` when left out.
        public var access: ModelsAccess?
        /// `snake` reads and writes JSON keys in snake_case; `exact` (the names as they are) when left out.
        public var coding: ModelsCoding?
        /// Modules the files import beside Foundation: where a unify line's source type lives.
        public var imports: [String]?
        /// Whether each type gets a `preview` value; true when left out.
        public var previews: Bool?
        /// The host's folder.
        public var directory: String?

        public init(entities: [String]? = nil, unify: [String]? = nil, into: String? = nil, access: ModelsAccess? = nil,
                    coding: ModelsCoding? = nil, imports: [String]? = nil, previews: Bool? = nil, directory: String? = nil) {
            self.entities = entities; self.unify = unify; self.into = into; self.access = access; self.coding = coding
            self.imports = imports; self.previews = previews; self.directory = directory
        }
    }

    public typealias Event = ModelsFrame
    public typealias Output = ModelsResult
    public typealias Compute = Void

    public static let word = "models"
    public static let summary = "writes an app's own domain types as Swift files — Codable, Hashable, Sendable structs and enums with previews — from one compact line a type."
    public static let fields = [
        "entities": "one line a type: `Post \"a post\": id String, title String, score Int = 0, author User?, tags [String]`; an enum is `Sort: hot | new | top` or `Media: image(URL) | video(url URL, seconds Double)`",
        "unify": "one line a type made from another API's type: `FederatedPost from LemmyPost: id = String(post.id), title = post.name`",
        "into": "the folder for the files, relative to the project; Shared/Models when left out, a service's own types in Services/<Name>Service/Models",
        "access": "public for a package's types; internal when left out",
        "coding": "snake for snake_case JSON keys; exact when left out",
        "imports": "modules to import beside Foundation, such as the package a unify line's source type is in",
        "previews": "whether each type gets a `preview` value for SwiftUI previews and tests; true when left out",
    ]
    public static let guide = """
        Tag models for the app's own value types: the records a service keeps, the choices a setting offers, one type \
        that unifies several APIs' types. Give `entities` one line a type. A struct is a name, an optional doc in \
        quotes, a colon and its fields: `Post "a post in a community": id String, title String, score Int = 0, \
        author User?, tags [String], created Date`. A field is a name and a type; `?` makes it optional, `= value` \
        gives a default (the JSON may then leave it out), `@json_key` names its key, and a quoted string after it \
        documents it. An enum is its cases split by bars: `Sort: hot | new | top = "top_all"`, or with values, \
        `Media: image(URL) | video(url URL, seconds Double)`. Types may name each other in one call. `into` is the \
        folder (Shared/Models when left out; a service's own types in its Models folder; `access: public` and the \
        package's Sources folder for a package). `unify` makes one type from another's, one assignment a field: \
        `FederatedPost from LemmyPost: id = String(post.id), title = post.name, body = post.body ?? ""`; a bare path \
        is read off the source, and `imports` names the module the source type is in. Every type is Codable, \
        Hashable and Sendable (Identifiable with an `id`; CaseIterable when an enum carries nothing) and gets a \
        `preview` value. A line it cannot read is refused with the reason and nothing is written: fix the line and \
        call again. Not for an API's request and response types inside its client package, and not for views.
        """

    public static func output(from events: [ModelsFrame]) -> ModelsResult? { events.compactMap(\.result).last }

    public init() {}

    public func run(_ input: Input, context: Context) -> AsyncThrowingStream<ModelsFrame, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let result = try Self.write(input, note: context.host.note) { continuation.yield($0) }
                    continuation.yield(.written(result))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// The whole call: the lines read, the files made, staged, checked and written.
    static func write(_ input: Input, note: @Sendable (String) -> Void, yield: (ModelsFrame) -> Void) throws -> ModelsResult {
        let entityLines = (input.entities ?? []).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let unifyLines = (input.unify ?? []).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !entityLines.isEmpty || !unifyLines.isEmpty else { throw ModelsError.nothing }

        var reasons: [String] = []
        var entities: [Entity] = []
        for line in entityLines {
            do { entities.append(try EntityLine.parse(line)) } catch { reasons.append("\(error)") }
        }
        var unifies: [Unify] = []
        for line in unifyLines {
            do { unifies.append(try UnifyLine.parse(line)) } catch { reasons.append("\(error)") }
        }
        var seen: Set<String> = []
        for entity in entities where !seen.insert(entity.name).inserted { reasons.append("`\(entity.name)` is written twice in one call") }
        guard reasons.isEmpty else { throw ModelsError.lines(reasons) }
        yield(.read(types: entities.count, unify: unifies.count))

        let files = AgentFiles(directory: input.directory)
        let folder = files.resolve(input.into ?? "Shared/Models")
        note("writing \(entities.count) type\(entities.count == 1 ? "" : "s") into \(files.relative(folder))")

        var emitter = ModelsEmitter()
        emitter.access = input.access ?? .internal
        emitter.coding = input.coding ?? .exact
        emitter.imports = input.imports ?? []
        emitter.previews = input.previews ?? true
        emitter.entities = Dictionary(uniqueKeysWithValues: entities.map { ($0.name, $0) })
        emitter.previewed = Self.previewed(in: folder, except: Set(emitter.entities.keys))
        emitter.resolvePreviews()

        var planned: [(url: URL, text: String)] = []
        var previews: [String] = [], notes: [String] = []
        for entity in entities {
            let emitted = emitter.emit(entity)
            planned.append((folder.appendingPathComponent("\(entity.name).swift"), emitted.text))
            if emitted.hasPreview { previews.append(entity.name) }
            if let line = emitted.note { notes.append(line) }
        }
        for unify in unifies {
            let order = emitter.entities[unify.target].map { $0.fields.map(\.name) } ?? Self.initializerOrder(of: unify.target, in: folder)
            let text = try emitter.emit(unify, order: order)
            let source = unify.source.replacingOccurrences(of: ".", with: "")
            planned.append((folder.appendingPathComponent("\(unify.target)+\(source).swift"), text))
        }
        let written = try files.write(planned)
        note("wrote \(written.count) file\(written.count == 1 ? "" : "s")")
        return ModelsResult(path: written.first, paths: written, types: entities.map(\.name), previews: previews, notes: notes)
    }

    /// Types an earlier call wrote into `folder` with a `preview`, so this call's previews may use them.
    static func previewed(in folder: URL, except: Set<String>) -> Set<String> {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return [] }
        var found: Set<String> = []
        for name in names where name.hasSuffix(".swift") && !name.contains("+") {
            let type = String(name.dropLast(6))
            guard !except.contains(type), let text = try? String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8) else { continue }
            if text.contains("static let preview: \(type)") { found.insert(type) }
        }
        return found
    }

    /// The labels of `type`'s first initializer, read off its file in `folder` (an earlier call's), in order.
    static func initializerOrder(of type: String, in folder: URL) -> [String]? {
        let file = folder.appendingPathComponent("\(type).swift")
        guard let text = try? String(contentsOf: file, encoding: .utf8),
              let range = text.range(of: #"init\(([^)]*)\)\s*\{"#, options: .regularExpression) else { return nil }
        let signature = String(text[range]).dropFirst(5)
        let inside = signature.prefix { $0 != ")" }
        let labels = LineSplit.top(String(inside), on: ",").compactMap { part -> String? in
            part.split(separator: ":").first.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " `")) }
        }
        return labels.isEmpty || labels == ["from decoder"] ? nil : labels
    }
}
