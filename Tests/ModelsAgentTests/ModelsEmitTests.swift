import Foundation
import XCTest
@testable import ModelsAgent

/// What the files say: the shapes the guide promises, and nothing written when a line is refused.
final class ModelsEmitTests: XCTestCase {
    private func write(_ input: ModelsAgent.Input) throws -> (ModelsResult, URL) {
        let folder = try Fixture.folder()
        var input = input
        input.directory = folder.path
        return (try ModelsAgent.write(input, note: { _ in }, yield: { _ in }), folder)
    }

    private func text(_ result: ModelsResult, _ name: String) throws -> String {
        let path = try XCTUnwrap(result.paths.first { $0.hasSuffix("/" + name) })
        return try String(contentsOfFile: path, encoding: .utf8)
    }

    func testAStructIsCodableHashableIdentifiableAndDecodesItsDefaults() throws {
        let (result, _) = try write(.init(entities: Fixture.recipes))
        let recipe = try text(result, "Recipe.swift")
        XCTAssertTrue(recipe.contains("/// A dish someone saved."))
        XCTAssertTrue(recipe.contains("struct Recipe: Codable, Hashable, Identifiable, Sendable {"))
        XCTAssertTrue(recipe.contains("init(id: String, title: String, minutes: Int = 30, author: Cook? = nil, steps: [Step], tags: [String], rating: Double? = nil, added: Date, source: URL? = nil)"))
        XCTAssertTrue(recipe.contains("minutes = try container.decodeIfPresent(Int.self, forKey: .minutes) ?? 30"), "a default is a default in JSON")
        XCTAssertTrue(recipe.contains("author = try container.decodeIfPresent(Cook.self, forKey: .author)"))
        XCTAssertTrue(recipe.contains("static let preview: Recipe = Recipe(id: \"recipe-1\""))
        let step = try text(result, "Step.swift")
        XCTAssertFalse(step.contains("init(from decoder"), "no default, no hand-written decoding")
        XCTAssertFalse(step.contains("Identifiable"), "no id, not Identifiable")
    }

    func testPreviewsNeverNameEachOtherInALoop() throws {
        // Recipe holds a Cook?, and Cook holds [Recipe]: one of them must leave the other out.
        let (result, _) = try write(.init(entities: Fixture.recipes))
        let recipe = try text(result, "Recipe.swift"), cook = try text(result, "Cook.swift")
        let recipeNamesCook = recipe.contains("author: Cook.preview"), cookNamesRecipe = cook.contains("recipes: [Recipe.preview]")
        XCTAssertFalse(recipeNamesCook && cookNamesRecipe, "the two previews read each other")
        XCTAssertTrue(recipeNamesCook || cookNamesRecipe, "one of them still shows the other")
        XCTAssertTrue(recipe.contains("steps: [Step.preview]"), "a type that cannot reach back is named")
    }

    func testEnums() throws {
        let (result, _) = try write(.init(entities: Fixture.recipes, coding: .snake))
        let course = try text(result, "Course.swift")
        XCTAssertTrue(course.contains("enum Course: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {"))
        XCTAssertTrue(course.contains("case dessert = \"pudding\""))
        XCTAssertTrue(course.contains("var id: Self { self }"))
        let media = try text(result, "Media.swift")
        XCTAssertTrue(media.contains("enum Media: Codable, Hashable, Sendable {"))
        XCTAssertTrue(media.contains("case video(url: URL, seconds: Double)"))
        XCTAssertTrue(media.contains("static let preview: Media = Media.photo(URL(string:"))
        let levels = try EntityLine.parse("Level: low = 1 | high = 5")
        XCTAssertTrue(ModelsEmitter().emit(levels).text.contains("enum Level: Int, Codable"))
    }

    func testSnakeKeysAndPublicTypes() throws {
        let (result, _) = try write(.init(entities: ["Profile: displayName String, avatarURL URL?, id Int"], access: .public, coding: .snake))
        let profile = try text(result, "Profile.swift")
        XCTAssertTrue(profile.contains("public struct Profile"))
        XCTAssertTrue(profile.contains("public var displayName: String"))
        XCTAssertTrue(profile.contains("public init(displayName: String, avatarURL: URL? = nil, id: Int)"))
        XCTAssertTrue(profile.contains("case displayName = \"display_name\""))
        XCTAssertTrue(profile.contains("case avatarURL = \"avatar_url\""))
        XCTAssertTrue(profile.contains("public static let preview"))
    }

    func testUnifyLinesFollowTheTargetsOrderAndRefuseAMissingField() throws {
        let (result, _) = try write(.init(entities: ["Item: id String, title String, score Int = 0"],
                                          unify: ["Item from Feed.Entry: title = name, id = String(entry.id)"], imports: ["Feed"]))
        let unify = try text(result, "Item+FeedEntry.swift")
        XCTAssertTrue(unify.contains("import Feed"))
        XCTAssertTrue(unify.contains("init(_ source: Feed.Entry) {"))
        XCTAssertTrue(unify.contains("self.init(id: String(entry.id), title: source.name)"), unify)
        XCTAssertThrowsError(try write(.init(entities: ["Item: id String, title String"], unify: ["Item from Entry: title = name"]))) { error in
            XCTAssertTrue("\(error)".contains("Item.id has no default"), "\(error)")
        }
    }

