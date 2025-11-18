import Foundation

let plistPath = NSHomeDirectory() + "/Library/Preferences/com.apple.finder.plist"
let plistURL = URL(fileURLWithPath: plistPath)

print("Checking plist at: \(plistPath)")

guard let data = try? Data(contentsOf: plistURL),
      let plist = try? PropertyListSerialization.propertyList(
        from: data,
        options: [],
        format: nil
      ) as? [String: Any] else {
    print("Could not read plist")
    exit(1)
}

print("\nTop-level keys in plist:")
for key in plist.keys {
    print("  - \(key)")
}

if let desktop = plist["DesktopViewSettings"] as? [String: Any] {
    print("\nDesktopViewSettings keys:")
    for key in desktop.keys {
        print("  - \(key)")
    }
    
    if let iconView = desktop["IconViewSettings"] as? [String: Any] {
        print("\nDesktopViewSettings > IconViewSettings keys:")
        for key in iconView.keys {
            print("  - \(key)")
        }
    }
    
    if let stdView = desktop["StandardViewSettings"] as? [String: Any] {
        print("\nDesktopViewSettings > StandardViewSettings keys:")
        for key in stdView.keys {
            print("  - \(key)")
        }
        
        if let iconView = stdView["IconViewSettings"] as? [String: Any] {
            print("\nDesktopViewSettings > StandardViewSettings > IconViewSettings keys:")
            for key in iconView.keys {
                print("  - \(key)")
            }
            
            if let positions = iconView["IconPositions"] as? [String: Any] {
                print("\nDesktopViewSettings > StandardViewSettings > IconViewSettings > IconPositions:")
                for (name, value) in positions {
                    print("  - \(name): \(value)")
                }
            }
        }
    }
}

print("\n\nChecking alternative structure:")
if let standardViewSettings = plist["StandardViewSettings"] as? [String: Any] {
    print("Found StandardViewSettings at root level")
    if let iconView = standardViewSettings["IconViewSettings"] as? [String: Any] {
        print("Found IconViewSettings")
        if let arrangeBy = iconView["arrangeBy"] as? String {
            print("arrangeBy: \(arrangeBy)")
        }
    }
}

if let desktopSettings = plist["Desktop"] as? [String: Any] {
    print("\nFound Desktop settings:")
    for key in desktopSettings.keys {
        print("  - \(key)")
    }
}

