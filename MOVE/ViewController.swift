import ApplicationServices
import Cocoa
import ObjectiveC

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
}

struct DesktopIconInfo: Codable {
    let name: String
    let position: CGPoint
}

extension CGRect: Codable {
    enum CodingKeys: String, CodingKey {
        case x, y, width, height
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(origin.x, forKey: .x)
        try container.encode(origin.y, forKey: .y)
        try container.encode(size.width, forKey: .width)
        try container.encode(size.height, forKey: .height)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        let width = try container.decode(CGFloat.self, forKey: .width)
        let height = try container.decode(CGFloat.self, forKey: .height)
        self.init(x: x, y: y, width: width, height: height)
    }
}

class ViewController: NSViewController {
    var savedLayouts: [LayoutData] = []
    private let layoutsKey = "SavedLayouts"
    private var permissionsTimer: Timer?

    @IBOutlet var applyLayoutButton: NSButton?
    @IBOutlet var deleteLayoutButton: NSButton?
    @IBOutlet var saveLayoutButton: NSButton?
    @IBOutlet var layoutsScrollView: NSScrollView?
    @IBOutlet var layoutsTableView: NSTableView?

    var permissionsBanner: NSView?
    private var permissionsLabel: NSTextField?
    private var permissionsButton: NSButton?

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

        saveLayoutButton?.setAccessibilityIdentifier("SaveCurrentLayoutButton")
        applyLayoutButton?.setAccessibilityIdentifier("ApplyLayoutButton")
        deleteLayoutButton?.setAccessibilityIdentifier("DeleteLayoutButton")

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

        permissionsBanner = banner
        permissionsLabel = label
        permissionsButton = button
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

    func loadSavedLayouts() {
        if let data = UserDefaults.standard.data(forKey: layoutsKey) {
            do {
                let layouts = try JSONDecoder().decode([LayoutData].self, from: data)
                savedLayouts = layouts
                print("Loaded \(layouts.count) saved layouts")
            } catch {
                print("Failed to load layouts: \(error)")
                print("Error details: \(error.localizedDescription)")
                if let decodingError = error as? DecodingError {
                    print("Decoding error: \(decodingError)")
                }
                UserDefaults.standard.removeObject(forKey: layoutsKey)
                savedLayouts = []
            }
        } else {
            print("No saved layouts found in UserDefaults")
        }
        DispatchQueue.main.async { [weak self] in
            self?.layoutsTableView?.reloadData()
        }
    }

    func saveLayouts() {
        do {
            let data = try JSONEncoder().encode(savedLayouts)
            UserDefaults.standard.set(data, forKey: layoutsKey)
            UserDefaults.standard.synchronize()
            print("Successfully saved \(savedLayouts.count) layouts to UserDefaults")
        } catch {
            print("Failed to save layouts: \(error)")
            print("Error details: \(error.localizedDescription)")
            if let encodingError = error as? EncodingError {
                print("Encoding error: \(encodingError)")
            }
        }
    }

    private func captureCurrentLayout() -> [WindowInfo] {
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

            let frame = CGRect(x: xValue, y: yValue, width: width, height: height)

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

    func captureDesktopIcons(from windows: [WindowInfo]) -> [DesktopIconInfo] {
        return detectDesktopIcons(using: windows).icons
    }

    @objc func saveLayout() {
        showSaveLayoutPopup { [weak self] name, includeDesktopIcons in
            guard let self = self, !name.isEmpty else { return }

            var windows = self.captureCurrentLayout()

            var capturedDesktopIcons: [DesktopIconInfo] = []
            if includeDesktopIcons {
                let extraction = self.extractDesktopIconsAndFilter(from: windows)
                capturedDesktopIcons = extraction.icons
                windows = extraction.filteredWindows

                if capturedDesktopIcons.isEmpty {
                    print("saveLayout: includeDesktopIcons requested but no desktop icons were detected. Layout will not store icon positions.")
                }
            }

            let layout = LayoutData(
                name: name,
                windows: windows,
                desktopIcons: capturedDesktopIcons.isEmpty ? nil : capturedDesktopIcons,
                includeDesktopIcons: includeDesktopIcons && !capturedDesktopIcons.isEmpty,
                dateCreated: Date()
            )

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.savedLayouts.append(layout)
                self.saveLayouts()
                self.layoutsTableView?.reloadData()
            }
        }
    }

