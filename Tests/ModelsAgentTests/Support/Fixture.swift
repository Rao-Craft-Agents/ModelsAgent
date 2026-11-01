import Foundation

enum Fixture {
    /// A folder of its own for one test, removed with the process's temporary files.
    static func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("models-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A recipe app's types: what the package is held to writing well.
    static let recipes = [
        #"Recipe "a dish someone saved": id String, title String, minutes Int = 30, author Cook?, steps [Step], tags [String], rating Double?, added Date, source URL?"#,
        "Cook: id UUID, name String, avatar URL?, recipes [Recipe] = []",
        "Step: order Int, text String, timer Int?",
        #"Course: starter | main | dessert = "pudding""#,
        "Media: photo(URL) | video(url URL, seconds Double) | none",
    ]
}
