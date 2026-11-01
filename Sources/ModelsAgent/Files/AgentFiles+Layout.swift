//  WHAT: The Loom layout's one rule for Shared/: what an agent writes goes in its own folder there.

import Foundation

extension AgentFiles {
    /// `folder`, unless it is a Loom-layout app's Shared folder itself: there only App.swift and AppDelegate.swift sit
    /// loose, so an agent pointed at Shared writes into its own folder inside it (`own`), and says so.
    func ownFolder(_ folder: URL, own: String) -> (folder: URL, note: String?) {
        let shared = root.appendingPathComponent("Shared")
        let manager = FileManager.default
        let isLoomLayout = ["Components", "Services"].contains { manager.fileExists(atPath: root.appendingPathComponent($0).path) }
        guard folder.path == shared.path, isLoomLayout else { return (folder, nil) }
        return (shared.appendingPathComponent(own), "Shared holds only App.swift and AppDelegate.swift loose in this layout, so the files went into Shared/\(own)")
    }
}
