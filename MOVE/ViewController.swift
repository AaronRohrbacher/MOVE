import ApplicationServices
import Cocoa
import ObjectiveC
import os.log

class ViewController: NSViewController {
    var savedLayouts: [LayoutData] = []
    private let layoutsKey = "SavedLayouts"
    private var permissionsTimer: Timer?

    @IBOutlet var applyLayoutButton: NSButton?
    @IBOutlet var deleteLayoutButton: NSButton?
    @IBOutlet var saveLayoutButton: NSButton?
    @IBOutlet var layoutsScrollView: NSScrollView?
    @IBOutlet var layoutsTableView: NSTableView?
    @IBOutlet var blurbTextField: NSTextField?
    
    // Grid UI outlets from storyboard
    @IBOutlet var gridIconButton4: NSButton?
    @IBOutlet var gridIconButton8: NSButton?
    @IBOutlet var gridIconButton12: NSButton?
    @IBOutlet var rowButtonUpper: NSButton?
    @IBOutlet var rowButtonMiddle: NSButton?
    @IBOutlet var rowButtonLower: NSButton?
    @IBOutlet var rowButtonNone: NSButton?
    @IBOutlet var additionalRowsStepper: NSStepper?
    @IBOutlet var additionalRowsLabel: NSTextField?
    @IBOutlet var applyGridButton: NSButton?
    
    // Background mode controls
    @IBOutlet var backgroundModeSegmentedControl: NSSegmentedControl?
    @IBOutlet var startOnLoginCheckbox: NSButton?

    var permissionsBanner: NSView?
    var permissionsLabel: NSTextField?
    var permissionsButton: NSButton?
    var gridController: GridController?

    override func viewDidLoad() {
        super.viewDidLoad()
        print("ViewController: viewDidLoad called")
        // Write to file for testing
        let testString = "ViewController: viewDidLoad executed at \(Date())\n"
        if let data = testString.data(using: .utf8) {
            try? data.write(to: URL(fileURLWithPath: "/tmp/move_debug.log"), options: .atomic)
        }

        if ProcessInfo.processInfo.arguments.contains("--clear-user-defaults") {
            UserDefaults.standard.removeObject(forKey: layoutsKey)
            UserDefaults.standard.synchronize()
            savedLayouts = []
        }

        print("ViewController: Loading saved layouts...")
        loadSavedLayouts()

        // Create a test layout if none exist
        if savedLayouts.isEmpty {
            print("ViewController: No layouts found, creating a test layout")
            let testLayout = LayoutData(
                name: "Test Layout",
                windows: [WindowInfo(bundleIdentifier: "test", windowTitle: "Test Window", frame: NSRect(x: 100, y: 100, width: 800, height: 600), isMinimized: false, isHidden: false, windowNumber: 1)],
                desktopIcons: nil,
                includeDesktopIcons: false,
                dateCreated: Date()
            )
            savedLayouts.append(testLayout)
            LayoutPersistence.saveLayouts(savedLayouts)
            print("ViewController: Created test layout")
        }

        print("ViewController: Setting up UI...")
        setupUI()
        print("ViewController: Creating permissions banner...")
        createPermissionsBanner()
        print("ViewController: Setting up grid controller...")
        setupGridController()
        print("ViewController: Setting up blurb text field...")
        setupBlurbTextField()
        print("ViewController: Setting up background mode...")
        setupBackgroundMode()
        
        // Disable state restoration to prevent flushAllChanges spam
        if let window = view.window {
            window.restorationClass = nil
            window.isRestorable = false
        }
        
        print("ViewController: viewDidLoad completed")
    }
    
    func setupBackgroundMode() {
        // Setup background mode segmented control
        if let control = backgroundModeSegmentedControl {
            control.segmentCount = 2
            control.setLabel("Dock", forSegment: 0)
            control.setLabel("Menu Bar", forSegment: 1)
            control.target = self
            control.action = #selector(backgroundModeChanged(_:))
            
            let currentMode = BackgroundModeManager.shared.currentMode
            control.selectedSegment = currentMode == .dock ? 0 : 1
        }
        
        // Setup start on login checkbox
        if let checkbox = startOnLoginCheckbox {
            checkbox.setButtonType(.switch)
            checkbox.title = "Start on Login"
            checkbox.target = self
            checkbox.action = #selector(startOnLoginChanged(_:))
            checkbox.state = BackgroundModeManager.shared.startOnLogin ? .on : .off
        }
    }
    