    func testAUnifyLineFindsAnEarlierCallsType() throws {
        let (first, folder) = try write(.init(entities: ["Item: id String, title String, score Int = 0"]))
        XCTAssertEqual(first.types, ["Item"])
        var input = ModelsAgent.Input(unify: ["Item from Entry: title = name, id = key"])
        input.directory = folder.path
        let second = try ModelsAgent.write(input, note: { _ in }, yield: { _ in })
        let text = try String(contentsOfFile: second.paths[0], encoding: .utf8)
        XCTAssertTrue(text.contains("self.init(id: source.key, title: source.name)"), "the order is read off Item.swift: \(text)")
    }

    func testAnEarlierCallsTypeIsPreviewedWhenAFieldNeedsIt() throws {
        let (_, folder) = try write(.init(entities: ["Cook: id String, name String"]))
        var input = ModelsAgent.Input(entities: ["Dish: id String, cook Cook, helper Cook?"])
        input.directory = folder.path
        let result = try ModelsAgent.write(input, note: { _ in }, yield: { _ in })
        let dish = try String(contentsOfFile: result.paths[0], encoding: .utf8)
        XCTAssertTrue(dish.contains("cook: Cook.preview, helper: nil"), dish)
    }

    func testATypeWithNoSampleSaysSoAndHasNoPreview() throws {
        let (result, _) = try write(.init(entities: ["Dish: id String, plate Plate"]))
        XCTAssertEqual(result.previews, [])
        XCTAssertEqual(result.notes, ["Dish has no preview: plate is Plate, which this call did not write and the project has no preview of"])
    }

    func testRefusedLinesWriteNothingAndNameEveryReason() throws {
        let folder = try Fixture.folder()
        let input = ModelsAgent.Input(entities: ["Good: id String", "bad: id String", "Worse id"], directory: folder.path)
        XCTAssertThrowsError(try ModelsAgent.write(input, note: { _ in }, yield: { _ in })) { error in
            XCTAssertTrue("\(error)".contains("2 lines are not understood"), "\(error)")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("Shared/Models/Good.swift").path))
        XCTAssertThrowsError(try ModelsAgent.write(.init(directory: folder.path), note: { _ in }, yield: { _ in })) { error in
            XCTAssertEqual(error as? ModelsError, .nothing)
        }
    }

    func testSwiftThatDoesNotParseIsRefusedBeforeItLands() throws {
        let folder = try Fixture.folder()
        let input = ModelsAgent.Input(entities: ["Odd: id String = (("], directory: folder.path)
        XCTAssertThrowsError(try ModelsAgent.write(input, note: { _ in }, yield: { _ in })) { error in
            XCTAssertTrue("\(error)".contains("does not parse"), "\(error)")
            XCTAssertTrue("\(error)".contains("Shared/Models/Odd.swift"), "the file is named as the project knows it: \(error)")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("Shared/Models/Odd.swift").path))
    }

    func testKeywordsAreEscaped() throws {
        let (result, _) = try write(.init(entities: ["Rule: default Bool, `class` String", "Kind: default | open"]))
        XCTAssertTrue(try text(result, "Kind.swift").contains("case `default`"))
        XCTAssertTrue(try text(result, "Rule.swift").contains("var `class`: String"))
    }
}

/// The host's folder, kept as the host wrote it.
final class AgentFilesTests: XCTestCase {
    func testPathsKeepTheHostsFormAndResolveParents() {
        let files = AgentFiles(directory: "/private/tmp/app")
        XCTAssertEqual(files.resolve("Shared/Models").path, "/private/tmp/app/Shared/Models", "/private is not dropped")
        XCTAssertEqual(files.resolve("Shared/../Services/./X.swift").path, "/private/tmp/app/Services/X.swift")
        XCTAssertEqual(files.resolve("/abs/a/../b").path, "/abs/b")
        XCTAssertEqual(files.relative(files.resolve("Shared/Models/Post.swift")), "Shared/Models/Post.swift")
        XCTAssertEqual(files.relative(URL(fileURLWithPath: "/elsewhere/x")), "/elsewhere/x")
    }
}

/// A Loom-layout app's Shared folder holds only App.swift and AppDelegate.swift loose.
final class LayoutFolderTests: XCTestCase {
    func testPointedAtSharedItselfTheTypesGoInSharedModels() throws {
        let folder = try Fixture.folder()
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("Components"), withIntermediateDirectories: true)
        let input = ModelsAgent.Input(entities: ["Item: id String"], into: "Shared", directory: folder.path)
        let result = try ModelsAgent.write(input, note: { _ in }, yield: { _ in })
        XCTAssertEqual(result.paths, [folder.appendingPathComponent("Shared/Models/Item.swift").path])
        XCTAssertTrue(result.notes.first?.contains("Shared/Models") ?? false, "\(result.notes)")
    }
}
