import Foundation

let plistPath = NSHomeDirectory() + "/Library/Preferences/com.apple.finder.plist"
let plistURL = URL(fileURLWithPath: plistPath)

print("Adding ALL desktop icons to plist...\n")

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

// Navigate into the nested dictionaries
guard
    var desktop = plist["DesktopViewSettings"] as? [String: Any],
    var stdView = desktop["StandardViewSettings"] as? [String: Any],
    var iconView = stdView["IconViewSettings"] as? [String: Any],
    var positions = iconView["IconPositions"] as? [String: Any]
else {
    fatalError("Finder preferences missing expected keys.")
}

print("Current IconPositions has \(positions.count) items")

// Get ALL files on desktop
let desktopPath = NSHomeDirectory() + "/Desktop"
if let contents = try? FileManager.default.contentsOfDirectory(atPath: desktopPath) {
    print("Found \(contents.count) items on desktop")
    
    var x: Double = 100
    var y: Double = 100
    var addedCount = 0
    
    for item in contents where !item.hasPrefix(".") {
        // Only add if not already in positions
        if positions[item] == nil {
            positions[item] = [
                "x": x,
                "y": y,
                "Container": "Desktop"
            ]
            print("Added: \(item) at (\(x), \(y))")
            addedCount += 1
            
            x += 150
            if x > 1000 {
                x = 100
                y += 150
            }
        } else {
            print("Already has position: \(item)")
        }
    }
    
    print("\nAdded \(addedCount) new positions")
}

// Write them back
iconView["IconPositions"] = positions
stdView["IconViewSettings"] = iconView
desktop["StandardViewSettings"] = stdView
plist["DesktopViewSettings"] = desktop

let newData = try! PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
try! newData.write(to: plistURL)

// Apply by restarting Finder
print("\nRestarting Finder...")
_ = Process.launchedProcess(launchPath: "/usr/bin/killall", arguments: ["Finder"])

print("✓ All desktop icons now have positions in plist")
print("Total: \(positions.count) icon positions")

