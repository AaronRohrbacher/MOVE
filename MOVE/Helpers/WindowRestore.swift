import ApplicationServices
import Cocoa

enum WindowRestore {
    static func restoreLayout(_ layout: LayoutData) {
        let runningApps = NSWorkspace.shared.runningApplications
        let runningBundleIds = Set(runningApps.compactMap { $0.bundleIdentifier })

        var appsToLaunch: Set<String> = []
        for window in layout.windows {
            if !window.bundleIdentifier.isEmpty, !runningBundleIds.contains(window.bundleIdentifier) {
                appsToLaunch.insert(window.bundleIdentifier)
            }
        }

        for bundleId in appsToLaunch {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = false
                NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
                    if let error = error {
                        print("Error launching \(bundleId): \(error)")
                    }
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            for window in layout.windows {
                restoreWindow(window)
            }

            if layout.includeDesktopIcons, let icons = layout.desktopIcons {
                DesktopIconManager.restoreDesktopIcons(icons)
            }
        }
    }

    static func restoreWindow(_ savedWindow: WindowInfo) {
        let runningApps = NSWorkspace.shared.runningApplications
        guard let app = runningApps.first(where: {
            $0.bundleIdentifier == savedWindow.bundleIdentifier ||
                $0.localizedName == savedWindow.bundleIdentifier
        }) else {
            return
        }

        if app.processIdentifier == getpid() { return }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        var success = false

        if !savedWindow.windowTitle.isEmpty {
            success = moveWindowByTitle(appElement: appElement,
                                        title: savedWindow.windowTitle,
                                        to: savedWindow.frame)
        }

        if !success {
            success = moveFirstWindow(of: appElement, to: savedWindow.frame)
        }
    }

    private static func moveWindowByTitle(appElement: AXUIElement, title: String, to frame: CGRect) -> Bool {
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement]
        else {
            return false
        }

        for window in windows {
            var titleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
               let windowTitle = titleRef as? String,
               windowTitle == title {
                return setWindowFrame(window, frame: frame)
            }
        }

        for window in windows {
            var titleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
               let windowTitle = titleRef as? String,
               windowTitle.lowercased().contains(title.lowercased()) ||
               title.lowercased().contains(windowTitle.lowercased()) {
                return setWindowFrame(window, frame: frame)
            }
        }

        return false
    }

    private static func moveFirstWindow(of appElement: AXUIElement, to frame: CGRect) -> Bool {
        var mainWindowRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &mainWindowRef) == .success,
           let mainWindow = mainWindowRef as! AXUIElement? {
            if setWindowFrame(mainWindow, frame: frame) {
                return true
            }
        }

        var focusedWindowRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindowRef) == .success,
           let focusedWindow = focusedWindowRef as! AXUIElement? {
            if setWindowFrame(focusedWindow, frame: frame) {
                return true
            }
        }

        var windowsRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
           let windows = windowsRef as? [AXUIElement],
           !windows.isEmpty {
            return setWindowFrame(windows[0], frame: frame)
        }

        return false
    }

    private static func setWindowFrame(_ window: AXUIElement, frame: CGRect) -> Bool {
        var positionSettable: DarwinBoolean = false
        var sizeSettable: DarwinBoolean = false

        AXUIElementIsAttributeSettable(window, kAXPositionAttribute as CFString, &positionSettable)
        AXUIElementIsAttributeSettable(window, kAXSizeAttribute as CFString, &sizeSettable)

        guard positionSettable.boolValue && sizeSettable.boolValue else {
            return false
        }

        var position = frame.origin
        if let positionValue = AXValueCreate(.cgPoint, &position) {
            guard AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue) == .success else {
                return false
            }
        }

        var size = frame.size
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            guard AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue) == .success else {
                return false
            }
        }

        return true
    }
}

