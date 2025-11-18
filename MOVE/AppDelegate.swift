import Cocoa
import ApplicationServices

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        UserDefaults.standard.synchronize()
        
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
        
        DispatchQueue.main.async {
            for window in NSApplication.shared.windows {
                window.restorationClass = nil
                window.isRestorable = false
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApplication.shared.windows.first {
                print("AppDelegate: Configuring existing window")
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
        for window in NSApplication.shared.windows {
            window.orderOut(nil)
        }
        return .terminateCancel
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            if let window = NSApplication.shared.windows.first {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        return true
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first, !window.isVisible {
            print("AppDelegate: Window not visible, showing it")
            window.makeKeyAndOrderFront(nil)
        }
    }
}

