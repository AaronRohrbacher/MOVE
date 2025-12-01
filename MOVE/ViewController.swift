import ApplicationServices
import Cocoa
import ObjectiveC
import os.log
import QuartzCore

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
    
    @IBOutlet var hotkeyButtonTemplate: NSButton?
    
    @IBOutlet var backgroundModeSegmentedControl: NSSegmentedControl?
    @IBOutlet var startOnLoginCheckbox: NSButton?

    var permissionsBanner: NSView?
    var permissionsLabel: NSTextField?
    var permissionsButton: NSButton?
    var gridController: GridController?
    
    fileprivate var loadingOverlayWindow: NSPanel?
    fileprivate var loadingOverlayHideWorkItem: DispatchWorkItem?

    override func viewDidLoad() {
        super.viewDidLoad()

        if ProcessInfo.processInfo.arguments.contains("--clear-user-defaults") {
            UserDefaults.standard.removeObject(forKey: layoutsKey)
            UserDefaults.standard.synchronize()
            savedLayouts = []
        }

        loadSavedLayouts()

        if savedLayouts.isEmpty {
            let testLayout = LayoutData(
                name: "Test Layout",
                windows: [WindowInfo(bundleIdentifier: "test", windowTitle: "Test Window", frame: NSRect(x: 100, y: 100, width: 800, height: 600), isMinimized: false, isHidden: false, windowNumber: 1)],
                dateCreated: Date()
            )
            savedLayouts.append(testLayout)
            LayoutPersistence.saveLayouts(savedLayouts)
        }

        setupUI()
        registerTableCellViews()
        layoutsTableView?.reloadData()
        createPermissionsBanner()
        setupGridController()
        setupBlurbTextField()
        setupBackgroundMode()
        
        if let templateButton = hotkeyButtonTemplate {
            templateButton.isHidden = true
        }
        
        if let window = view.window {
            window.restorationClass = nil
            window.isRestorable = false
        }
    }
    
    private func registerTableCellViews() {
        guard let tableView = layoutsTableView else { return }
        
        if let hotkeyNib = NSNib(nibNamed: "HotkeyTableCellView", bundle: nil) {
            tableView.register(hotkeyNib, forIdentifier: NSUserInterfaceItemIdentifier("HotkeyButton"))
        }
        
        if let layoutNib = NSNib(nibNamed: "LayoutTableCellView", bundle: nil) {
            tableView.register(layoutNib, forIdentifier: NSUserInterfaceItemIdentifier("LayoutCell"))
        }
    }
    
    fileprivate func showLoadingOverlay() {
        DispatchQueue.main.async {
            if self.loadingOverlayWindow != nil { return }
            guard let screen = self.view.window?.screen ?? NSScreen.main else { return }
            let screenFrame = screen.frame
            
            let overlay = NSPanel(contentRect: screenFrame, styleMask: [.borderless], backing: .buffered, defer: false, screen: screen)
            overlay.level = .screenSaver
            overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            overlay.animationBehavior = .none
            overlay.isOpaque = false
            overlay.backgroundColor = .clear
            overlay.ignoresMouseEvents = false
            overlay.hidesOnDeactivate = false
            overlay.isMovable = false
            overlay.isMovableByWindowBackground = false
            overlay.hasShadow = false
            overlay.titleVisibility = .hidden
            overlay.titlebarAppearsTransparent = true
            overlay.isReleasedWhenClosed = false
            overlay.sharingType = .none
            overlay.preventsApplicationTerminationWhenModal = false
            
            let rootView = NSView(frame: NSRect(origin: .zero, size: screenFrame.size))
            rootView.translatesAutoresizingMaskIntoConstraints = true
            overlay.contentView = rootView
            
            let contentView = NSView()
            contentView.translatesAutoresizingMaskIntoConstraints = false
            contentView.wantsLayer = true
            contentView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.35).cgColor
            rootView.addSubview(contentView)
            
            let container = NSView()
            container.translatesAutoresizingMaskIntoConstraints = false
            container.wantsLayer = true
            container.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.85).cgColor
            container.layer?.cornerRadius = 16
            
            let logoImage = NSApp.applicationIconImage ?? NSImage(size: NSSize(width: 128, height: 128))
            let logoView = NSImageView(image: logoImage)
            logoView.translatesAutoresizingMaskIntoConstraints = false
            logoView.wantsLayer = true
            logoView.layer?.cornerRadius = 18
            logoView.layer?.masksToBounds = true
            logoView.imageScaling = .scaleProportionallyUpOrDown
            
            let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
            rotation.fromValue = 0
            rotation.toValue = Double.pi * 2
            rotation.duration = 1.6
            rotation.repeatCount = .infinity
            logoView.layer?.add(rotation, forKey: "spin")
            
            let label = NSTextField(labelWithString: "Applying layout…")
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = NSFont.systemFont(ofSize: 15, weight: .medium)
            label.textColor = .labelColor
            label.alignment = .center
            
            let stack = NSStackView()
            stack.orientation = .vertical
            stack.alignment = .centerX
            stack.distribution = .gravityAreas
            stack.spacing = 12
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(logoView)
            stack.addArrangedSubview(label)
            
            container.addSubview(stack)
            contentView.addSubview(container)
            
            NSLayoutConstraint.activate([
                contentView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
                contentView.topAnchor.constraint(equalTo: rootView.topAnchor),
                contentView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
                
                container.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                container.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
                
                stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
                stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32),
                stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
                stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -24),
                
                logoView.widthAnchor.constraint(equalToConstant: 72),
                logoView.heightAnchor.constraint(equalTo: logoView.widthAnchor)
            ])
            
            overlay.alphaValue = 0
            overlay.makeKeyAndOrderFront(nil)
            overlay.animator().alphaValue = 1
            self.loadingOverlayWindow = overlay
            
            self.loadingOverlayHideWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.hideLoadingOverlay()
            }
            self.loadingOverlayHideWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: workItem)
        }
    }
    
    fileprivate func hideLoadingOverlay() {
        DispatchQueue.main.async {
            self.loadingOverlayHideWorkItem?.cancel()
            self.loadingOverlayHideWorkItem = nil
            guard let overlay = self.loadingOverlayWindow else { return }
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                overlay.animator().alphaValue = 0
            } completionHandler: {
                overlay.orderOut(nil)
                self.loadingOverlayWindow = nil
            }
        }
    }
    
    func setupBackgroundMode() {
        if let control = backgroundModeSegmentedControl {
            if control.segmentCount < 2 {
                control.segmentCount = 2
                if control.label(forSegment: 0)?.isEmpty != false {
                    control.setLabel("Dock", forSegment: 0)
                }
                if control.label(forSegment: 1)?.isEmpty != false {
                    control.setLabel("Menu Bar", forSegment: 1)
                }
            }
            control.target = self
            control.action = #selector(backgroundModeChanged(_:))
            control.selectedSegment = BackgroundModeManager.shared.currentMode == .dock ? 0 : 1
        }
        
        if let checkbox = startOnLoginCheckbox {
            checkbox.setButtonType(.switch)
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
        
        if let titleRange = fullText.range(of: titleText) {
            let nsRange = NSRange(titleRange, in: fullText)
            attributedString.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 12), range: nsRange)
            attributedString.addAttribute(.foregroundColor, value: NSColor.labelColor, range: nsRange)
        }
        
        if let subtitleRange = fullText.range(of: subtitleText) {
            let nsRange = NSRange(subtitleRange, in: fullText)
            attributedString.addAttribute(.font, value: NSFont.systemFont(ofSize: 10), range: nsRange)
            attributedString.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: nsRange)
        }
        
        if let urlRange = fullText.range(of: urlString) {
            let nsRange = NSRange(urlRange, in: fullText)
            if let url = URL(string: urlString) {
                attributedString.addAttribute(.link, value: url, range: nsRange)
            }
            attributedString.addAttribute(.font, value: NSFont.systemFont(ofSize: 10), range: nsRange)
            attributedString.addAttribute(.foregroundColor, value: NSColor.linkColor, range: nsRange)
            attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: nsRange)
        }
        
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
        let gridController = GridController()
        gridController.mainViewController = self
        
        gridController.gridIconButtons = [gridIconButton4, gridIconButton8, gridIconButton12].compactMap { $0 }
        gridController.rowSelectionButtons = [rowButtonUpper, rowButtonMiddle, rowButtonLower, rowButtonNone].compactMap { $0 }
        gridController.additionalRowsStepper = additionalRowsStepper
        gridController.additionalRowsLabel = additionalRowsLabel
        gridController.applyGridButton = applyGridButton
        
        gridController.setupUIFromStoryboard()
        self.gridController = gridController
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        BackgroundModeManager.shared.setMainWindowVisible(true)
        
        if let window = view.window {
            window.contentMinSize = NSSize(width: 680, height: 360)
            window.contentMaxSize = NSSize(width: 2000, height: 2000)
        }

        saveLayoutButton?.setAccessibilityIdentifier("SaveCurrentLayoutButton")
        applyLayoutButton?.setAccessibilityIdentifier("ApplyLayoutButton")
        deleteLayoutButton?.setAccessibilityIdentifier("DeleteLayoutButton")
        
        applyLayoutButton?.target = self
        applyLayoutButton?.action = #selector(applyLayout)
        applyLayoutButton?.isEnabled = true

        checkPermissionsAndUpdateUI()
        permissionsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkPermissionsAndUpdateUI()
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        BackgroundModeManager.shared.setMainWindowVisible(false)
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

    func captureCurrentLayout() -> [WindowInfo] {
        var windows: [WindowInfo] = []
        let myPID = getpid()

        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
        }

        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
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

            let bundleId = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == pid })?.bundleIdentifier ?? ownerName

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
        showLoadingOverlay()
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
            guard let self = self else { return }
            for window in layout.windows {
                self.restoreWindow(window)
            }
            
            self.hideLoadingOverlay()
        }
    }

    private func restoreWindow(_ savedWindow: WindowInfo) {
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == savedWindow.bundleIdentifier || $0.localizedName == savedWindow.bundleIdentifier
        }), app.processIdentifier != getpid() else { return }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        _ = !savedWindow.windowTitle.isEmpty && moveWindowByTitle(appElement: appElement, title: savedWindow.windowTitle, to: savedWindow.frame) || moveFirstWindow(of: appElement, to: savedWindow.frame)
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
        guard positionSettable.boolValue && sizeSettable.boolValue else { return false }

        var position = frame.origin
        guard let positionValue = AXValueCreate(.cgPoint, &position),
              AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue) == .success else {
            return false
        }

        var size = frame.size
        guard let sizeValue = AXValueCreate(.cgSize, &size),
              AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue) == .success else {
            return false
        }

        return true
    }

}

