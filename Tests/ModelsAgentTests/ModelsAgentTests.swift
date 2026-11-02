import Foundation
import GraniteAgents
import XCTest
@testable import ModelsAgent

/// The package as an app finds it: by its record, with the schema a model is shown and the guide a host prompts with.
final class ModelsAgentTests: XCTestCase {
    func testTheRecordIsFoundWithNothingListed() throws {
        let models = try XCTUnwrap(GraniteRoster.discovered().package("models"), "the record is in this test binary")
        XCTAssertEqual(models.module, "ModelsAgent")
        XCTAssertEqual(models.summary, ModelsAgent.summary)
    }

    func testTheSchemaIsWhatAModelIsShown() {
        let models = AnyAgentPackage(ModelsAgent.self)
        XCTAssertEqual(models.schema, .object([
            .init(name: "entities", schema: .array(.string), required: false),
            .init(name: "unify", schema: .array(.string), required: false),
            .init(name: "into", schema: .string, required: false),
            .init(name: "access", schema: .choice(["internal", "public"]), required: false),
            .init(name: "coding", schema: .choice(["exact", "snake"]), required: false),
            .init(name: "imports", schema: .array(.string), required: false),
            .init(name: "previews", schema: .boolean, required: false),
            .init(name: "directory", schema: .string, required: false),
        ]))
        XCTAssertTrue(models.takesDirectory)
        XCTAssertEqual(Set(models.fields.keys), ["entities", "unify", "into", "access", "coding", "imports", "previews"],
                       "a note beside every field the model sees")
    }

    func testTheGuideSaysHowToWriteALine() {
        let guide = AnyAgentPackage(ModelsAgent.self).guide
        for word in ["entities", "unify", "into", "access", "imports", "preview", "@json_key", "?"] {
            XCTAssertTrue(guide.contains(word), "the guide says \(word)")
        }
    }

    /// The call as a host makes it: JSON in, the host's folder filled, JSON out naming the files.
    func testACallThroughTheRosterWritesTheFilesItNames() async throws {
        let folder = try Fixture.folder()
        let input = try JSONSerialization.data(withJSONObject: ["entities": Fixture.recipes, "into": "Shared/Models", "directory": folder.path])
        let answer = try await AnyAgentPackage(ModelsAgent.self).perform(input, host: AgentHost(directory: folder.path, ask: "the recipe types"))
        let result = try JSONDecoder().decode(ModelsResult.self, from: answer)
        XCTAssertEqual(result.types, ["Recipe", "Cook", "Step", "Course", "Media"])
        XCTAssertEqual(result.paths.map { URL(fileURLWithPath: $0).lastPathComponent },
                       ["Recipe.swift", "Cook.swift", "Step.swift", "Course.swift", "Media.swift"])
        XCTAssertEqual(result.path, result.paths.first)
        for path in result.paths {
            XCTAssertTrue(path.hasPrefix(folder.appendingPathComponent("Shared/Models").path), path)
            XCTAssertTrue(FileManager.default.fileExists(atPath: path))
        }
        XCTAssertEqual(Set(result.previews), ["Recipe", "Cook", "Step", "Course", "Media"])
        XCTAssertTrue(result.notes.isEmpty, "\(result.notes)")
    }
}

/// A host that names its folder only in `AgentHost`, as one calling over the wire may.
final class HostFolderTests: XCTestCase {
    func testTheHostsFolderIsUsedWhenTheInputHasNone() async throws {
        let folder = try Fixture.folder()
        let input = try JSONSerialization.data(withJSONObject: ["entities": ["Item: id String"]])
        let answer = try await AnyAgentPackage(ModelsAgent.self).perform(input, host: AgentHost(directory: folder.path))
        let result = try JSONDecoder().decode(ModelsResult.self, from: answer)
        XCTAssertEqual(result.paths, [folder.appendingPathComponent("Shared/Models/Item.swift").path])
    }
}

/// A struct cannot hold itself in place, directly or through another type (Margin, 2026-11-01).
final class LoopTests: XCTestCase {
    func testATypeHoldingItselfInPlaceIsRefusedAndAListIsNot() throws {
        let entities = try ["Comment: id String, parent Comment?, replies [Comment]", "Post: id String, author User?", "User: id String, pinned Post?",
                            "Reader: id String, friends [Reader]"].map(EntityLine.parse)
        let reasons = ModelsAgent.loops(in: entities)
        XCTAssertTrue(reasons.contains { $0.contains("`Comment` holds a `Comment` in place (`Comment.parent`)") && $0.contains("`parentID String?`") }, "\(reasons)")
        XCTAssertTrue(reasons.contains { $0.contains("`Post` holds a `Post` in place (`Post.author` → `User.pinned`)") }, "\(reasons)")
        XCTAssertFalse(reasons.contains { $0.contains("`Reader`") }, "a list holds its elements elsewhere")
    }
}