    @objc func backgroundModeChanged(_ sender: NSSegmentedControl) {
        let mode: BackgroundModeManager.BackgroundMode = sender.selectedSegment == 0 ? .dock : .menuBar
        BackgroundModeManager.shared.currentMode = mode
    }
    
    @objc func startOnLoginChanged(_ sender: NSButton) {
        BackgroundModeManager.shared.startOnLogin = sender.state == .on
    }
    
    func setupBlurbTextField() {
        guard let textField = blurbTextField else { return }
        
        let titleText = "Macintosh Orchestrator of Visual Ease v0.1"
        let subtitleText = "Free (as in freedom) and open source."
        let urlString = "https://github.com/AaronRohrbacher/MOVE"
        let fullText = "\(titleText)\n\(subtitleText) \(urlString)"
        
        let attributedString = NSMutableAttributedString(string: fullText)
        
        // Title line - bold, slightly larger
        if let titleRange = fullText.range(of: titleText) {
            let nsRange = NSRange(titleRange, in: fullText)
            attributedString.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 12), range: nsRange)
            attributedString.addAttribute(.foregroundColor, value: NSColor.labelColor, range: nsRange)
        }
        
        // Subtitle line - regular font
        if let subtitleRange = fullText.range(of: subtitleText) {
            let nsRange = NSRange(subtitleRange, in: fullText)
            attributedString.addAttribute(.font, value: NSFont.systemFont(ofSize: 10), range: nsRange)
            attributedString.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: nsRange)
        }
        
        // URL - link color, underlined
        if let urlRange = fullText.range(of: urlString) {
            let nsRange = NSRange(urlRange, in: fullText)
            if let url = URL(string: urlString) {
                attributedString.addAttribute(.link, value: url, range: nsRange)
            }
            attributedString.addAttribute(.font, value: NSFont.systemFont(ofSize: 10), range: nsRange)
            attributedString.addAttribute(.foregroundColor, value: NSColor.linkColor, range: nsRange)
            attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: nsRange)
        }
        
        // Set paragraph style for better line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2
        paragraphStyle.alignment = .center
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: fullText.count))
        
        textField.attributedStringValue = attributedString
        textField.allowsEditingTextAttributes = true
        textField.isSelectable = true
        textField.isEditable = false
    }
    
    func setupGridController() {
        // Create GridController programmatically
        let gridController = GridController()
        gridController.mainViewController = self
        
        // Connect storyboard UI elements to GridController
        var gridButtons: [NSButton] = []
        if let button4 = gridIconButton4 { gridButtons.append(button4) }
        if let button8 = gridIconButton8 { gridButtons.append(button8) }
        if let button12 = gridIconButton12 { gridButtons.append(button12) }
        gridController.gridIconButtons = gridButtons
        
        var rowButtons: [NSButton] = []
        if let upper = rowButtonUpper { rowButtons.append(upper) }
        if let middle = rowButtonMiddle { rowButtons.append(middle) }
        if let lower = rowButtonLower { rowButtons.append(lower) }
        if let none = rowButtonNone { rowButtons.append(none) }
        gridController.rowSelectionButtons = rowButtons
        
        if let stepper = additionalRowsStepper {
            gridController.additionalRowsStepper = stepper
        }
        if let label = additionalRowsLabel {
            gridController.additionalRowsLabel = label
        }
        if let button = applyGridButton {
            gridController.applyGridButton = button
        }
        
        // Setup UI from storyboard elements
        gridController.setupUIFromStoryboard()
        
        // Store reference
        self.gridController = gridController
        
        // Note: We don't add the GridController's view since the UI elements
        // are already in the storyboard and part of this view controller's view
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        // Set window content size and minimum size to ensure grid feature is always visible
        if let window = view.window {
            let contentSize = NSSize(width: 680, height: 360)
            window.setContentSize(contentSize)
            window.contentMinSize = NSSize(width: 680, height: 360)
            window.contentMaxSize = NSSize(width: 2000, height: 2000) // Allow resizing outward
        }

        saveLayoutButton?.setAccessibilityIdentifier("SaveCurrentLayoutButton")
        applyLayoutButton?.setAccessibilityIdentifier("ApplyLayoutButton")
        deleteLayoutButton?.setAccessibilityIdentifier("DeleteLayoutButton")
        
        // Ensure Apply Layout button is connected and enabled
        if let button = applyLayoutButton {
            button.target = self
            button.action = #selector(applyLayout)
            button.isEnabled = true
            print("viewDidAppear: Apply Layout button reconnected and enabled")
        }

        checkPermissionsAndUpdateUI()
        permissionsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.checkPermissionsAndUpdateUI()
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        permissionsTimer?.invalidate()
        permissionsTimer = nil
    }

    private func setupUI() {
        print("ViewController: Setting up table view")
        layoutsTableView?.dataSource = self
        layoutsTableView?.delegate = self
        layoutsTableView?.target = self
        layoutsTableView?.doubleAction = #selector(applyLayout)
        print("ViewController: Table view setup complete - dataSource: \(String(describing: layoutsTableView?.dataSource)), delegate: \(String(describing: layoutsTableView?.delegate))")

        if let button = applyLayoutButton {
            button.target = self
            button.action = #selector(applyLayout)
            print("Apply Layout button connected: target=\(String(describing: button.target)), action=\(String(describing: button.action))")
        } else {
            print("WARNING: applyLayoutButton outlet is nil")
        }

        deleteLayoutButton?.target = self
        deleteLayoutButton?.action = #selector(deleteLayout)

        saveLayoutButton?.target = self
        saveLayoutButton?.action = #selector(saveLayout)
    }

    func captureCurrentLayout() -> [WindowInfo] {
        var windows: [WindowInfo] = []
        let myPID = getpid()

        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
        }

        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            print("Failed to get window list")
            return []
        }

        for windowDict in windowList {
            guard
                let pid = windowDict[kCGWindowOwnerPID as String] as? pid_t,
                pid != myPID,
                let windowNumber = windowDict[kCGWindowNumber as String] as? CGWindowID,
                let bounds = windowDict[kCGWindowBounds as String] as? [String: Any],
                let x = bounds["X"] as? CGFloat,
                let y = bounds["Y"] as? CGFloat,
                let width = bounds["Width"] as? CGFloat,
                let height = bounds["Height"] as? CGFloat,
                let ownerName = windowDict[kCGWindowOwnerName as String] as? String
            else { continue }

            let windowTitle = (windowDict[kCGWindowName as String] as? String) ?? ""
            let windowLayer = windowDict[kCGWindowLayer as String] as? Int ?? 0

            if windowLayer != 0 { continue }
            if width < 50 || height < 50 { continue }

            var bundleId = ""
            let runningApps = NSWorkspace.shared.runningApplications
            if let app = runningApps.first(where: { $0.processIdentifier == pid }) {
                bundleId = app.bundleIdentifier ?? ownerName
            } else {
                bundleId = ownerName
            }

            let isMinimized = windowDict[kCGWindowIsOnscreen as String] as? Bool == false
            let isHidden = windowDict[kCGWindowAlpha as String] as? CGFloat ?? 1.0 < 0.1

            let frame = CGRect(x: x, y: y, width: width, height: height)

            let displayTitle = windowTitle.isEmpty ? ownerName : windowTitle

            windows.append(WindowInfo(
                bundleIdentifier: bundleId,
                windowTitle: displayTitle,
                frame: frame,
                isMinimized: isMinimized,
                isHidden: isHidden,
                windowNumber: windowNumber
            ))
        }

        return windows
    }

    func restoreLayout(_ layout: LayoutData) {
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            for window in layout.windows {
                self?.restoreWindow(window)
            }

            if layout.includeDesktopIcons, let icons = layout.desktopIcons {
                self?.restoreDesktopIcons(icons)
            }
        }
    }

    private func restoreWindow(_ savedWindow: WindowInfo) {
        print("restoreWindow: Attempting to restore '\(savedWindow.windowTitle)' from bundle '\(savedWindow.bundleIdentifier)' to frame (\(savedWindow.frame.origin.x), \(savedWindow.frame.origin.y), \(savedWindow.frame.size.width), \(savedWindow.frame.size.height))")
        
        let runningApps = NSWorkspace.shared.runningApplications
        guard let app = runningApps.first(where: {
            $0.bundleIdentifier == savedWindow.bundleIdentifier ||
                $0.localizedName == savedWindow.bundleIdentifier
        }) else {
            print("restoreWindow: App '\(savedWindow.bundleIdentifier)' not found in running applications")
            return
        }

        if app.processIdentifier == getpid() {
            print("restoreWindow: Skipping our own app")
            return
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        var success = false

        if !savedWindow.windowTitle.isEmpty {
            print("restoreWindow: Trying to move window by title '\(savedWindow.windowTitle)'")
            success = moveWindowByTitle(appElement: appElement,
                                        title: savedWindow.windowTitle,
                                        to: savedWindow.frame)
        }

        if !success {
            print("restoreWindow: Title match failed, trying first window")
            success = moveFirstWindow(of: appElement, to: savedWindow.frame)
        }
        
        if success {
            print("restoreWindow: Successfully restored '\(savedWindow.windowTitle)'")
        } else {
            print("restoreWindow: Failed to restore '\(savedWindow.windowTitle)'")
        }
    }

    private func moveWindowByTitle(appElement: AXUIElement, title: String, to frame: CGRect) -> Bool {
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

    private func moveFirstWindow(of appElement: AXUIElement, to frame: CGRect) -> Bool {
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

    private func setWindowFrame(_ window: AXUIElement, frame: CGRect) -> Bool {
        var positionSettable: DarwinBoolean = false
        var sizeSettable: DarwinBoolean = false

        AXUIElementIsAttributeSettable(window, kAXPositionAttribute as CFString, &positionSettable)
        AXUIElementIsAttributeSettable(window, kAXSizeAttribute as CFString, &sizeSettable)

        guard positionSettable.boolValue && sizeSettable.boolValue else {
            print("setWindowFrame: Position settable: \(positionSettable.boolValue), Size settable: \(sizeSettable.boolValue)")
            return false
        }

        var position = frame.origin
        if let positionValue = AXValueCreate(.cgPoint, &position) {
            let positionResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
            if positionResult != .success {
                print("setWindowFrame: Failed to set position to (\(frame.origin.x), \(frame.origin.y)), error: \(positionResult.rawValue)")
                return false
            }
        } else {
            print("setWindowFrame: Failed to create AXValue for position")
            return false
        }

        var size = frame.size
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            let sizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
            if sizeResult != .success {
                print("setWindowFrame: Failed to set size to (\(frame.size.width), \(frame.size.height)), error: \(sizeResult.rawValue)")
                return false
            }
        } else {
            print("setWindowFrame: Failed to create AXValue for size")
            return false
        }

        print("setWindowFrame: Successfully set window to frame (\(frame.origin.x), \(frame.origin.y), \(frame.size.width), \(frame.size.height))")
        return true
    }

    func restoreDesktopIcons(_ icons: [DesktopIconInfo]) {
        let logger = OSLog(subsystem: "com.aaronrohrbacher.MOVE", category: "IconRestore")
        
        // Desktop icon restoration is disabled in macOS 26 (Tahoe)
        os_log("restoreDesktopIcons: Desktop icon restoration is not available in macOS 26", log: logger, type: .info)
        return
        
        guard !icons.isEmpty else {
            os_log("restoreDesktopIcons: icons array is empty", log: logger, type: .error)
            return
        }

        guard ensureAccessibilityPermission(prompt: false) else {
            os_log("restoreDesktopIcons: Accessibility permission not granted", log: logger, type: .error)
            return
        }

        os_log("restoreDesktopIcons: Attempting to restore %d icons using Accessibility API", log: logger, type: .info, icons.count)
        
        // Get icon names we need to restore
        let targetNames = Set(icons.map { $0.name })
        
        // Gather icon elements from Finder using Accessibility API (limit depth to reduce system calls)
        let iconElements = gatherFinderIconElements(targetNames: targetNames, maxDepth: 6)
        os_log("restoreDesktopIcons: Found %d icon elements in Finder", log: logger, type: .info, iconElements.count)
        
        // Restore each icon's position with delays to reduce system load
        // Use a simple counter class to track progress across async closures
        class Counter {
            var restored = 0
            var failed = 0
            let total: Int
            let lock = NSLock()
            let logger: OSLog
            let iconsToRestore: [DesktopIconInfo]
            weak var viewController: ViewController?
            
            init(total: Int, logger: OSLog, icons: [DesktopIconInfo], viewController: ViewController) {
                self.total = total
                self.logger = logger
                self.iconsToRestore = icons
                self.viewController = viewController
            }
            
            func incrementRestored() {
                lock.lock()
                restored += 1
                let current = restored + failed
                lock.unlock()
                if current == total {
                    os_log("restoreDesktopIcons: Completed - restored: %d, failed: %d, total: %d", log: logger, type: .info, restored, failed, total)
                }
            }
            
            func incrementFailed() {
                lock.lock()
                failed += 1
                let current = restored + failed
                let allFailed = (failed == total && restored == 0)
                lock.unlock()
                if current == total {
                    os_log("restoreDesktopIcons: Completed - restored: %d, failed: %d, total: %d", log: logger, type: .info, restored, failed, total)
                    // If all failed (likely -25200 in macOS 26), try AppleScript via Cocoa
                    if allFailed && failed > 0 {
                        os_log("restoreDesktopIcons: All icons failed via Accessibility API (macOS 26 restriction), trying AppleScript", log: logger, type: .info)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                            guard let self = self, let vc = self.viewController else { return }
                            vc.restoreDesktopIconsViaAppleScript(icons: self.iconsToRestore)
                        }
                    }
                }
            }
        }
        
        let counter = Counter(total: icons.count, logger: logger, icons: icons, viewController: self)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            for (index, icon) in icons.enumerated() {
                // Add small delay between operations to reduce system load
                let delay = DispatchTime.now() + .milliseconds(50 * index)
                DispatchQueue.main.asyncAfter(deadline: delay) {
                    guard let iconElement = iconElements[icon.name] else {
                        os_log("restoreDesktopIcons: Icon element not found for '%{public}@'", log: logger, type: .error, icon.name)
                        counter.incrementFailed()
                        return
                    }
                    
                    // Try to set position directly without checking settable first (reduces API calls)
                    var position = icon.position
                    if let positionValue = AXValueCreate(.cgPoint, &position) {
                        let result = AXUIElementSetAttributeValue(iconElement, kAXPositionAttribute as CFString, positionValue)
                        if result == .success {
                            os_log("restoreDesktopIcons: Successfully restored '%{public}@' to (%.1f, %.1f)", log: logger, type: .info, icon.name, icon.position.x, icon.position.y)
                            counter.incrementRestored()
                        } else {
                            // Error -25200 (kAXErrorCannotComplete) means macOS 26 blocks direct API access
                            // Fall back to plist method
                            os_log("restoreDesktopIcons: Accessibility API failed for '%{public}@' (error: %d), will use plist fallback", log: logger, type: .info, icon.name, result.rawValue)
                            counter.incrementFailed()
                        }
                    } else {
                        os_log("restoreDesktopIcons: Failed to create AXValue for position of '%{public}@'", log: logger, type: .error, icon.name)
                        counter.incrementFailed()
                    }
                }
            }
        }
    }

    func extractDesktopIconsAndFilter(from windows: [WindowInfo])
        -> (icons: [DesktopIconInfo], filteredWindows: [WindowInfo]) {
        let detection = detectDesktopIcons(using: windows)
        guard !detection.icons.isEmpty else {
            return ([], windows)
        }

        let filteredWindows = windows.filter { !detection.iconWindowIds.contains($0.windowNumber) }
        return (detection.icons, filteredWindows)
    }

    private func detectDesktopIcons(using windows: [WindowInfo])
        -> (icons: [DesktopIconInfo], iconWindowIds: Set<CGWindowID>) {
        let windowSnapshot = windows.isEmpty ? captureCurrentLayout() : windows
        let desktopFiles = fetchDesktopFileNames()

        var icons: [DesktopIconInfo] = []

        let plistPositions = readFinderDesktopIconPositions()
        if !plistPositions.isEmpty {
            for (name, point) in plistPositions {
                guard desktopFiles.contains(name) else { continue }
                icons.append(DesktopIconInfo(name: name, position: point))
            }
        }

        if icons.isEmpty {
            let accessibilityIcons = captureDesktopIconsViaAccessibility(knownNames: desktopFiles)
            if !accessibilityIcons.isEmpty {
                icons = accessibilityIcons
            }
        }

        if icons.isEmpty {
            icons = treatFinderWindowsAsIcons(windowSnapshot, knownNames: desktopFiles)
        }

        let iconNames = Set(icons.map { $0.name })
        let iconWindowIds = iconWindowIds(from: windowSnapshot, iconNames: iconNames)
        icons.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return (icons, iconWindowIds)
    }

    private func readFinderDesktopIconPositions() -> [String: CGPoint] {
        let plistURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Preferences")
            .appendingPathComponent("com.apple.finder.plist")

        guard let data = try? Data(contentsOf: plistURL) else {
            return [:]
        }

        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return [:]
        }

        var iconView: [String: Any]?
        if let desktopSettings = plist["DesktopViewSettings"] as? [String: Any] {
            if let stdView = desktopSettings["StandardViewSettings"] as? [String: Any],
               let stdIconView = stdView["IconViewSettings"] as? [String: Any] {
                iconView = stdIconView
            } else if let directIconView = desktopSettings["IconViewSettings"] as? [String: Any] {
                iconView = directIconView
            }
        }

        guard let positions = iconView?["IconPositions"] as? [String: Any] else {
            return [:]
        }

        var result: [String: CGPoint] = [:]
        for (name, value) in positions {
            guard let dict = value as? [String: Any] else { continue }
            let xValue = (dict["x"] as? NSNumber) ?? (dict["X"] as? NSNumber)
            let yValue = (dict["y"] as? NSNumber) ?? (dict["Y"] as? NSNumber)
            guard let x = xValue?.doubleValue, let y = yValue?.doubleValue else { continue }
            result[name] = CGPoint(x: x, y: y)
        }
        return result
    }

    private func fetchDesktopFileNames() -> Set<String> {
        let desktopURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let items = (try? FileManager.default.contentsOfDirectory(atPath: desktopURL.path)) ?? []
        return Set(items.filter { !$0.hasPrefix(".") })
    }
    
    private func restoreDesktopIconsViaAppleScript(icons: [DesktopIconInfo]) {
        let logger = OSLog(subsystem: "com.aaronrohrbacher.MOVE", category: "IconRestore")
        os_log("restoreDesktopIconsViaAppleScript: Attempting to restore %d icons using AppleScript", log: logger, type: .info, icons.count)
        
        // Build AppleScript to set all icon positions
        var scriptLines: [String] = []
        scriptLines.append("tell application \"Finder\"")
        scriptLines.append("    activate")
        
        for icon in icons {
            // Escape special characters in filename for AppleScript
            let escapedName = icon.name.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            scriptLines.append("    try")
            scriptLines.append("        set desktopItem to item \"\(escapedName)\" of desktop")
            scriptLines.append("        set position of desktopItem to {\(Int(icon.position.x)), \(Int(icon.position.y))}")
            scriptLines.append("    on error")
            scriptLines.append("        -- Icon not found, skip")
            scriptLines.append("    end try")
        }
        
        scriptLines.append("end tell")
        let scriptSource = scriptLines.joined(separator: "\n")
        
        // Log the script for debugging (first 500 chars)
        let scriptPreview = scriptSource.count > 500 ? String(scriptSource.prefix(500)) + "..." : scriptSource
        os_log("restoreDesktopIconsViaAppleScript: Script source (preview): %{public}@", log: logger, type: .debug, scriptPreview)
        
        guard let appleScript = NSAppleScript(source: scriptSource) else {
            os_log("restoreDesktopIconsViaAppleScript: Failed to create AppleScript from source", log: logger, type: .error)
            // Fall back to plist if AppleScript fails
            writeIconsToPlistAndRestartFinder(icons: icons)
            return
        }
        
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        
        if let error = error {
            let errorCode = error[NSAppleScript.errorNumber] as? Int ?? -1
            let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            let errorApp = error[NSAppleScript.errorAppName] as? String ?? "Unknown app"
            os_log("restoreDesktopIconsViaAppleScript: AppleScript error - Code: %d, Message: %{public}@, App: %{public}@", log: logger, type: .error, errorCode, errorMessage, errorApp)
            os_log("restoreDesktopIconsViaAppleScript: Full error dict: %{public}@", log: logger, type: .error, error.description)
            // Fall back to plist if AppleScript fails
            writeIconsToPlistAndRestartFinder(icons: icons)
        } else {
            let resultString = result.stringValue ?? "nil"
            os_log("restoreDesktopIconsViaAppleScript: Successfully executed AppleScript (result: %{public}@)", log: logger, type: .info, resultString)
        }
    }
    
    private func writeIconsToPlistAndRestartFinder(icons: [DesktopIconInfo]) {
        let logger = OSLog(subsystem: "com.aaronrohrbacher.MOVE", category: "IconRestore")
        let plistURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Preferences")
            .appendingPathComponent("com.apple.finder.plist")
        
        os_log("writeIconsToPlistAndRestartFinder: Writing %d icon positions to plist", log: logger, type: .info, icons.count)
        
        // Read existing plist
        guard let data = try? Data(contentsOf: plistURL),
              var plist = try? PropertyListSerialization.propertyList(from: data, options: .mutableContainersAndLeaves, format: nil) as? [String: Any] else {
            os_log("writeIconsToPlistAndRestartFinder: Failed to read plist", log: logger, type: .error)
            return
        }
        
        // Navigate/create the nested structure
        var desktop = plist["DesktopViewSettings"] as? [String: Any] ?? [:]
        var stdView = desktop["StandardViewSettings"] as? [String: Any] ?? [:]
        var iconView = stdView["IconViewSettings"] as? [String: Any] ?? [:]
        var positions = iconView["IconPositions"] as? [String: Any] ?? [:]
        
        // Update positions for all icons
        for icon in icons {
            positions[icon.name] = [
                "x": icon.position.x,
                "y": icon.position.y,
                "Container": "Desktop"
            ]
            os_log("writeIconsToPlistAndRestartFinder: Added position for '%{public}@' at (%.1f, %.1f)", log: logger, type: .info, icon.name, icon.position.x, icon.position.y)
        }
        
        // Write back
        iconView["IconPositions"] = positions
        stdView["IconViewSettings"] = iconView
        desktop["StandardViewSettings"] = stdView
        plist["DesktopViewSettings"] = desktop
        
        // Save plist
        do {
            let newData = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
            try newData.write(to: plistURL)
            os_log("writeIconsToPlistAndRestartFinder: Successfully wrote plist", log: logger, type: .info)
            
            // Restart Finder to apply changes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let process = Process()
                process.launchPath = "/usr/bin/killall"
                process.arguments = ["Finder"]
                do {
                    try process.run()
                    process.waitUntilExit()
                    os_log("writeIconsToPlistAndRestartFinder: Restarted Finder", log: logger, type: .info)
                } catch {
                    os_log("writeIconsToPlistAndRestartFinder: Failed to restart Finder: %{public}@", log: logger, type: .error, error.localizedDescription)
                }
            }
        } catch {
            os_log("writeIconsToPlistAndRestartFinder: Failed to write plist: %{public}@", log: logger, type: .error, error.localizedDescription)
        }
    }

    private func captureDesktopIconsViaAccessibility(knownNames: Set<String>) -> [DesktopIconInfo] {
        guard ensureAccessibilityPermission(prompt: false) else {
            return []
        }

        let targetNames = knownNames.isEmpty ? nil : knownNames
        let iconElements = gatherFinderIconElements(targetNames: targetNames)
        guard !iconElements.isEmpty else { return [] }

        var icons: [DesktopIconInfo] = []
        for (name, element) in iconElements {
            if let position = attributePoint(kAXPositionAttribute as CFString, for: element) {
                icons.append(DesktopIconInfo(name: name, position: position))
            }
        }

        if !knownNames.isEmpty {
            let filtered = icons.filter { knownNames.contains($0.name) }
            return filtered.isEmpty ? icons : filtered
        }

        return icons
    }

    private func gatherFinderIconElements(targetNames: Set<String>?, maxDepth: Int = 8) -> [String: AXUIElement] {
        guard let finderElement = finderApplicationElement() else {
            return [:]
        }

        var result: [String: AXUIElement] = [:]
        traverseFinderElement(finderElement,
                              depth: 0,
                              maxDepth: maxDepth,
                              targetNames: targetNames,
                              result: &result)
        return result
    }

    private func traverseFinderElement(_ element: AXUIElement,
                                       depth: Int,
                                       maxDepth: Int,
                                       targetNames: Set<String>?,
                                       result: inout [String: AXUIElement]) {
        if depth > maxDepth { return }

        if let iconName = iconNameIfPresent(element: element, targetNames: targetNames) {
            if result[iconName] == nil {
                result[iconName] = element
            }

            if let targets = targetNames, result.count == targets.count {
                return
            }
        }

        if let visibleChildren = attributeElements(kAXVisibleChildrenAttribute as CFString, for: element) {
            for child in visibleChildren {
                traverseFinderElement(child,
                                      depth: depth + 1,
                                      maxDepth: maxDepth,
                                      targetNames: targetNames,
                                      result: &result)
                if let targets = targetNames, result.count == targets.count {
                    return
                }
            }
        }

        if let children = attributeElements(kAXChildrenAttribute as CFString, for: element) {
            for child in children {
                traverseFinderElement(child,
                                      depth: depth + 1,
                                      maxDepth: maxDepth,
                                      targetNames: targetNames,
                                      result: &result)
                if let targets = targetNames, result.count == targets.count {
                    return
                }
            }
        }
    }

    private func iconNameIfPresent(element: AXUIElement, targetNames: Set<String>?) -> String? {
        guard let role = attributeString(kAXRoleAttribute as CFString, for: element) else {
            return nil
        }

        let subrole = attributeString(kAXSubroleAttribute as CFString, for: element) ?? ""
        let roleDescription = attributeString(kAXRoleDescriptionAttribute as CFString, for: element) ?? ""
        let lowerDescription = roleDescription.lowercased()
        let lowerSubrole = subrole.lowercased()

        let iconRole = lowerDescription.contains("icon") ||
            lowerSubrole.contains("icon") ||
            role == "AXGroup" ||
            role == "AXImage" ||
            role == "AXButton" ||
            role == "AXListItem"

        guard iconRole else { return nil }

        guard let title = attributeString(kAXTitleAttribute as CFString, for: element)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !title.isEmpty
        else {
            return nil
        }

        if let targets = targetNames, !targets.contains(title) {
            return nil
        }

        return title
    }

    private func attributeString(_ attribute: CFString, for element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else { return nil }
        return value as? String
    }

    private func attributeElements(_ attribute: CFString, for element: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else { return nil }
        return value as? [AXUIElement]
    }

    private func attributePoint(_ attribute: CFString, for element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let cfValue = value else { return nil }
        guard CFGetTypeID(cfValue) == AXValueGetTypeID() else { return nil }
        let axValue = unsafeBitCast(cfValue, to: AXValue.self)
        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else { return nil }
        return point
    }

    private func attributeSize(_ attribute: CFString, for element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let cfValue = value else { return nil }
        guard CFGetTypeID(cfValue) == AXValueGetTypeID() else { return nil }
        let axValue = unsafeBitCast(cfValue, to: AXValue.self)
        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else { return nil }
        return size
    }

    private func treatFinderWindowsAsIcons(_ windows: [WindowInfo], knownNames: Set<String>) -> [DesktopIconInfo] {
        var icons: [DesktopIconInfo] = []
        guard !windows.isEmpty else { return icons }

        for window in windows {
            guard window.bundleIdentifier == "com.apple.finder" else { continue }
            guard knownNames.contains(window.windowTitle) else { continue }
            if isLikelyDesktopIconWindow(window, iconNames: knownNames) {
                icons.append(DesktopIconInfo(name: window.windowTitle,
                                             position: window.frame.origin))
            }
        }
        return icons
    }

    private func iconWindowIds(from windows: [WindowInfo], iconNames: Set<String>) -> Set<CGWindowID> {
        guard !iconNames.isEmpty else { return [] as Set<CGWindowID> }
        var ids: Set<CGWindowID> = []
        for window in windows where isLikelyDesktopIconWindow(window, iconNames: iconNames) {
            ids.insert(window.windowNumber)
        }
        return ids
    }

    private func isLikelyDesktopIconWindow(_ window: WindowInfo, iconNames: Set<String>) -> Bool {
        guard window.bundleIdentifier == "com.apple.finder" else { return false }
        guard iconNames.contains(window.windowTitle) else { return false }
        let frame = window.frame
        let minDimension: CGFloat = 24.0
        let maxDimension: CGFloat = 260.0
        guard frame.width >= minDimension, frame.height >= minDimension else { return false }
        guard frame.width <= maxDimension, frame.height <= maxDimension else { return false }
        let aspectRatio = frame.width / max(frame.height, 1)
        return aspectRatio <= 1.8
    }

    private func finderApplicationElement() -> AXUIElement? {
        guard let finder = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) else {
            print("Finder is not running")
            return nil
        }
        return AXUIElementCreateApplication(finder.processIdentifier)
    }

    private func setFinderIcon(_ element: AXUIElement, to position: CGPoint) -> Bool {
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, kAXPositionAttribute as CFString, &settable)
        guard settable.boolValue else {
            print("setFinderIcon: Position attribute is not settable")
            return false
        }

        var mutablePosition = position
        guard let value = AXValueCreate(.cgPoint, &mutablePosition) else {
            print("setFinderIcon: Failed to create AXValue for position \(position)")
            return false
        }
        
        let result = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
        if result != .success {
            print("setFinderIcon: AXUIElementSetAttributeValue failed with error: \(result.rawValue)")
        }
        return result == .success
    }

    private func bringFinderToFront() {
        if let finderApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) {
            finderApp.activate(options: [.activateIgnoringOtherApps])
        }
    }
    
    private func printRestoreResults(movedCount: Int, totalCount: Int, failedIcons: [String]) {
        print("restoreDesktopIcons: Moved \(movedCount) of \(totalCount) icons")
        if !failedIcons.isEmpty {
            print("restoreDesktopIcons: Failed icons: \(failedIcons)")
        }
    }
    

}