    @objc private func applyLayout() {
        let checkOpts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false] as CFDictionary
        if !AXIsProcessTrustedWithOptions(checkOpts) {
            print("Cannot apply layout: Accessibility permissions not granted")
            return
        }

        var row = layoutsTableView?.selectedRow ?? -1
        if row < 0, !savedLayouts.isEmpty {
            row = 0
            layoutsTableView?.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        guard row >= 0, row < savedLayouts.count else {
            print("No layout selected")
            return
        }

        let layout = savedLayouts[row]

        restoreLayout(layout)
    }

    @objc private func deleteLayout() {
        var row = layoutsTableView?.selectedRow ?? -1
        if row < 0, !savedLayouts.isEmpty { row = 0 }
        guard row >= 0, row < savedLayouts.count else { return }

        savedLayouts.remove(at: row)
        saveLayouts()
        layoutsTableView?.reloadData()
    }

    private func restoreLayout(_ layout: LayoutData) {
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
        let runningApps = NSWorkspace.shared.runningApplications
        guard let app = runningApps.first(where: {
            $0.bundleIdentifier == savedWindow.bundleIdentifier ||
                $0.localizedName == savedWindow.bundleIdentifier
        }) else {
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
                                        to: savedWindow.frame)
        }

        if !success {
            success = moveFirstWindow(of: appElement, to: savedWindow.frame)
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

    func restoreDesktopIcons(_ icons: [DesktopIconInfo]) {
        guard !icons.isEmpty else {
            print("restoreDesktopIcons: icons array is empty")
            return
        }

        guard ensureAccessibilityPermission(prompt: false) else {
            print("restoreDesktopIcons: Accessibility permission missing")
            return
        }

        let targetNames = Set(icons.map { $0.name })
        let iconElements = gatherFinderIconElements(targetNames: targetNames)

        guard !iconElements.isEmpty else {
            print("restoreDesktopIcons: Could not locate any Finder AX elements for requested icons")
            return
        }

        var movedCount = 0
        var failedIcons: [String] = []

        for icon in icons {
            guard let element = iconElements[icon.name] else {
                failedIcons.append("\(icon.name) (AX element not found)")
                continue
            }

            if setFinderIcon(element, to: icon.position) {
                movedCount += 1
            } else if dragFinderIconElement(element, targetPosition: icon.position) {
                movedCount += 1
            } else {
                failedIcons.append("\(icon.name) (position attribute not settable)")
            }
        }

        print("restoreDesktopIcons: Moved \(movedCount) of \(icons.count) icons")
        if !failedIcons.isEmpty {
            print("restoreDesktopIcons: Failed icons: \(failedIcons)")
        }
    }

    private func extractDesktopIconsAndFilter(from windows: [WindowInfo])
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

    private func ensureAccessibilityPermission(prompt: Bool) -> Bool {
        let promptValue = prompt ? true : false
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: promptValue] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
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
        guard settable.boolValue else { return false }

        var mutablePosition = position
        guard let value = AXValueCreate(.cgPoint, &mutablePosition) else { return false }
        return AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value) == .success
    }

    private func dragFinderIconElement(_ element: AXUIElement, targetPosition: CGPoint) -> Bool {
        guard let currentPosition = attributePoint(kAXPositionAttribute as CFString, for: element),
              let size = attributeSize(kAXSizeAttribute as CFString, for: element)
        else {
            return false
        }

        let distance = hypot(currentPosition.x - targetPosition.x, currentPosition.y - targetPosition.y)
        if distance < 1.0 {
            return true
        }

        bringFinderToFront()

        let startCenter = CGPoint(x: currentPosition.x + size.width / 2, y: currentPosition.y + size.height / 2)
        let endCenter = CGPoint(x: targetPosition.x + size.width / 2, y: targetPosition.y + size.height / 2)

        return simulateMouseDrag(from: startCenter, to: endCenter)
    }

    private func bringFinderToFront() {
        if let finderApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) {
            finderApp.activate(options: [.activateIgnoringOtherApps])
        }
    }

    private func simulateMouseDrag(from start: CGPoint, to end: CGPoint) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return false }

        let originalLocation = NSEvent.mouseLocation
        CGWarpMouseCursorPosition(start)
        usleep(15000)

        let downEvent = CGEvent(mouseEventSource: source,
                                mouseType: .leftMouseDown,
                                mouseCursorPosition: start,
                                mouseButton: .left)
        downEvent?.post(tap: .cghidEventTap)
        usleep(15000)

        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = hypot(dx, dy)
        let steps = max(6, Int(distance / 40))

        for step in 1 ... steps {
            let t = CGFloat(step) / CGFloat(steps)
            let intermediate = CGPoint(x: start.x + dx * t, y: start.y + dy * t)
            let dragEvent = CGEvent(mouseEventSource: source,
                                    mouseType: .leftMouseDragged,
                                    mouseCursorPosition: intermediate,
                                    mouseButton: .left)
            dragEvent?.post(tap: .cghidEventTap)
            usleep(12000)
        }

        let upEvent = CGEvent(mouseEventSource: source,
                              mouseType: .leftMouseUp,
                              mouseCursorPosition: end,
                              mouseButton: .left)
        upEvent?.post(tap: .cghidEventTap)
        usleep(20000)

        CGWarpMouseCursorPosition(originalLocation)
        return true
    }

    // MARK: - UI Helpers

    private func showSaveLayoutPopup(completion: @escaping (String, Bool) -> Void) {
        // Use NSAlert with accessory view as a sheet (standard macOS modal)
        let alert = NSAlert()
        alert.messageText = "Save Layout"
        alert.informativeText = "Enter a name for this layout:"
        alert.alertStyle = .informational

        // Create accessory view with text field and checkbox
        let nameField = NSTextField(frame: NSRect(x: 0, y: 24, width: 220, height: 24))
        nameField.placeholderString = "Layout name"
        nameField.stringValue = "Layout \(savedLayouts.count + 1)"
        nameField.setAccessibilityIdentifier("SaveLayoutNameField")

        let checkbox = NSButton(checkboxWithTitle: "Include desktop icons", target: nil, action: nil)
        checkbox.frame = NSRect(x: 0, y: 0, width: 220, height: 20)
        checkbox.state = .off
        checkbox.setAccessibilityIdentifier("SaveLayoutCheckbox")

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 48))
        container.addSubview(nameField)
        container.addSubview(checkbox)
        alert.accessoryView = container

        // Add buttons - first button is the default/primary action
        _ = alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        // Set accessibility identifiers
        alert.window.setAccessibilityIdentifier("SaveLayoutWindow")
        if let buttons = alert.window.contentView?.subviews.compactMap({ $0 as? NSButton }) {
            for (index, button) in buttons.enumerated() {
                if index == 0 {
                    button.setAccessibilityIdentifier("SaveLayoutSaveButton")
                } else if index == 1 {
                    button.setAccessibilityIdentifier("SaveLayoutCancelButton")
                }
            }
        }

        alert.window.initialFirstResponder = nameField

        // Use beginSheetModalForWindow for testable modal
        guard let window = view.window else { return }
        alert.beginSheetModal(for: window) { response in
            if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let includeDesktopIcons = checkbox.state == .on
                DispatchQueue.main.async {
                    completion(name, includeDesktopIcons)
                }
            }
        }
    }
}

// MARK: - Table View DataSource & Delegate

extension ViewController: NSTableViewDataSource {
    func numberOfRows(in _: NSTableView) -> Int {
        return savedLayouts.count
    }
}

extension ViewController: NSTableViewDelegate {
    func tableView(_: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        guard row < savedLayouts.count else { return nil }

        let layout = savedLayouts[row]
        let cell = NSTableCellView()

        let textField = NSTextField(labelWithString: layout.name)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.lineBreakMode = .byTruncatingTail
        textField.setAccessibilityLabel(layout.name) // Make it accessible for tests
        cell.addSubview(textField)

        let subtitleText = "\(layout.windows.count) windows"
        let subtitle = NSTextField(labelWithString: subtitleText)
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        subtitle.font = NSFont.systemFont(ofSize: 11)
        subtitle.textColor = NSColor.secondaryLabelColor
        subtitle.setAccessibilityLabel(subtitleText) // Make it accessible for tests
        cell.addSubview(subtitle)

        // Set cell's accessibility label to the layout name for easier testing
        cell.setAccessibilityLabel(layout.name)

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

    func tableView(_: NSTableView, heightOfRow _: Int) -> CGFloat {
        return 48
    }
}
