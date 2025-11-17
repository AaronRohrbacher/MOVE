//
//  AppDelegate.swift
//  MOVE
//
//  Created by Aaron Rohrbacher on 10/21/25.
//

import Cocoa
import ApplicationServices

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    


    func applicationWillFinishLaunching(_ notification: Notification) {
        // Disable state restoration BEFORE windows are created
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        UserDefaults.standard.synchronize()
        
        // Disable persistent UI state restoration completely
        // This prevents flushAllChanges spam
        if let persistentUIManager = NSApplication.shared.value(forKey: "persistentUIManager") as? NSObject {
            persistentUIManager.perform(Selector(("setEnabled:")), with: false)
        }
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("AppDelegate: applicationDidFinishLaunching called")
        
        if ProcessInfo.processInfo.arguments.contains("--clear-user-defaults") {
            UserDefaults.standard.removeObject(forKey: "SavedLayouts")
            UserDefaults.standard.synchronize()
            let emptyArray: [[String: Any]] = []
            if let emptyData = try? JSONSerialization.data(withJSONObject: emptyArray) {
                UserDefaults.standard.set(emptyData, forKey: "SavedLayouts")
            }
            UserDefaults.standard.synchronize()
        }
        
        print("AppDelegate: Requesting accessibility permissions...")
        requestAccessibilityPermissions()
        
        // Disable state restoration on all windows to prevent flushAllChanges spam
        DispatchQueue.main.async {
            for window in NSApplication.shared.windows {
                window.restorationClass = nil
                window.isRestorable = false
            }
        }
        
        // Ensure the main window is shown
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Try to get window from storyboard
            if let storyboard = NSStoryboard.main,
               let windowController = storyboard.instantiateInitialController() as? NSWindowController {
                print("AppDelegate: Found window controller from storyboard")
                windowController.window?.restorationClass = nil
                windowController.window?.isRestorable = false
                windowController.showWindow(nil)
                windowController.window?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            } else if let window = NSApplication.shared.windows.first {
                print("AppDelegate: Found window, making it key and ordering front")
                window.restorationClass = nil
                window.isRestorable = false
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            } else {
                print("AppDelegate: No windows found")
            }
        }
        
        print("AppDelegate: applicationDidFinishLaunching completed")
    }
    
    private func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if !trusted {
            print("Please enable accessibility permissions in System Settings")
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Always keep app running in background - just hide windows
        // This allows hotkeys to continue working
        for window in NSApplication.shared.windows {
            window.orderOut(nil)
        }
        return .terminateCancel
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false  // Disable state restoration to prevent flushAllChanges spam
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // If the app is reopened (e.g., dock click) and no windows are visible, show the main window
        if !flag {
            if let window = NSApplication.shared.windows.first {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        return true
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        // Ensure window is visible when app becomes active
        if let window = NSApplication.shared.windows.first, !window.isVisible {
            print("AppDelegate: Window not visible, showing it")
            window.makeKeyAndOrderFront(nil)
        }
    }

    // Core Data removed - app uses UserDefaults for persistence
    // This reduces system activity and CoreAnalytics spam at launch

}

