//  WHAT: The Swift for a call's types: one file a type, each Codable, Hashable and Sendable (Identifiable with an
//        `id`, CaseIterable when an enum carries nothing), an explicit initializer, and a `preview` value; one file
//        a unify line, an initializer from the other API's type.
//  PIN:  A DEFAULT IS A DEFAULT IN JSON TOO. A field with `= value` decodes as that value when the JSON leaves it
//        out, so a persisted store keeps reading after a field is added and an API that omits a key still decodes.
//        Synthesized decoding would refuse both.
//  PIN:  THE CODE READS AS THE APP'S OWN: no generator banner, the line's doc as the type's doc comment.

import Foundation

struct ModelsEmitter {
    var access: ModelsAccess = .internal
    var coding: ModelsCoding = .exact
    var imports: [String] = []
    var previews = true
    /// Every type this call writes, by name: what a preview may build from.
    var entities: [String: Entity] = [:]
    /// Types with a preview already in the project (written by an earlier call).
    var previewed: Set<String> = []
    /// The types of this call whose preview can be made: every field sampled (`resolvePreviews`).
    var previewable: Set<String> = []

    /// Works out which of this call's types get a preview. A type whose field has no sample has none, and neither
    /// does one whose required field is such a type; repeated until nothing changes.
    mutating func resolvePreviews() {
        var candidates = Set(entities.keys)
        while true {
            previewable = candidates
            let next = candidates.filter { name in previewValue(entities[name]!) != nil }
            if next == candidates { break }
            candidates = next
        }
    }

    /// Whether `from` mentions `to` in its fields or cases, directly or through other types of this call.
    func reaches(_ from: String, _ to: String) -> Bool {
        var seen: Set<String> = [], stack = [from]
        while let name = stack.popLast() {
            guard seen.insert(name).inserted, let entity = entities[name] else { continue }
            let mentioned = entity.fields.flatMap(\.type.names) + entity.cases.flatMap { $0.values.flatMap(\.type.names) }
            if mentioned.contains(to) { return true }
            stack += mentioned
        }
        return false
    }

    private var open: String { access == .public ? "public " : "" }

    // MARK: - A type

    struct Emitted { var text: String; var hasPreview: Bool; var note: String? }

    func emit(_ entity: Entity) -> Emitted {
        var lines = header()
        if let doc = entity.doc, !doc.isEmpty { lines.append("/// \(sentence(doc))") }
        switch entity.shape {
        case .record(let fields): lines += record(entity, fields)
        case .choice(let cases): lines += choice(entity, cases)
        }
        var note: String?
        var hasPreview = false
        if previews {
            if let value = previewValue(entity) {
                lines += ["", "extension \(entity.name) {", "    /// \(article(entity.name).capitalized) \(entity.name) to preview and test with.",
                          "    \(open)static let preview: \(entity.name) = \(value)", "}"]
                hasPreview = true
            } else {
                note = "\(entity.name) has no preview: \(missingPreview(entity) ?? "a field's type has none")"
            }
        }
        return Emitted(text: lines.joined(separator: "\n") + "\n", hasPreview: hasPreview, note: note)
    }

    private func header() -> [String] {
        (["Foundation"] + imports.filter { $0 != "Foundation" }).map { "import \($0)" } + [""]
    }

    private func record(_ entity: Entity, _ fields: [Field]) -> [String] {
        var conformances = ["Codable", "Hashable"]
        if fields.contains(where: { $0.name == "id" }) { conformances.append("Identifiable") }
        conformances.append("Sendable")
        var lines = ["\(open)struct \(entity.name): \(conformances.joined(separator: ", ")) {"]
        for field in fields {
            if let doc = field.doc, !doc.isEmpty { lines.append("    /// \(sentence(doc))") }
            lines.append("    \(open)var \(SwiftName.member(field.name)): \(field.type)")
        }
        // The initializer, every field in order; a default or nil where the line gave one.
        let parameters = fields.map { field -> String in
            var text = "\(SwiftName.member(field.name)): \(field.type)"
            if let value = field.defaultValue { text += " = \(value)" } else if field.type.isOptional { text += " = nil" }
            return text
        }
        lines += ["", "    \(open)init(\(parameters.joined(separator: ", "))) {"]
        lines += fields.map { "        self.\(SwiftName.member($0.name)) = \(SwiftName.member($0.name))" }
        lines.append("    }")
        let keyed = fields.contains { key(for: $0) != $0.name }
        let lenient = fields.contains { $0.defaultValue != nil && !$0.type.isOptional }
        if keyed || lenient {
            lines += ["", "    enum CodingKeys: String, CodingKey {"]
            lines += fields.map { field in
                let key = self.key(for: field)
                return key == field.name ? "        case \(SwiftName.member(field.name))" : "        case \(SwiftName.member(field.name)) = \"\(key)\""
            }
            lines.append("    }")
        }
        if lenient {
            lines += ["", "    \(open)init(from decoder: Decoder) throws {", "        let container = try decoder.container(keyedBy: CodingKeys.self)"]
            for field in fields {
                let name = SwiftName.member(field.name)
                if field.type.isOptional {
                    lines.append("        \(name) = try container.decodeIfPresent(\(field.type.unwrapped).self, forKey: .\(name))\(field.defaultValue.map { " ?? \($0)" } ?? "")")
                } else if let value = field.defaultValue {
                    lines.append("        \(name) = try container.decodeIfPresent(\(field.type).self, forKey: .\(name)) ?? \(value)")
                } else {
                    lines.append("        \(name) = try container.decode(\(field.type).self, forKey: .\(name))")
                }
            }
            lines.append("    }")
        }
        lines.append("}")
        return lines
    }

