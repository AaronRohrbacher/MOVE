import Foundation

let plistPath = NSHomeDirectory() + "/Library/Preferences/com.apple.finder.plist"
let plistURL = URL(fileURLWithPath: plistPath)

guard
    let data = try? Data(contentsOf: plistURL),
    let plist = try? PropertyListSerialization.propertyList(
        from: data,
        options: [],
        format: nil
    ) as? [String: Any]
else {
    print("Unable to load Finder preferences plist.")
    exit(1)
}

// Check what's under DesktopViewSettings
if let desktop = plist["DesktopViewSettings"] as? [String: Any] {
    print("DesktopViewSettings contains:")
    for (key, _) in desktop {
        print("  - \(key)")
    }
    
    // Check if IconViewSettings is directly here
    if let iconView = desktop["IconViewSettings"] as? [String: Any] {
        print("\nIconViewSettings contains:")
        for (key, _) in iconView {
            print("  - \(key)")
        }
    }
}

// Try the structure without StandardViewSettings
if let desktop = plist["DesktopViewSettings"] as? [String: Any],
   let iconView = desktop["IconViewSettings"] as? [String: Any] {
    
    print("\n✓ Found DesktopViewSettings -> IconViewSettings")
    
    if let positions = iconView["IconPositions"] as? [String: Any] {
        print("✓ Found IconPositions with \(positions.count) items")
        for (name, value) in positions {
            print("  - \(name): \(value)")
        }
    } else {
        print("✗ No IconPositions found")
    }
}

