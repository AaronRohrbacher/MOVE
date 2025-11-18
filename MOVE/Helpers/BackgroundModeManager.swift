import Cocoa
import ServiceManagement

class BackgroundModeManager: NSObject {
    static let shared = BackgroundModeManager()
    
    enum BackgroundMode: String {
        case dock = "dock"
        case menuBar = "menuBar"
    }
    
    private var statusItem: NSStatusItem?
    private let backgroundModeKey = "BackgroundMode"
    private let startOnLoginKey = "StartOnLogin"
    private var visibleWindowCount = 0
    
    override init() {
        super.init()
        loadSettings()
    }
    
    var currentMode: BackgroundMode {
        get {
            if let modeString = UserDefaults.standard.string(forKey: backgroundModeKey),
               let mode = BackgroundMode(rawValue: modeString) {
                return mode
            }
            return .dock
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: backgroundModeKey)
            applyMode(newValue)
        }
    }
    
    var startOnLogin: Bool {
        get {
            return UserDefaults.standard.bool(forKey: startOnLoginKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: startOnLoginKey)
            setLoginItem(enabled: newValue)
        }
    }
    
    private func loadSettings() {
        applyMode(currentMode)
        setLoginItem(enabled: startOnLogin)
    }
    
    private func applyMode(_ mode: BackgroundMode) {
        switch mode {
        case .dock:
            removeStatusItem()
        case .menuBar:
            createStatusItem()
        }
        updateActivationPolicy()
    }

    private func updateActivationPolicy() {
        if visibleWindowCount > 0 {
            NSApp.setActivationPolicy(.regular)
            return
        }
        switch currentMode {
        case .dock:
            NSApp.setActivationPolicy(.regular)
        case .menuBar:
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func setMainWindowVisible(_ isVisible: Bool) {
        if isVisible {
            visibleWindowCount += 1
        } else {
            visibleWindowCount = max(0, visibleWindowCount - 1)
        }
        updateActivationPolicy()
    }
    
    private func createStatusItem() {
        guard statusItem == nil else { return }
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            if let appIcon = NSImage(named: "AppIcon") ?? NSApplication.shared.applicationIconImage {
                button.image = appIcon
                appIcon.size = NSSize(width: 18, height: 18)
            } else {
                button.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "MOVE")
                button.image?.isTemplate = true
            }
            button.action = nil
            button.target = nil
        }
        
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        let showWindowItem = NSMenuItem(title: "Show Window", action: #selector(showWindow), keyEquivalent: "")
        showWindowItem.target = self
        showWindowItem.isEnabled = true
        menu.addItem(showWindowItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit MOVE", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        quitItem.isEnabled = true
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    private func removeStatusItem() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }
    
    @objc private func statusItemClicked() {
        showWindow()
    }
    
    @objc private func showWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private func setLoginItem(enabled: Bool) {
        if #available(macOS 13.0, *) {
            if enabled {
                do {
                    try SMAppService.mainApp.register()
                } catch {
                    print("Failed to register login item: \(error)")
                }
            } else {
                do {
                    try SMAppService.mainApp.unregister()
                } catch {
                    print("Failed to unregister login item: \(error)")
                }
            }
        } else {
            let loginItemsList = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeUnretainedValue(), nil)
            guard let loginItems = loginItemsList?.takeRetainedValue() else { return }
            
            let appURL = Bundle.main.bundleURL as CFURL
            
            if enabled {
                var snapshot: Unmanaged<CFArray>?
                snapshot = LSSharedFileListCopySnapshot(loginItems, nil)
                if let items = snapshot?.takeRetainedValue() as? [LSSharedFileListItem] {
                    var alreadyExists = false
                    for item in items {
                        var resolvedURL: Unmanaged<CFURL>?
                        resolvedURL = LSSharedFileListItemCopyResolvedURL(item, 0, nil)
                        if let url = resolvedURL?.takeRetainedValue() as URL?,
                           url == appURL as URL {
                            alreadyExists = true
                            break
                        }
                    }
                    if !alreadyExists {
                        LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemBeforeFirst.takeUnretainedValue(), nil, nil, appURL, nil, nil)
                    }
                } else {
                    LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemBeforeFirst.takeUnretainedValue(), nil, nil, appURL, nil, nil)
                }
            } else {
                var snapshot: Unmanaged<CFArray>?
                snapshot = LSSharedFileListCopySnapshot(loginItems, nil)
                guard let items = snapshot?.takeRetainedValue() as? [LSSharedFileListItem] else { return }
                
                for item in items {
                    var resolvedURL: Unmanaged<CFURL>?
                    resolvedURL = LSSharedFileListItemCopyResolvedURL(item, 0, nil)
                    if let url = resolvedURL?.takeRetainedValue() as URL?,
                       url == appURL as URL {
                        LSSharedFileListItemRemove(loginItems, item)
                    }
                }
            }
        }
    }
}

