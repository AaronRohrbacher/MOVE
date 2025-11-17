import Cocoa

class HotkeyManager {
    static let shared = HotkeyManager()
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var hotkeyHandlers: [String: () -> Void] = [:]
    private var layoutIndices: [String: Int] = [:] // Track which layout index uses which hotkey

    private init() {}

    static func normalizeModifiers(_ modifiers: NSEvent.ModifierFlags) -> UInt {
        return modifiers.rawValue & (NSEvent.ModifierFlags.command.rawValue |
                                   NSEvent.ModifierFlags.shift.rawValue |
                                   NSEvent.ModifierFlags.option.rawValue |
                                   NSEvent.ModifierFlags.control.rawValue)
    }
    
    func registerHotkey(_ hotkey: HotkeyData, forLayoutIndex index: Int, handler: @escaping () -> Void) {
        let key = hotkeyKey(hotkey)

        print("HotkeyManager: Registering hotkey - keyCode: \(hotkey.keyCode), modifiers: \(hotkey.modifiers), key: \(key), layoutIndex: \(index)")

        // Unregister any existing hotkey for this layout index
        if let existingKey = layoutIndices.first(where: { $0.value == index })?.key {
            print("HotkeyManager: Removing existing hotkey for layout \(index): \(existingKey)")
            hotkeyHandlers.removeValue(forKey: existingKey)
            layoutIndices.removeValue(forKey: existingKey)
        }

        hotkeyHandlers[key] = handler
        layoutIndices[key] = index
        startMonitoring()

        print("HotkeyManager: Registration complete. Total handlers: \(hotkeyHandlers.count)")
    }
    
    func unregisterHotkey(_ hotkey: HotkeyData) {
        let key = hotkeyKey(hotkey)
        hotkeyHandlers.removeValue(forKey: key)
        layoutIndices.removeValue(forKey: key)
        if hotkeyHandlers.isEmpty {
            stopMonitoring()
        }
    }
    
    func unregisterHotkeyForLayout(at index: Int) {
        if let existingKey = layoutIndices.first(where: { $0.value == index })?.key {
            hotkeyHandlers.removeValue(forKey: existingKey)
            layoutIndices.removeValue(forKey: existingKey)
            if hotkeyHandlers.isEmpty {
                stopMonitoring()
            }
        }
    }
    
    func unregisterAll() {
        hotkeyHandlers.removeAll()
        layoutIndices.removeAll()
        stopMonitoring()
    }
    
    private func hotkeyKey(_ hotkey: HotkeyData) -> String {
        return "\(hotkey.keyCode)_\(hotkey.modifiers)"
    }
    
    private func startMonitoring() {
        guard globalMonitor == nil && localMonitor == nil else { return }

        // Check for accessibility permissions
        let hasAccessibility = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary)
        print("HotkeyManager: Accessibility permissions: \(hasAccessibility ? "GRANTED" : "DENIED")")

        // Global monitor for when app is in background (requires accessibility permissions)
        if hasAccessibility {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
                self?.handleEvent(event)
            }
            print("HotkeyManager: Global monitor started")
        } else {
            print("HotkeyManager: Global monitor NOT started - no accessibility permissions")
        }

        // Local monitor for when app is active (always works)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.handleEvent(event)
            return event // Don't consume local events
        }
        print("HotkeyManager: Local monitor started")
    }

    private func stopMonitoring() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    private func handleEvent(_ event: NSEvent) {
        // Handle both keyDown and flagsChanged events
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let normalizedModifiers = HotkeyManager.normalizeModifiers(modifiers)

        let key = "\(keyCode)_\(normalizedModifiers)"

        // Debug logging
        print("HotkeyManager: Event type: \(event.type.rawValue), keyCode: \(keyCode), modifiers: \(String(format: "0x%X", modifiers.rawValue)), normalized: \(String(format: "0x%X", normalizedModifiers)), key: \(key)")

        // Only trigger on keyDown events (when a key is actually pressed)
        if event.type == .keyDown {
            print("HotkeyManager: Registered handlers: \(Array(hotkeyHandlers.keys))")

            if let handler = hotkeyHandlers[key] {
                print("HotkeyManager: Found handler for key: \(key) - triggering!")
                DispatchQueue.main.async {
                    handler()
                }
            } else {
                print("HotkeyManager: No handler found for key: \(key)")
            }
        }
    }
    
    deinit {
        stopMonitoring()
    }
}

