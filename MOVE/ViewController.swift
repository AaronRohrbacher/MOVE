//
//  ViewController.swift
//  MOVE
//
//  Created by Aaron Rohrbacher on 10/21/25.
//

import Cocoa
import ApplicationServices

// MARK: - Data Models
struct LayoutData: Codable {
    let name: String
    let windows: [WindowInfo]
    let desktopIcons: [DesktopIconInfo]?
    let includeDesktopIcons: Bool
    let dateCreated: Date
}

struct WindowInfo: Codable {
    let bundleIdentifier: String
    let windowTitle: String
    let frame: CGRect
    let isMinimized: Bool
    let isHidden: Bool
    let windowNumber: CGWindowID
    let isDesktopIcon: Bool  // Track if this was a desktop icon (small Finder window)
}

struct DesktopIconInfo: Codable {
    let name: String
    let position: CGPoint
}

class ViewController: NSViewController {
    
    // MARK: - Properties
    var savedLayouts: [LayoutData] = []
    private let layoutsKey = "SavedLayouts"
    private var permissionsTimer: Timer?
    
    // MARK: - Outlets
    @IBOutlet weak var applyLayoutButton: NSButton?
    @IBOutlet weak var deleteLayoutButton: NSButton?
    @IBOutlet weak var saveLayoutButton: NSButton?
    @IBOutlet weak var layoutsScrollView: NSScrollView?
    @IBOutlet weak var layoutsTableView: NSTableView?
    
    // Permissions UI - will create programmatically since storyboard is complex
    var permissionsBanner: NSView?
    private var permissionsLabel: NSTextField?
    private var permissionsButton: NSButton?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        loadSavedLayouts()
        setupUI()
        createPermissionsBanner()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        // Just check and update UI, don't prompt again (already done in AppDelegate)
        checkPermissionsAndUpdateUI()
        // Start timer to periodically check permissions - less frequently to avoid hanging
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
    
    // MARK: - Setup
    private func setupUI() {
        layoutsTableView?.dataSource = self
        layoutsTableView?.delegate = self
        layoutsTableView?.target = self
        layoutsTableView?.doubleAction = #selector(applyLayout)
        
        applyLayoutButton?.target = self
        applyLayoutButton?.action = #selector(applyLayout)
        
        deleteLayoutButton?.target = self
        deleteLayoutButton?.action = #selector(deleteLayout)
        
        saveLayoutButton?.target = self
        saveLayoutButton?.action = #selector(saveLayout)
    }
    
    private func createPermissionsBanner() {
        // Create red banner for permissions warning
        let banner = NSView()
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.wantsLayer = true
        banner.layer?.backgroundColor = NSColor.systemRed.cgColor
        
        // Create label
        let label = NSTextField(labelWithString: "Accessibility permissions are required to move windows")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.font = NSFont.systemFont(ofSize: 13)
        banner.addSubview(label)
        
        // Create button to open settings
        let button = NSButton(title: "Open Accessibility Settings", target: self, action: #selector(openAccessibilitySettings))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .rounded
        banner.addSubview(button)
        
        // Initially hide the banner
        banner.isHidden = true
        view.addSubview(banner)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: view.topAnchor),
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            banner.heightAnchor.constraint(equalToConstant: 40),
            
            label.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: banner.centerYAnchor),
            
