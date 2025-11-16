import Foundation

let plistPath = NSHomeDirectory() + "/Library/Preferences/com.apple.finder.plist"
let plistURL = URL(fileURLWithPath: plistPath)

print("Setting up desktop icon positions in Finder plist...\n")

guard
    let data = try? Data(contentsOf: plistURL),
    var plist = try? PropertyListSerialization.propertyList(
        from: data,
        options: .mutableContainersAndLeaves,
        format: nil
    ) as? [String: Any]
else {
    fatalError("Unable to load Finder preferences plist.")
}

// Get or create DesktopViewSettings
var desktop = plist["DesktopViewSettings"] as? [String: Any] ?? [:]

// Create StandardViewSettings if it doesn't exist
if desktop["StandardViewSettings"] == nil {
    print("Creating StandardViewSettings...")
    
    // Copy existing IconViewSettings to StandardViewSettings if it exists
    if let existingIconView = desktop["IconViewSettings"] as? [String: Any] {
        desktop["StandardViewSettings"] = ["IconViewSettings": existingIconView]
        print("Moved existing IconViewSettings under StandardViewSettings")
    } else {
        desktop["StandardViewSettings"] = ["IconViewSettings": [:]]
        print("Created new StandardViewSettings with empty IconViewSettings")
    }
}

// Now navigate the proper structure
guard
    var stdView = desktop["StandardViewSettings"] as? [String: Any],
    var iconView = stdView["IconViewSettings"] as? [String: Any]
else {
    fatalError("Failed to create proper structure")
}

// Create IconPositions if it doesn't exist
if iconView["IconPositions"] == nil {
    print("Creating IconPositions...")
    iconView["IconPositions"] = [String: Any]()
    
    // Add some test positions for files on desktop
    var positions = [String: Any]()
    
    // Get list of files on desktop
    let desktopPath = NSHomeDirectory() + "/Desktop"
    if let contents = try? FileManager.default.contentsOfDirectory(atPath: desktopPath) {
        var x: Double = 100
        var y: Double = 100
        
        for item in contents.prefix(5) where !item.hasPrefix(".") {
            positions[item] = [
                "x": x,
                "y": y,
                "Container": "Desktop"
            ]
            print("Added position for: \(item) at (\(x), \(y))")
            x += 150
            if x > 700 {
                x = 100
                y += 150
            }
        }
    }
    
    iconView["IconPositions"] = positions
}

// Write the structure back
stdView["IconViewSettings"] = iconView
desktop["StandardViewSettings"] = stdView
plist["DesktopViewSettings"] = desktop

do {
    let newData = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
    try newData.write(to: plistURL)
    print("\n✓ Successfully created proper structure in plist")
    
    // Apply by restarting Finder
    print("Restarting Finder to apply changes...")
    _ = Process.launchedProcess(launchPath: "/usr/bin/killall", arguments: ["Finder"])
    
    print("\n✓ Desktop icon positions structure is now ready")
    print("Run the MOVE app to save/restore desktop icon positions")
} catch {
    print("✗ Failed to write plist: \(error)")
}

// Now read back to verify
print("\n--- Verifying Structure ---")
if let data = try? Data(contentsOf: plistURL),
   let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
   let desktop = plist["DesktopViewSettings"] as? [String: Any],
   let stdView = desktop["StandardViewSettings"] as? [String: Any],
   let iconView = stdView["IconViewSettings"] as? [String: Any],
   let positions = iconView["IconPositions"] as? [String: Any] {
    print("✓ Found \(positions.count) desktop icon positions:")
    for (name, value) in positions {
        if let posDict = value as? [String: Any],
           let x = posDict["x"] as? Double,
           let y = posDict["y"] as? Double {
            print("  📄 \(name) at position (\(x), \(y))")
        }
    }
} else {
    print("✗ Could not verify structure")
}

