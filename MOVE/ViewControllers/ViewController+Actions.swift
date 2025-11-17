import ApplicationServices
import Cocoa

extension ViewController {
    @objc func hotkeyButtonClicked(_ sender: NSButton) {
        print("HOTKEY: Button clicked for row \(sender.tag)")

        let row = sender.tag
        guard row >= 0 && row < savedLayouts.count else {
            print("HOTKEY: Invalid row \(row)")
            return
        }

        // Simple hotkey input using NSAlert with a text field
        let alert = NSAlert()
        alert.messageText = "Set Hotkey"
        alert.informativeText = "Press a key combination (e.g., Cmd+U):"

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.placeholderString = "Press keys..."
        alert.accessoryView = textField

        alert.addButton(withTitle: "Set")
        alert.addButton(withTitle: "Cancel")

        textField.becomeFirstResponder()

        // Use a custom key event handler
        var eventMonitor: Any?

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if event.keyCode == 53 { // Escape key
                NSApp.stopModal()
                return nil
            }

            let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
            if modifiers.isEmpty {
                textField.stringValue = "Include modifier key"
                return nil
            }

            let keyString = self.formatHotkeyString(keyCode: event.keyCode, modifiers: modifiers)
            textField.stringValue = keyString

            // Store the hotkey
            let normalizedModifiers = HotkeyManager.normalizeModifiers(modifiers)
            let hotkey = HotkeyData(keyCode: event.keyCode, modifiers: normalizedModifiers, keyString: keyString)
            self.savedLayouts[row].hotkey = hotkey
            LayoutPersistence.saveLayouts(self.savedLayouts)

            // Register the hotkey
            HotkeyManager.shared.registerHotkey(hotkey, forLayoutIndex: row) { [weak self] in
                self?.applyLayoutAtIndex(at: row)
            }

            // Update the button
            sender.title = keyString
            sender.contentTintColor = .controlAccentColor

            print("HOTKEY: Set hotkey \(keyString) for layout \(row)")

            NSApp.stopModal()
            return nil
        }

        alert.runModal()

        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func formatHotkeyString(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []

        if modifiers.contains(.command) {
            parts.append("⌘")
        }
        if modifiers.contains(.shift) {
            parts.append("⇧")
        }
        if modifiers.contains(.option) {
            parts.append("⌥")
        }
        if modifiers.contains(.control) {
            parts.append("⌃")
        }

        // Convert key code to character
        if let keyChar = keyCodeToString(keyCode) {
            parts.append(keyChar)
        } else {
            parts.append("Key\(keyCode)")
        }

        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String? {
        // Correct macOS key codes (US keyboard layout)
        let keyMap: [UInt16: String] = [
            // A-Z letters (correct mapping)
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P",
            37: "L", 38: "J", 40: "K", 45: "N", 46: "M",

            // Numbers 0-9
            18: "1", 19: "2", 20: "3", 21: "4", 22: "5", 23: "6", 24: "7", 25: "8", 26: "9", 27: "0",

            // Punctuation and special characters
            28: "-", 29: "=", 30: "[", 33: "]", 36: "Return", 39: ";", 41: "'",
            42: "\\", 43: ",", 44: "/", 47: ".", 48: "Tab", 49: "Space", 50: "`", 51: "Delete", 53: "Escape",

            // Arrow keys
            123: "←", 124: "→", 125: "↓", 126: "↑",

            // Function keys
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
            103: "F11", 105: "F13", 106: "F16", 107: "F14", 109: "F10",
            111: "F12", 113: "F15", 114: "Help", 115: "Home", 116: "Page Up",
            117: "Delete Forward", 118: "F4", 119: "End", 120: "F2",
            121: "Page Down", 122: "F1"
        ]

        return keyMap[keyCode]
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension ViewController {
    @objc func saveLayout() {
        showSaveLayoutPopup { [weak self] name, includeDesktopIcons in
            guard let self = self, !name.isEmpty else { return }

            var windows = WindowCapture.captureCurrentLayout()

            var capturedDesktopIcons: [DesktopIconInfo] = []
            if includeDesktopIcons {
                let extraction = self.extractDesktopIconsAndFilter(from: windows)
                capturedDesktopIcons = extraction.icons
                windows = extraction.filteredWindows
            }

            let layout = LayoutData(
                name: name,
                windows: windows,
                desktopIcons: capturedDesktopIcons.isEmpty ? nil : capturedDesktopIcons,
                includeDesktopIcons: includeDesktopIcons,
                dateCreated: Date()
            )

            self.savedLayouts.append(layout)
            self.saveLayouts()
            self.layoutsTableView?.reloadData()
        }
    }

    @objc func applyLayout() {
        print("applyLayout called")
        var row = layoutsTableView?.selectedRow ?? -1
        print("Selected row: \(row), savedLayouts count: \(savedLayouts.count)")
        if row < 0, !savedLayouts.isEmpty {
            row = 0
            layoutsTableView?.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        guard row >= 0, row < savedLayouts.count else {
            print("applyLayout: No valid row selected")
            return
        }

        let layout = savedLayouts[row]
        print("applyLayout: Restoring layout '\(layout.name)' with \(layout.windows.count) windows")
        self.restoreLayout(layout)
    }

    @objc func deleteLayout() {
        var row = layoutsTableView?.selectedRow ?? -1
        if row < 0, !savedLayouts.isEmpty { row = 0 }
        guard row >= 0, row < savedLayouts.count else { return }

        savedLayouts.remove(at: row)
        saveLayouts()
        layoutsTableView?.reloadData()
    }

}

