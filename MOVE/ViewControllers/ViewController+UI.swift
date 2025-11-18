import ApplicationServices
import Cocoa

extension ViewController {
    func createPermissionsBanner() {
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

    func checkPermissionsAndUpdateUI() {
        let checkOpts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false] as CFDictionary
        let hasPermission = AXIsProcessTrustedWithOptions(checkOpts)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.permissionsBanner?.isHidden = hasPermission
        }
    }

    func showSaveLayoutPopup(completion: @escaping (String, Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Save Layout"
        alert.informativeText = "Enter a name for this layout:"
        alert.alertStyle = .informational

        let nameField = NSTextField(frame: NSRect(x: 0, y: 24, width: 220, height: 24))
        nameField.placeholderString = "Layout name"
        nameField.stringValue = "Layout \(savedLayouts.count + 1)"
        nameField.setAccessibilityIdentifier("SaveLayoutNameField")

        let checkbox = NSButton(checkboxWithTitle: "Include desktop icons (not available in macOS 26)", target: nil, action: nil)
        checkbox.frame = NSRect(x: 0, y: 0, width: 220, height: 20)
        checkbox.state = .off
        checkbox.isEnabled = false
        checkbox.setAccessibilityIdentifier("SaveLayoutCheckbox")
        
        let attributedTitle = NSAttributedString(
            string: "Include desktop icons (not available in macOS 26)",
            attributes: [.foregroundColor: NSColor.disabledControlTextColor]
        )
        checkbox.attributedTitle = attributedTitle

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 48))
        container.addSubview(nameField)
        container.addSubview(checkbox)
        
        DispatchQueue.main.async {
            checkbox.isEnabled = false
            if let cell = checkbox.cell as? NSButtonCell {
                cell.isEnabled = false
            }
        }
        alert.accessoryView = container

        _ = alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

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

    func ensureAccessibilityPermission(prompt: Bool) -> Bool {
        let promptValue = prompt ? true : false
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: promptValue] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}