    private func choice(_ entity: Entity, _ cases: [Case]) -> [String] {
        let carries = cases.contains { !$0.values.isEmpty }
        var lines: [String] = []
        if carries {
            lines.append("\(open)enum \(entity.name): Codable, Hashable, Sendable {")
            for item in cases {
                if let doc = item.doc, !doc.isEmpty { lines.append("    /// \(sentence(doc))") }
                if item.values.isEmpty {
                    lines.append("    case \(SwiftName.member(item.name))")
                } else {
                    let values = item.values.map { value in value.label.map { "\($0): \(value.type)" } ?? "\(value.type)" }
                    lines.append("    case \(SwiftName.member(item.name))(\(values.joined(separator: ", ")))")
                }
            }
            lines.append("}")
            return lines
        }
        let integers = cases.allSatisfy { $0.raw == nil || Int($0.raw!) != nil } && cases.contains { $0.raw != nil }
        let raw = integers ? "Int" : "String"
        lines.append("\(open)enum \(entity.name): \(raw), Codable, CaseIterable, Hashable, Identifiable, Sendable {")
        for item in cases {
            if let doc = item.doc, !doc.isEmpty { lines.append("    /// \(sentence(doc))") }
            var line = "    case \(SwiftName.member(item.name))"
            if integers {
                if let value = item.raw { line += " = \(value)" }
            } else if let value = item.raw {
                let quoted = value.hasPrefix("\"") ? value : "\"\(value)\""
                line += " = \(quoted)"
            } else if coding == .snake, SwiftName.snake(item.name) != item.name {
                line += " = \"\(SwiftName.snake(item.name))\""
            }
            lines.append(line)
        }
        lines += ["", "    \(open)var id: Self { self }", "}"]
        return lines
    }

    private func key(for field: Field) -> String {
        if let key = field.key { return key }
        return coding == .snake ? SwiftName.snake(field.name) : field.name
    }

    // MARK: - Previews

    /// The value `preview` is, or nil when a field's type has no sample this call can make.
    func previewValue(_ entity: Entity) -> String? {
        switch entity.shape {
        case .record(let fields):
            var arguments: [String] = []
            for field in fields {
                guard let value = sample(field.type, field: field.name, owner: entity.name) else { return nil }
                arguments.append("\(SwiftName.member(field.name)): \(value)")
            }
            return "\(entity.name)(\(arguments.joined(separator: ", ")))"
        case .choice(let cases):
            guard let first = cases.first else { return nil }
            if first.values.isEmpty { return "\(entity.name).\(SwiftName.member(first.name))" }
            var arguments: [String] = []
            for (index, value) in first.values.enumerated() {
                guard let made = sample(value.type, field: value.label ?? "value\(index)", owner: entity.name) else { return nil }
                arguments.append(value.label.map { "\($0): \(made)" } ?? made)
            }
            return "\(entity.name).\(SwiftName.member(first.name))(\(arguments.joined(separator: ", ")))"
        }
    }

    /// Why `entity` has no preview, as the end of a sentence.
    func missingPreview(_ entity: Entity) -> String? {
        let types: [(String, TypeRef)] = entity.fields.map { ($0.name, $0.type) } + (entity.cases.first?.values.map { ($0.label ?? "a value", $0.type) } ?? [])
        for (name, type) in types where sample(type, field: name, owner: entity.name) == nil {
            return "\(name) is \(type.unwrapped), which this call did not write and the project has no preview of"
        }
        return nil
    }

