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
    let isDesktopIcon: Bool
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
    
    var permissionsBanner: NSView?
    private var permissionsLabel: NSTextField?
    private var permissionsButton: NSButton?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if ProcessInfo.processInfo.arguments.contains("--clear-user-defaults") {
            UserDefaults.standard.removeObject(forKey: layoutsKey)
            UserDefaults.standard.synchronize()
            savedLayouts = []
        }
        
        loadSavedLayouts()
        setupUI()
        createPermissionsBanner()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
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
        let banner = NSView()
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.wantsLayer = true
        banner.layer?.backgroundColor = NSColor.systemRed.cgColor
        
        let label = NSTextField(labelWithString: "Accessibility permissions are required to move windows")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.font = NSFont.systemFont(ofSize: 13)
        banner.addSubview(label)
        
        let button = NSButton(title: "Open Accessibility Settings", target: self, action: #selector(openAccessibilitySettings))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .rounded
        banner.addSubview(button)
        
        banner.isHidden = true
        view.addSubview(banner)
        
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
        if #available(macOS 13.0, *) {
            if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        } else {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    private func checkPermissionsAndUpdateUI() {
        let checkOpts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false] as CFDictionary
        let hasPermission = AXIsProcessTrustedWithOptions(checkOpts)
        
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
            
            // Filter out non-windows (desktop icons are now handled via plist)
            if windowLayer != 0 { continue }
            if windowTitle.isEmpty { continue }
            if width < 100 || height < 100 { continue }
            
            var bundleId = ""
            let runningApps = NSWorkspace.shared.runningApplications
            if let app = runningApps.first(where: { $0.processIdentifier == pid }) {
                bundleId = app.bundleIdentifier ?? ownerName
            }
            
            let frame = CGRect(x: x, y: y, width: width, height: height)
            
            windows.append(WindowInfo(
                bundleIdentifier: bundleId,
                windowTitle: windowTitle,
                frame: frame,
                isMinimized: false,
                isHidden: false,
                windowNumber: windowNumber,
                isDesktopIcon: false
            ))
            
            print("Captured window: \(windowTitle) (\(ownerName)) - \(frame)")
        }
        
        return windows
    }
    
    // MARK: - Desktop Icon Capture
    private func captureDesktopIcons(from windows: [WindowInfo]) -> [DesktopIconInfo] {
        print("\n=== CAPTURING DESKTOP ICONS ===")
        
        var icons: [DesktopIconInfo] = []
        
        // Get list of files on desktop to match against windows
        let desktopPath = NSHomeDirectory() + "/Desktop"
        let desktopFiles = (try? FileManager.default.contentsOfDirectory(atPath: desktopPath))?.filter { !$0.hasPrefix(".") } ?? []
        print("Found \(desktopFiles.count) files on desktop")
        
        // Use CGWindowListCopyWindowInfo like getAllWindows() method
        let options = CGWindowListOption.optionOnScreenOnly
        guard let windowListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0)),
              let windowArray = windowListInfo as? [[String: Any]] else {
            print("Failed to get window list for desktop icons")
            return []
        }
        
        print("Scanning \(windowArray.count) windows for desktop icons...")
        
        for window in windowArray {
            if let ownerName = window[kCGWindowOwnerName as String] as? String,
               ownerName != "Window Server" && ownerName != "Dock",
               let bounds = window[kCGWindowBounds as String] as? [String: Any],
               let x = bounds["X"] as? CGFloat,
               let y = bounds["Y"] as? CGFloat,
               let width = bounds["Width"] as? CGFloat,
               let height = bounds["Height"] as? CGFloat {
                
                let windowTitle = (window[kCGWindowName as String] as? String) ?? ""
                
                // Only save windows that are reasonably sized (like getAllWindows)
                if width > 50 && height > 50 {
                    // Desktop icons are small windows
                    if width < 100 && height < 100 {
                        // Check if window title matches a desktop file
                        let matchesDesktopFile = desktopFiles.contains { $0 == windowTitle }
                        
                        // Desktop icons: small windows with titles that match desktop files, or Finder windows with titles below menu bar
                        if matchesDesktopFile || (ownerName == "Finder" && !windowTitle.isEmpty && y > 100) {
                            print("  → Captured desktop icon: \(windowTitle) (\(ownerName)) at (\(x), \(y))")
                            icons.append(DesktopIconInfo(name: windowTitle, position: CGPoint(x: x, y: y)))
                        } else if width < 100 && height < 100 && !windowTitle.isEmpty {
                            print("  Skipped small window: title='\(windowTitle)' owner='\(ownerName)' size: \(width)x\(height) at (\(x), \(y))")
                        }
                    }
                }
            }
        }
        
        print("\n=== CAPTURE COMPLETE: \(icons.count) desktop icons ===")
        return icons
    }
    
    // MARK: - Actions
    @objc func saveLayout() {
        showSaveLayoutPopup { [weak self] name, includeDesktopIcons in
            guard let self = self, !name.isEmpty else { return }
            
            let checkOpts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false] as CFDictionary
            if !AXIsProcessTrustedWithOptions(checkOpts) {
                print("Cannot save layout: Accessibility permissions not granted")
                return
            }
            
            // Capture regular windows
            let windows = self.captureCurrentLayout(includeDesktopIcons: false)
            
            // Capture desktop icons separately from plist if requested
            var desktopIcons: [DesktopIconInfo]? = nil
            if includeDesktopIcons {
                print("\n*** USER CHECKED 'Include desktop icons' ***")
                desktopIcons = self.captureDesktopIcons(from: [])
                print("*** SAVED \(desktopIcons?.count ?? 0) DESKTOP ICONS TO LAYOUT ***")
                if let icons = desktopIcons {
                    for icon in icons {
                        print("  - \(icon.name) at (\(icon.position.x), \(icon.position.y))")
                    }
                }
            } else {
                print("\n*** USER DID NOT CHECK 'Include desktop icons' ***")
            }
            
            if windows.isEmpty && (desktopIcons?.isEmpty ?? true) {
                print("No windows or desktop icons found to save")
                return
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
        let checkOpts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false] as CFDictionary
        if !AXIsProcessTrustedWithOptions(checkOpts) {
            print("Cannot apply layout: Accessibility permissions not granted")
            return
        }
        
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
        
        savedLayouts.remove(at: row)
        saveLayouts()
        layoutsTableView?.reloadData()
    }
    
    // MARK: - Restore
    private func restoreLayout(_ layout: LayoutData) {
        print("Starting layout restoration for: \(layout.name)")
        
        let runningApps = NSWorkspace.shared.runningApplications
        let runningBundleIds = Set(runningApps.compactMap { $0.bundleIdentifier })
        
        var appsToLaunch: Set<String> = []
        for window in layout.windows {
            if !window.bundleIdentifier.isEmpty && !runningBundleIds.contains(window.bundleIdentifier) {
                appsToLaunch.insert(window.bundleIdentifier)
            }
        }
        
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            // Restore regular windows
            for window in layout.windows {
                self?.restoreWindow(window)
            }
            
            // Restore desktop icons separately if they were included
            if layout.includeDesktopIcons, let icons = layout.desktopIcons {
                print("\n*** LAYOUT HAS \(icons.count) DESKTOP ICONS TO RESTORE ***")
                for icon in icons {
                    print("  - \(icon.name) at (\(icon.position.x), \(icon.position.y))")
                }
                self?.restoreDesktopIcons(icons)
            } else {
                print("\n*** NO DESKTOP ICONS IN THIS LAYOUT ***")
            }
            
            print("Layout restoration complete.")
        }
    }
    
    private func restoreWindow(_ savedWindow: WindowInfo) {
        print("Restoring window: \(savedWindow.windowTitle) to \(savedWindow.frame)")
        
        let runningApps = NSWorkspace.shared.runningApplications
        guard let app = runningApps.first(where: { 
            $0.bundleIdentifier == savedWindow.bundleIdentifier ||
            $0.localizedName == savedWindow.bundleIdentifier
        }) else {
            print("App not found: \(savedWindow.bundleIdentifier)")
            return
        }
        
        if app.processIdentifier == getpid() {
            return
        }
        
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        
        var success = false
        
        if !savedWindow.windowTitle.isEmpty {
            success = moveWindowByTitle(appElement: appElement, 
                                       title: savedWindow.windowTitle, 
                                       to: savedWindow.frame,
                                       isDesktopIcon: savedWindow.isDesktopIcon)
        }
        
        if !success && savedWindow.isDesktopIcon {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                if !savedWindow.windowTitle.isEmpty {
                    _ = self?.moveWindowByTitle(appElement: appElement,
                                               title: savedWindow.windowTitle,
                                               to: savedWindow.frame,
                                               isDesktopIcon: savedWindow.isDesktopIcon)
                }
            }
        }
        
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
        
        if isDesktopIcon {
            // Desktop icons are small Finder windows - find by title
            for window in windows {
                var titleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
                   let windowTitle = titleRef as? String,
                   windowTitle == title {
                    // Verify it's a desktop icon (small size)
                    if let currentSize = getWindowSize(window),
                       currentSize.width < 100 && currentSize.height < 100 {
                        return setWindowFrame(window, frame: frame)
                    }
                }
            }
        } else {
            // Regular windows - try exact match first
            for window in windows {
                var titleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
                   let windowTitle = titleRef as? String,
                   windowTitle == title {
                    return setWindowFrame(window, frame: frame)
                }
            }
            
            // Try partial match if exact match fails
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
        var positionSettable: DarwinBoolean = false
        var sizeSettable: DarwinBoolean = false
        
        AXUIElementIsAttributeSettable(window, kAXPositionAttribute as CFString, &positionSettable)
        AXUIElementIsAttributeSettable(window, kAXSizeAttribute as CFString, &sizeSettable)
        
        if !positionSettable.boolValue || !sizeSettable.boolValue {
            print("Window attributes not settable")
            return false
        }
        
        var position = frame.origin
        if let positionValue = AXValueCreate(.cgPoint, &position) {
            let posResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
            if posResult != .success {
                print("Failed to set position: \(posResult.rawValue)")
                return false
            }
        }
        
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
        print("\n=== RESTORING DESKTOP ICONS ===")
        print("Number of icons to restore: \(icons.count)")
        
        // Desktop icons are small Finder windows - use Accessibility API to move them
        guard let finderApp = NSWorkspace.shared.runningApplications.first(where: { 
            $0.bundleIdentifier == "com.apple.finder" 
        }) else {
            print("Finder not running")
            return
        }
        
        let appElement = AXUIElementCreateApplication(finderApp.processIdentifier)
        
        for icon in icons {
            print("Restoring desktop icon: \(icon.name) to (\(icon.position.x), \(icon.position.y))")
            
            // Use the same moveWindowByTitle method but with isDesktopIcon flag
            let frame = CGRect(origin: icon.position, size: CGSize(width: 80, height: 80))
            let success = moveWindowByTitle(
                appElement: appElement,
                title: icon.name,
                to: frame,
                isDesktopIcon: true
            )
            
            if success {
                print("  ✓ Successfully restored \(icon.name)")
            } else {
                print("  ✗ Failed to restore \(icon.name)")
            }
        }
        
        print("\n=== RESTORE COMPLETE: \(icons.count) desktop icons ===")
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
