import Foundation
import XCTest
@testable import ModelsAgent

/// The files compiled and run as an app would: a package around them, built with `swift build`, and a program that
/// decodes JSON missing every defaulted key. Gated (`MODELS_BUILD=1`): a build takes a while.
final class ModelsBuildTests: XCTestCase {
    func testTheFilesBuildAndDecodeLeniently() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["MODELS_BUILD"] == "1", "set MODELS_BUILD=1 to build the output")
        let package = try Fixture.folder()
        var input = ModelsAgent.Input(entities: Fixture.recipes + [#"Feed "two APIs as one": id String, title String, votes Int = 0"#],
                                      unify: ["Feed from Recipe: id = id, title = title"], into: "Sources/Sample")
        input.directory = package.path
        let result = try ModelsAgent.write(input, note: { _ in }, yield: { _ in })
        XCTAssertEqual(result.paths.count, 7)
        try """
        // swift-tools-version:6.0
        import PackageDescription
        let package = Package(name: "Sample", platforms: [.macOS(.v14)],
                              targets: [.target(name: "Sample"), .executableTarget(name: "Check", dependencies: ["Sample"])])
        """.write(to: package.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        let check = package.appendingPathComponent("Sources/Check")
        try FileManager.default.createDirectory(at: check, withIntermediateDirectories: true)
        try """
        import Foundation
        @testable import Sample

        let json = #"{"id":"r","title":"Soup","steps":[],"tags":[],"added":0}"#
        let recipe = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
        precondition(recipe.minutes == 30, "a missing default decodes as the default")
        precondition(Recipe.preview.title == "Sample title")
        precondition(Feed(Recipe.preview).votes == 0)
        precondition(Course.allCases.count == 3)
        print("ok")
        """.write(to: check.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", "run", "--package-path", package.path, "Check"]
        let out = Pipe()
        process.standardOutput = out
        process.standardError = out
        try process.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let log = String(decoding: data, as: UTF8.self)
        XCTAssertEqual(process.terminationStatus, 0, log)
        XCTAssertTrue(log.hasSuffix("ok\n"), log)
    }
}