    /// A sample of `type` for the field `field` of `owner`; nil when there is none to make.
    ///
    /// PIN: PREVIEWS NEVER NAME EACH OTHER IN A LOOP. Two static values that read each other deadlock the first time
    /// either is read. A value the field may leave empty (optional, an array, a dictionary) names another type's
    /// preview only when that type cannot reach back to this one, or sorts after it; otherwise it is left empty.
    /// The previews then only ever point from an earlier name to a later one.
    func sample(_ type: TypeRef, field: String, owner: String, required: Bool = true) -> String? {
        switch type {
        case .optional(let wrapped):
            return sample(wrapped, field: field, owner: owner, required: false) ?? "nil"
        case .array(let element):
            return sample(element, field: singular(field), owner: owner, required: false).map { "[\($0)]" } ?? "[]"
        case .dictionary(let key, let value):
            guard let k = sample(key, field: "key", owner: owner, required: false),
                  let v = sample(value, field: field, owner: owner, required: false) else { return "[:]" }
            return "[\(k): \(v)]"
        case .named(let name):
            if let value = standard(name, field: field, owner: owner) { return value }
            return known(name, owner: owner, required: required)
        }
    }

    private func standard(_ name: String, field: String, owner: String) -> String? {
        let lower = field.lowercased(), isID = field == "id" || field.hasSuffix("ID") || field.hasSuffix("Id")
        switch name {
        case "String":
            if isID { return "\"\(SwiftName.snake(owner).replacingOccurrences(of: "_", with: "-"))-1\"" }
            if lower.contains("email") { return "\"person@example.com\"" }
            if lower.hasSuffix("url") || lower.contains("link") || lower.contains("href") { return "\"https://example.com/\(SwiftName.snake(field))\"" }
            return "\"Sample \(SwiftName.words(field))\""
        case "Int", "Int64", "Int32", "UInt", "UInt64", "Int16", "UInt32": return isID ? "1" : "42"
        case "Double", "Float", "CGFloat": return "4.5"
        case "Decimal": return "Decimal(string: \"4.5\")!"
        case "Bool": return "false"
        case "Date": return "Date(timeIntervalSince1970: 1_767_225_600)"
        case "URL": return "URL(string: \"https://example.com/\(SwiftName.snake(field))\")!"
        case "UUID": return "UUID(uuidString: \"00000000-0000-0000-0000-000000000001\")!"
        case "Data": return "Data()"
        default: return nil
        }
    }

    /// `Name.preview`, when there is one and naming it cannot loop back to `owner`.
    private func known(_ name: String, owner: String, required: Bool) -> String? {
        if name == owner { return nil }
        if entities[name] != nil {
            guard previewable.contains(name) else { return nil }
            if required || !reaches(name, owner) || owner < name { return "\(name).preview" }
            return nil
        }
        // A type an earlier call wrote: its fields are not known here, so only a field that must have a value names it.
        return required && previewed.contains(name) ? "\(name).preview" : nil
    }

    private func singular(_ name: String) -> String {
        name.hasSuffix("ies") ? String(name.dropLast(3)) + "y" : name.hasSuffix("s") && !name.hasSuffix("ss") ? String(name.dropLast()) : name
    }

    // MARK: - A unify line

    /// An initializer of `unify.target` from `unify.source`, its arguments in `order` (the target's fields) when known.
    func emit(_ unify: Unify, order: [String]?) throws -> String {
        var assignments = unify.assignments
        if let order {
            let known = Set(order)
            if let stray = assignments.first(where: { !known.contains($0.field) }) {
                throw ModelsError.unify("\(unify.target) has no field `\(stray.field)`; its fields are \(order.joined(separator: ", "))")
            }
            assignments.sort { (order.firstIndex(of: $0.field) ?? 0) < (order.firstIndex(of: $1.field) ?? 0) }
            if let target = entities[unify.target] {
                let given = Set(assignments.map(\.field))
                if let missing = target.fields.first(where: { !given.contains($0.name) && $0.defaultValue == nil && !$0.type.isOptional }) {
                    throw ModelsError.unify("\(unify.target).\(missing.name) has no default and \(unify.source) gives it no value")
                }
            }
        }
        var lines = header()
        lines += ["extension \(unify.target) {", "    /// \(article(unify.target).capitalized) \(unify.target) made from \(article(unify.source)) \(unify.source).",
                  "    \(open)init(_ source: \(unify.source)) {"]
        let arguments = assignments.map { "\(SwiftName.member($0.field)): \($0.expression)" }
        lines.append("        self.init(\(arguments.joined(separator: ", ")))")
        lines += ["    }", "}"]
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Words

    private func sentence(_ text: String) -> String {
        guard let first = text.first else { return text }
        let capped = first.uppercased() + text.dropFirst()
        return capped.hasSuffix(".") ? capped : capped + "."
    }

    private func article(_ word: String) -> String {
        guard let first = word.first?.lowercased() else { return "a" }
        return "aeiou".contains(first) ? "an" : "a"
    }
}