            button.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -10),
            button.centerYAnchor.constraint(equalTo: banner.centerYAnchor)
        ])
        
        self.permissionsBanner = banner
        self.permissionsLabel = label
        self.permissionsButton = button
    }
    
    @objc private func openAccessibilitySettings() {
        // Open System Settings to Accessibility pane
        // For macOS 13.0+ (Ventura and later), use the new URL scheme
        if #available(macOS 13.0, *) {
            let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        } else {
            // For older macOS versions
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
    }
    
    private func checkPermissionsAndUpdateUI() {
        // Check if we have accessibility permissions (no prompt)
        let checkOpts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false] as CFDictionary
        let hasPermission = AXIsProcessTrustedWithOptions(checkOpts)
        
        // Update UI based on permission state
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.permissionsBanner?.isHidden = hasPermission
        }
    }
    
    // MARK: - Layout persistence
    func loadSavedLayouts() {
        if let data = UserDefaults.standard.data(forKey: layoutsKey),
           let layouts = try? JSONDecoder().decode([LayoutData].self, from: data) {
            savedLayouts = layouts
        }
        DispatchQueue.main.async { [weak self] in
            self?.layoutsTableView?.reloadData()
        }
    }
    
    func saveLayouts() {
        if let data = try? JSONEncoder().encode(savedLayouts) {
            UserDefaults.standard.set(data, forKey: layoutsKey)
        }
    }
    
    // MARK: - Window Capture
    private func captureCurrentLayout(includeDesktopIcons: Bool = true) -> [WindowInfo] {
        var windows: [WindowInfo] = []
        let myPID = getpid()
        
        // Request screen recording permission if needed
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
                pid != myPID, // Skip our own app's windows
                let windowNumber = windowDict[kCGWindowNumber as String] as? CGWindowID,
                let windowLayer = windowDict[kCGWindowLayer as String] as? Int, 
                windowLayer == 0, // Only normal windows
                let bounds = windowDict[kCGWindowBounds as String] as? [String: Any],
                let x = bounds["X"] as? CGFloat,
                let y = bounds["Y"] as? CGFloat,
                let width = bounds["Width"] as? CGFloat,
                let height = bounds["Height"] as? CGFloat,
                let ownerName = windowDict[kCGWindowOwnerName as String] as? String
            else { continue }
            
            let windowTitle = (windowDict[kCGWindowName as String] as? String) ?? ""
            
            // Skip windows without titles and very small windows (except for Finder desktop icons)
            let isDesktopIcon = ownerName == "Finder" && width < 100 && height < 100 && !windowTitle.isEmpty
            
            // Skip desktop icons if not requested
            if isDesktopIcon && !includeDesktopIcons { continue }
            
            if windowTitle.isEmpty && !isDesktopIcon { continue }
            if !isDesktopIcon && (width < 100 || height < 100) { continue }
            
            // Get bundle identifier for the app
            var bundleId = ""
            let runningApps = NSWorkspace.shared.runningApplications
            if let app = runningApps.first(where: { $0.processIdentifier == pid }) {
                bundleId = app.bundleIdentifier ?? ownerName
            }
            
            // CGWindowListCopyWindowInfo returns coordinates with origin at top-left
            // AX API also uses top-left origin, so no conversion needed
            let frame = CGRect(x: x, y: y, width: width, height: height)
            
            windows.append(WindowInfo(
                bundleIdentifier: bundleId,
                windowTitle: windowTitle,
                frame: frame,
                isMinimized: false,
                isHidden: false,
                windowNumber: windowNumber,
                isDesktopIcon: isDesktopIcon
            ))
            
            print("Captured window: \(windowTitle) (\(ownerName)) - \(frame) - Desktop icon: \(isDesktopIcon)")
        }
        
        return windows
    }
    
    // MARK: - Desktop Icon Capture
    private func captureDesktopIcons() -> [DesktopIconInfo] {
        // This is a placeholder - actual desktop icon positions would require
        // more complex Finder scripting or private APIs
        var desktopIcons: [DesktopIconInfo] = []
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let desktopPath = homeDirectory.appendingPathComponent("Desktop")
        
        if let items = try? FileManager.default.contentsOfDirectory(at: desktopPath, includingPropertiesForKeys: nil) {
            for item in items where !item.lastPathComponent.hasPrefix(".") {
                desktopIcons.append(DesktopIconInfo(name: item.lastPathComponent, position: .zero))
            }
        }
        return desktopIcons
    }
    
    // MARK: - Actions
    @objc func saveLayout() {
        // Always show the dialog first, then check permissions when actually saving
        showSaveLayoutPopup { [weak self] name, includeDesktopIcons in
            guard let self = self, !name.isEmpty else { return }
            
            // Check permissions before trying to capture
            let checkOpts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false] as CFDictionary
            if !AXIsProcessTrustedWithOptions(checkOpts) {
                print("Cannot save layout: Accessibility permissions not granted")
                return
            }
            
            // Capture current window layout
            let windows = self.captureCurrentLayout(includeDesktopIcons: includeDesktopIcons)
            
            if windows.isEmpty {
                print("No windows found to save")
                return
            }
            
            var desktopIcons: [DesktopIconInfo]? = nil
            if includeDesktopIcons {
                desktopIcons = self.captureDesktopIcons()
            }
            
            let layout = LayoutData(
                name: name,
                windows: windows,
                desktopIcons: desktopIcons,
                includeDesktopIcons: includeDesktopIcons,
                dateCreated: Date()
            )
            
            self.savedLayouts.append(layout)
            self.saveLayouts()
            self.layoutsTableView?.reloadData()
            
            print("Saved layout '\(name)' with \(windows.count) windows")
        }
    }
    
    @objc private func applyLayout() {
        // Check accessibility permission - should have been prompted at startup
        let checkOpts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false] as CFDictionary
        if !AXIsProcessTrustedWithOptions(checkOpts) {
            print("Cannot apply layout: Accessibility permissions not granted")
            return
        }
        
    // Get selected layout
    var row = layoutsTableView?.selectedRow ?? -1
    if row < 0 && !savedLayouts.isEmpty {
        row = 0
        layoutsTableView?.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
    }
        guard row >= 0 && row < savedLayouts.count else {
            print("No layout selected")
            return
        }
        
        let layout = savedLayouts[row]
        print("Applying layout: \(layout.name)")
        
        restoreLayout(layout)
    }
    
    @objc private func deleteLayout() {
        var row = layoutsTableView?.selectedRow ?? -1
        if row < 0 && !savedLayouts.isEmpty { row = 0 }
        guard row >= 0 && row < savedLayouts.count else { return }
        
        // Just delete without confirmation
        savedLayouts.remove(at: row)
        saveLayouts()
        layoutsTableView?.reloadData()
    }
    
    // MARK: - Restore
    private func restoreLayout(_ layout: LayoutData) {
        print("Starting layout restoration for: \(layout.name)")
        
        // First, launch any apps that aren't running
        let runningApps = NSWorkspace.shared.runningApplications
        let runningBundleIds = Set(runningApps.compactMap { $0.bundleIdentifier })
        
        var appsToLaunch: Set<String> = []
        for window in layout.windows {
            if !window.bundleIdentifier.isEmpty && !runningBundleIds.contains(window.bundleIdentifier) {
                appsToLaunch.insert(window.bundleIdentifier)
            }
        }
        
        // Launch missing apps
        for bundleId in appsToLaunch {
            print("Launching app: \(bundleId)")
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
        
        // Wait a moment for apps to launch, then restore windows
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            for window in layout.windows {
                self?.restoreWindow(window)
            }
            
            if layout.includeDesktopIcons, let icons = layout.desktopIcons {
                self?.restoreDesktopIcons(icons)
            }
            
            print("Layout restoration complete.")
        }
    }
    
    private func restoreWindow(_ savedWindow: WindowInfo) {
        print("Restoring window: \(savedWindow.windowTitle) to \(savedWindow.frame)")
        
        // Find the app by bundle identifier
        let runningApps = NSWorkspace.shared.runningApplications
        guard let app = runningApps.first(where: { 
            $0.bundleIdentifier == savedWindow.bundleIdentifier ||
            $0.localizedName == savedWindow.bundleIdentifier
        }) else {
            print("App not found: \(savedWindow.bundleIdentifier)")
            return
        }
        
        // Skip if it's our own app
        if app.processIdentifier == getpid() {
            return
        }
        
        // Get the AXUIElement for the app
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        
        // Try to find and move the window
        var success = false
        
        // First try to match by window title
        if !savedWindow.windowTitle.isEmpty {
            success = moveWindowByTitle(appElement: appElement, 
                                       title: savedWindow.windowTitle, 
                                       to: savedWindow.frame,
                                       isDesktopIcon: savedWindow.isDesktopIcon)
        }
        
        // If that didn't work and it's not a desktop icon, try to move any window of the app
        if !success && !savedWindow.isDesktopIcon {
            success = moveFirstWindow(of: appElement, to: savedWindow.frame)
        }
        
        if !success {
            print("Failed to restore window: \(savedWindow.windowTitle)")
        }
    }
    
    private func moveWindowByTitle(appElement: AXUIElement, title: String, to frame: CGRect, isDesktopIcon: Bool) -> Bool {
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else {
            print("Could not get windows for app")
            return false
        }
        
        // For desktop icons (small Finder windows), we need special handling
        if isDesktopIcon {
            // Match desktop icons by title (filename) 
            for window in windows {
                var titleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
                   let windowTitle = titleRef as? String,
                   windowTitle == title,
                   let currentSize = getWindowSize(window),
                   currentSize.width < 100 && currentSize.height < 100 {
                    return setWindowFrame(window, frame: frame)
                }
            }
        } else {
            // Try exact title match first
            for window in windows {
                var titleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
                   let windowTitle = titleRef as? String,
                   windowTitle == title {
                    return setWindowFrame(window, frame: frame)
                }
            }
            
            // Try fuzzy match
            for window in windows {
                var titleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
                   let windowTitle = titleRef as? String,
                   (windowTitle.lowercased().contains(title.lowercased()) || 
                    title.lowercased().contains(windowTitle.lowercased())) {
                    return setWindowFrame(window, frame: frame)
                }
            }
        }
        
        return false
    }
    
    private func moveFirstWindow(of appElement: AXUIElement, to frame: CGRect) -> Bool {
        // Try to get the main window
        var mainWindowRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &mainWindowRef) == .success,
           let mainWindow = mainWindowRef as! AXUIElement? {
            if setWindowFrame(mainWindow, frame: frame) {
                return true
            }
        }
        
        // Try to get the focused window
        var focusedWindowRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindowRef) == .success,
           let focusedWindow = focusedWindowRef as! AXUIElement? {
            if setWindowFrame(focusedWindow, frame: frame) {
                return true
            }
        }
        
        // Try to get any window
        var windowsRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
           let windows = windowsRef as? [AXUIElement],
           !windows.isEmpty {
            return setWindowFrame(windows[0], frame: frame)
        }
        
        return false
    }
    
    private func getWindowSize(_ window: AXUIElement) -> CGSize? {
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let axValue = sizeRef as! AXValue? else {
            return nil
        }
        
        var size = CGSize.zero
        AXValueGetValue(axValue, .cgSize, &size)
        return size
    }
    
    private func setWindowFrame(_ window: AXUIElement, frame: CGRect) -> Bool {
        // Check if attributes are settable
        var positionSettable: DarwinBoolean = false
        var sizeSettable: DarwinBoolean = false
        
        AXUIElementIsAttributeSettable(window, kAXPositionAttribute as CFString, &positionSettable)
        AXUIElementIsAttributeSettable(window, kAXSizeAttribute as CFString, &sizeSettable)
        
        if !positionSettable.boolValue || !sizeSettable.boolValue {
            print("Window attributes not settable")
            return false
        }
        
        // Set position
        var position = frame.origin
        if let positionValue = AXValueCreate(.cgPoint, &position) {
            let posResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
            if posResult != .success {
                print("Failed to set position: \(posResult.rawValue)")
                return false
            }
        }
        
        // Set size
        var size = frame.size
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            let sizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
            if sizeResult != .success {
                print("Failed to set size: \(sizeResult.rawValue)")
                return false
            }
        }
        
        print("Successfully moved window to \(frame)")
        return true
    }
    
    private func restoreDesktopIcons(_ icons: [DesktopIconInfo]) {
        // This would require AppleScript or private APIs to actually position desktop icons
        print("Restoring \(icons.count) desktop icons (positions not implemented)")
    }
    
    // MARK: - UI Helpers
    private func showSaveLayoutPopup(completion: @escaping (String, Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Save Layout"
        alert.informativeText = "Enter a name for this layout:"
        alert.alertStyle = .informational
        
        let nameField = NSTextField(frame: NSRect(x: 0, y: 24, width: 220, height: 24))
        nameField.placeholderString = "Layout name"
        nameField.stringValue = "Layout \(savedLayouts.count + 1)"
        
        let checkbox = NSButton(checkboxWithTitle: "Include desktop icons", target: nil, action: nil)
        checkbox.frame = NSRect(x: 0, y: 0, width: 220, height: 20)
        checkbox.state = .off
        
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 48))
        container.addSubview(nameField)
        container.addSubview(checkbox)
        alert.accessoryView = container
        
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        
        // Make the text field first responder
        alert.window.initialFirstResponder = nameField
        
        if alert.runModal() == .alertFirstButtonReturn {
            let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            completion(name, checkbox.state == .on)
        }
    }
}

// MARK: - Table View DataSource & Delegate
extension ViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return savedLayouts.count
    }
}

extension ViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < savedLayouts.count else { return nil }
        
        let layout = savedLayouts[row]
        let cell = NSTableCellView()
        
        let textField = NSTextField(labelWithString: layout.name)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.lineBreakMode = .byTruncatingTail
        cell.addSubview(textField)
        
        // Add subtitle with window count
        let subtitleText = "\(layout.windows.count) windows"
        let subtitle = NSTextField(labelWithString: subtitleText)
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        subtitle.font = NSFont.systemFont(ofSize: 11)
        subtitle.textColor = NSColor.secondaryLabelColor
        cell.addSubview(subtitle)
        
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            textField.topAnchor.constraint(equalTo: cell.topAnchor, constant: 4),
            
            subtitle.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            subtitle.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            subtitle.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 2),
            subtitle.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -4)
        ])
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 48
    }
}
