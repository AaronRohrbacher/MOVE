#!/usr/bin/swift

import Foundation
import AppKit

let checkOpts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false] as CFDictionary
let trusted = AXIsProcessTrustedWithOptions(checkOpts)
if !trusted {
    print("WARNING: No accessibility permissions - results may be limited")
    print("Grant Terminal accessibility permissions in System Settings > Privacy & Security > Accessibility for full access")
    print("")
}

guard let finderApp = NSWorkspace.shared.runningApplications.first(where: { 
    $0.bundleIdentifier == "com.apple.finder" 
}) else {
    print("Finder not running")
    exit(1)
}

print("=== DESKTOP ICON ACCESSIBILITY TEST ===")
print("")

let finderElement = AXUIElementCreateApplication(finderApp.processIdentifier)

var windowsRef: CFTypeRef?
guard AXUIElementCopyAttributeValue(finderElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
      let windows = windowsRef as? [AXUIElement] else {
    print("Could not get Finder windows")
    exit(1)
}

print("Found \(windows.count) Finder window(s)")
print("")

for (index, window) in windows.enumerated() {
    var titleRef: CFTypeRef?
    let titleResult = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
    let windowTitle = (titleResult == .success) ? (titleRef as? String ?? "<no title>") : "<error>"
    
    var roleRef: CFTypeRef?
    let roleResult = AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &roleRef)
    let role = (roleResult == .success) ? (roleRef as? String ?? "<no role>") : "<error>"
    
    print("Window \(index + 1): '\(windowTitle)' (Role: \(role))")
    
    var childrenRef: CFTypeRef?
    if AXUIElementCopyAttributeValue(window, kAXChildrenAttribute as CFString, &childrenRef) == .success,
       let children = childrenRef as? [AXUIElement] {
        print("  Has \(children.count) children")
        
        for (childIndex, child) in children.enumerated() {
            var childRoleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &childRoleRef) == .success,
               let childRole = childRoleRef as? String {
                
                var descRef: CFTypeRef?
                let descResult = AXUIElementCopyAttributeValue(child, kAXDescriptionAttribute as CFString, &descRef)
                let desc = (descResult == .success) ? (descRef as? String ?? "") : ""
                
                print("    Child \(childIndex + 1): Role=\(childRole) \(desc.isEmpty ? "" : "Desc='\(desc)'")")
                
                if childRole == "AXScrollArea" || childRole == "AXGroup" || childRole == "AXList" {
                    var subChildrenRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &subChildrenRef) == .success,
                       let subChildren = subChildrenRef as? [AXUIElement] {
                        print("      Contains \(subChildren.count) items")
                        
                        for i in 0..<min(3, subChildren.count) {
                            let item = subChildren[i]
                            
                            var itemTitleRef: CFTypeRef?
                            let itemTitle = AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &itemTitleRef) == .success ? 
                                (itemTitleRef as? String ?? "") : ""
                            
                            var itemRoleRef: CFTypeRef?
                            let itemRole = AXUIElementCopyAttributeValue(item, kAXRoleAttribute as CFString, &itemRoleRef) == .success ?
                                (itemRoleRef as? String ?? "") : ""
                            
                            var posRef: CFTypeRef?
                            var position = CGPoint.zero
                            if AXUIElementCopyAttributeValue(item, kAXPositionAttribute as CFString, &posRef) == .success,
                               let posValue = posRef {
                                AXValueGetValue(posValue as! AXValue, .cgPoint, &position)
                            }
                            
                            if !itemTitle.isEmpty || !itemRole.isEmpty {
                                print("        Item \(i+1): '\(itemTitle)' Role=\(itemRole) Pos=\(position)")
                            }
                        }
                        
                        if subChildren.count > 3 {
                            print("        ... and \(subChildren.count - 3) more items")
                        }
                    }
                }
            }
        }
    }
    print("")
}
