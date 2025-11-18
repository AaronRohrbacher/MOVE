import Foundation

let plistPath = NSHomeDirectory() + "/Library/Preferences/com.apple.finder.plist"
let plistURL = URL(fileURLWithPath: plistPath)

guard
    let data = try? Data(contentsOf: plistURL),
    let plist = try? PropertyListSerialization.propertyList(
        from: data,
        options: [],
        format: nil
    ) as? [String: Any],
    let desktop = plist["DesktopViewSettings"] as? [String: Any],
    let stdView = desktop["StandardViewSettings"] as? [String: Any],
    let iconView = stdView["IconViewSettings"] as? [String: Any],
    let positions = iconView["IconPositions"] as? [String: Any]
else {
    print("Could not read IconPositions")
    exit(1)
}

print("Current IconPositions has \(positions.count) items:")
for (name, _) in positions {
    print("  - \(name)")
}

print("\nFiles on Desktop:")
let desktopPath = NSHomeDirectory() + "/Desktop"
if let contents = try? FileManager.default.contentsOfDirectory(atPath: desktopPath) {
    let visibleFiles = contents.filter { !$0.hasPrefix(".") }
    print("  Total: \(visibleFiles.count) files")
    for file in visibleFiles {
        if positions[file] != nil {
            print("  ✓ \(file) - has position")
        } else {
            print("  ✗ \(file) - NO position")
        }
    }
}

