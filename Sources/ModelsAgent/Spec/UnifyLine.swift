//  WHAT: A unify line: how one of the app's types is made from another API's type, one assignment a field.
//
//            FederatedPost from LemmyKit.PostView: id = String(post.id), title = post.name, body = post.body ?? ""
//
//        A bare path on the right (`post.name`) is read off the source; anything else is Swift that may name
//        `source`. Fields left out take their defaults.

import Foundation

struct Unify: Equatable, Sendable {
    var target: String
    var source: String
    var assignments: [(field: String, expression: String)]

    static func == (a: Unify, b: Unify) -> Bool {
        a.target == b.target && a.source == b.source
            && a.assignments.map(\.field) == b.assignments.map(\.field) && a.assignments.map(\.expression) == b.assignments.map(\.expression)
    }
}

enum UnifyLine {
    static func parse(_ line: String) throws -> Unify {
        let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let colon = LineSplit.firstTop(text, ":") else {
            throw ModelsError.line(line, "a unify line is `Target from Source: field = expression, …`")
        }
        let head = text[..<colon].split(separator: " ").map(String.init)
        guard head.count == 3, head[1] == "from", SwiftName.isTypeName(head[0]),
              head[2].split(separator: ".").allSatisfy({ SwiftName.isTypeName(String($0)) }) else {
            throw ModelsError.line(line, "a unify line starts `Target from Source:`")
        }
        var assignments: [(String, String)] = []
        for piece in LineSplit.top(String(text[text.index(after: colon)...]), on: ",") {
            guard let equals = LineSplit.firstTop(piece, "=") else { throw ModelsError.line(line, "`\(piece)` is not `field = expression`") }
            let field = piece[..<equals].trimmingCharacters(in: .whitespaces)
            var expression = piece[piece.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            guard SwiftName.isMemberName(field), !expression.isEmpty else { throw ModelsError.line(line, "`\(piece)` is not `field = expression`") }
            if isPath(expression), !expression.hasPrefix("source.") , expression != "source" { expression = "source." + expression }
            assignments.append((field, expression))
        }
        guard !assignments.isEmpty else { throw ModelsError.line(line, "\(head[0]) from \(head[2]) assigns nothing") }
        return Unify(target: head[0], source: head[2], assignments: assignments)
    }

    /// A bare dotted path: `post.name`, `counts.score`.
    static func isPath(_ text: String) -> Bool {
        text.range(of: #"^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$"#, options: .regularExpression) != nil
            && !["true", "false", "nil"].contains(text)
    }
}
