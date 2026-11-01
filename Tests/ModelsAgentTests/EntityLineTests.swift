import XCTest
@testable import ModelsAgent

/// The line a model writes, read: every form the guide promises, and a reason for every line refused.
final class EntityLineTests: XCTestCase {
    func testAStructLine() throws {
        let entity = try EntityLine.parse(#"Recipe "a dish": id String, minutes Int = 30, author Cook?, tags [String], meta [String: Int], title String @name "the dish's name""#)
        XCTAssertEqual(entity.name, "Recipe")
        XCTAssertEqual(entity.doc, "a dish")
        XCTAssertEqual(entity.fields.map(\.name), ["id", "minutes", "author", "tags", "meta", "title"])
        XCTAssertEqual(entity.fields.map(\.type.description), ["String", "Int", "Cook?", "[String]", "[String: Int]", "String"])
        XCTAssertEqual(entity.fields[1].defaultValue, "30")
        XCTAssertEqual(entity.fields[5].key, "name")
        XCTAssertEqual(entity.fields[5].doc, "the dish's name")
    }

    func testColonsAndAliasesAreReadToo() throws {
        let entity = try EntityLine.parse("struct Point: x: double, y: Double = 0, label: string = \"a, b\"")
        XCTAssertEqual(entity.fields.map(\.type.description), ["Double", "Double", "String"])
        XCTAssertEqual(entity.fields[2].defaultValue, "\"a, b\"", "a comma inside quotes stays in the default")
    }

    func testEnumLines() throws {
        let plain = try EntityLine.parse(#"Course: starter | main | dessert = "pudding""#)
        XCTAssertEqual(plain.cases.map(\.name), ["starter", "main", "dessert"])
        XCTAssertEqual(plain.cases[2].raw, "\"pudding\"")
        let carrying = try EntityLine.parse("Media: photo(URL) | video(url URL, seconds Double) | none")
        XCTAssertEqual(carrying.cases[1].values.map(\.label), ["url", "seconds"])
        XCTAssertEqual(carrying.cases[0].values.map(\.label), [nil])
        let forced = try EntityLine.parse("enum Size: small, large")
        XCTAssertEqual(forced.cases.map(\.name), ["small", "large"])
    }

    func testLinesThatAreRefusedSayWhy() {
        let refused: [(String, String)] = [
            ("Recipe id String", "no colon"),
            ("recipe: id String", "not a type name"),
            ("Recipe: id", "needs a name and a type"),
            ("Recipe: id String, id Int", "named twice"),
            ("Recipe: Title String", "not a field name"),
            ("Size: small | big = 2 | huge(Int)", "one or the other"),
        ]
        for (line, reason) in refused {
            XCTAssertThrowsError(try EntityLine.parse(line), line) { error in
                XCTAssertTrue("\(error)".contains(reason), "\(line) → \(error)")
            }
        }
    }

    func testAUnifyLine() throws {
        let unify = try UnifyLine.parse(#"FederatedPost from LemmyKit.PostView: id = String(post.id), title = post.name, body = post.body ?? """#)
        XCTAssertEqual(unify.target, "FederatedPost")
        XCTAssertEqual(unify.source, "LemmyKit.PostView")
        XCTAssertEqual(unify.assignments.map(\.expression), ["String(post.id)", "source.post.name", #"post.body ?? """#])
    }
}

/// An API's own enum spelling, read as Swift's with the API's kept as the raw value.
final class APISpellingTests: XCTestCase {
    func testCapitalizedCasesKeepTheirSpellingAsTheRawValue() throws {
        let sort = try EntityLine.parse("SortType: Active | Hot | TopDay | NSFW | new")
        XCTAssertEqual(sort.cases.map(\.name), ["active", "hot", "topDay", "nsfw", "new"])
        XCTAssertEqual(sort.cases.map(\.raw), ["\"Active\"", "\"Hot\"", "\"TopDay\"", "\"NSFW\"", nil])
        let text = ModelsEmitter().emit(sort).text
        XCTAssertTrue(text.contains("case topDay = \"TopDay\""), text)
        XCTAssertTrue(text.contains("case new\n"), text)
        XCTAssertEqual(SwiftName.lowerCamel("URLPath"), "urlPath")
    }
}

/// snake_case, as an API writes it, said in Swift's spelling with the API's kept as the key.
final class SnakeCaseTests: XCTestCase {
    func testSnakeCaseFieldsAreCamelCasedAndKeyedAsWritten() throws {
        let entity = try EntityLine.parse("Post: id Int, comment_count Int = 0, created_at Date, post_id Int?, avatar_url URL?, title String")
        XCTAssertEqual(entity.fields.map(\.name), ["id", "commentCount", "createdAt", "postID", "avatarURL", "title"])
        XCTAssertEqual(entity.fields.map(\.key), [nil, "comment_count", "created_at", "post_id", "avatar_url", nil])
        let text = ModelsEmitter().emit(entity).text
        XCTAssertTrue(text.contains("case commentCount = \"comment_count\""), text)
        let sort = try EntityLine.parse("Sort: hot | top_day | new")
        XCTAssertEqual(sort.cases.map(\.name), ["hot", "topDay", "new"])
        XCTAssertEqual(sort.cases.map(\.raw), [nil, "\"top_day\"", nil])
    }
}
