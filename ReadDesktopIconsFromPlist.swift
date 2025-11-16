import Foundation

let plistPath = NSHomeDirectory() + "/Library/Preferences/com.apple.finder.plist"
let plistURL = URL(fileURLWithPath: plistPath)

print("Reading desktop icons from: \(plistPath)\n")

guard
    let data = try? Data(contentsOf: plistURL),
    var plist = try? PropertyListSerialization.propertyList(
        from: data,
        options: .mutableContainersAndLeaves,
        format: nil
    ) as? [String: Any]
else {
    print("Unable to load Finder preferences plist.")
    exit(1)
}

// Navigate into the nested dictionaries
if let desktop = plist["DesktopViewSettings"] as? [String: Any] {
    print("✓ Found DesktopViewSettings")
    
    if let stdView = desktop["StandardViewSettings"] as? [String: Any] {
        print("✓ Found StandardViewSettings")
        
        if let iconView = stdView["IconViewSettings"] as? [String: Any] {
            print("✓ Found IconViewSettings")
            
            if let positions = iconView["IconPositions"] as? [String: Any] {
                print("✓ Found IconPositions with \(positions.count) items:\n")
                
                for (name, value) in positions {
                    if let posDict = value as? [String: Any] {
                        let x = posDict["x"] as? Double ?? 0
                        let y = posDict["y"] as? Double ?? 0
                        let container = posDict["Container"] as? String ?? "Unknown"
                        print("  📄 \(name)")
                        print("     Position: (\(x), \(y))")
                        print("     Container: \(container)")
                    }
                }
            } else {
                print("✗ IconPositions not found - creating empty structure...")
                
                // Create the IconPositions key
                var iconView = stdView["IconViewSettings"] as? [String: Any] ?? [:]
                iconView["IconPositions"] = [String: Any]()
                
                var stdView = desktop["StandardViewSettings"] as? [String: Any] ?? [:]
                stdView["IconViewSettings"] = iconView
                
                var desktop = plist["DesktopViewSettings"] as? [String: Any] ?? [:]
                desktop["StandardViewSettings"] = stdView
                
                plist["DesktopViewSettings"] = desktop
                
                // Write it back
                do {
                    let newData = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
                    try newData.write(to: plistURL)
                    print("✓ Created IconPositions structure in plist")
                    print("  Run this script again after moving some desktop icons")
                } catch {
                    print("✗ Failed to write plist: \(error)")
                }
            }
        } else {
            print("✗ IconViewSettings not found")
        }
    } else {
        print("✗ StandardViewSettings not found") 
    }
} else {
    print("✗ DesktopViewSettings not found")
}

print("\n---\n")

// Also list what's actually on the desktop
let desktopPath = NSHomeDirectory() + "/Desktop"
if let contents = try? FileManager.default.contentsOfDirectory(atPath: desktopPath) {
    print("Files on Desktop:")
    for item in contents where !item.hasPrefix(".") {
        print("  - \(item)")
    }
}

