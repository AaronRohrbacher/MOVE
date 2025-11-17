import Cocoa


extension ViewController: NSTableViewDataSource {
    func numberOfRows(in _: NSTableView) -> Int {
        return savedLayouts.count
    }
}

extension ViewController: NSTableViewDelegate {
    // Allow controls in cells to become first responder immediately
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < savedLayouts.count else { return nil }
        let layout = savedLayouts[row]

        // Debug: Write to file
        let debugString = "TableView: Creating cell for row \(row), column: \(tableColumn?.identifier.rawValue ?? "nil"), layouts count: \(savedLayouts.count)\n"
        if let data = debugString.data(using: .utf8) {
            let fileURL = URL(fileURLWithPath: "/tmp/move_debug.log")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let fileHandle = try? FileHandle(forWritingTo: fileURL)
                fileHandle?.seekToEndOfFile()
                fileHandle?.write(data)
                fileHandle?.closeFile()
            } else {
                try? data.write(to: fileURL)
            }
        }

        // Handle different columns
        if tableColumn?.identifier.rawValue == "hotkey" {
            // Hotkey column - NSButton as cell view (standard Apple pattern)
            let button = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("HotkeyButton"), owner: self) as? NSButton ?? {
                let btn = NSButton()
                btn.identifier = NSUserInterfaceItemIdentifier("HotkeyButton")
                btn.bezelStyle = .rounded
                btn.isBordered = false
                btn.font = NSFont.systemFont(ofSize: 11)
                btn.alignment = .right
                btn.wantsLayer = true
                btn.layer?.cornerRadius = 6
                btn.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
                btn.layer?.borderWidth = 1.0
                btn.layer?.borderColor = NSColor.separatorColor.cgColor
                btn.target = self
                btn.action = #selector(hotkeyButtonClicked(_:))
                return btn
            }()

            button.tag = row
            let hotkeyText = layout.hotkey?.keyString ?? "Click to set hotkey"
            button.title = hotkeyText
            button.contentTintColor = layout.hotkey != nil ? .controlAccentColor : .secondaryLabelColor

            return button
        } else {
            // Layout name column - create cell with title and info
            var cellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("LayoutCell"), owner: self) as? NSTableCellView

            if cellView == nil {
                cellView = NSTableCellView()
                cellView?.identifier = NSUserInterfaceItemIdentifier("LayoutCell")

                // Title field
                let titleField = NSTextField(labelWithString: "")
                titleField.translatesAutoresizingMaskIntoConstraints = false
                titleField.font = NSFont.systemFont(ofSize: 13)
                titleField.lineBreakMode = .byTruncatingTail
                cellView?.addSubview(titleField)
                cellView?.textField = titleField

                // Info field
                let infoField = NSTextField(labelWithString: "")
                infoField.translatesAutoresizingMaskIntoConstraints = false
                infoField.font = NSFont.systemFont(ofSize: 10)
                infoField.textColor = NSColor.secondaryLabelColor
                infoField.lineBreakMode = .byTruncatingTail
                cellView?.addSubview(infoField)

                NSLayoutConstraint.activate([
                    titleField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 5),
                    titleField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -5),
                    titleField.topAnchor.constraint(equalTo: cellView!.topAnchor, constant: 6),

                    infoField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 5),
                    infoField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -5),
                    infoField.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 2),
                    infoField.bottomAnchor.constraint(lessThanOrEqualTo: cellView!.bottomAnchor, constant: -6)
                ])
            }

            // Configure with layout data
            let iconIndicator = layout.includeDesktopIcons ? "🖥️ " : ""
            let windowCount = layout.windows.count
            let iconCount = layout.desktopIcons?.count ?? 0

            cellView?.textField?.stringValue = "\(iconIndicator)\(layout.name)"

            var infoParts: [String] = []
            infoParts.append("\(windowCount) window\(windowCount == 1 ? "" : "s")")
            if iconCount > 0 {
                infoParts.append("\(iconCount) icon\(iconCount == 1 ? "" : "s")")
            }

            // Find info field (second text field in cell)
            if let infoField = cellView?.subviews.compactMap({ $0 as? NSTextField }).first(where: { $0 != cellView?.textField }) {
                infoField.stringValue = infoParts.joined(separator: ", ")
            }

            return cellView
        }
    }

    func tableView(_: NSTableView, heightOfRow _: Int) -> CGFloat {
        return 52
    }

    private func registerHotkeyForLayout(at index: Int) {
        guard index >= 0 && index < savedLayouts.count else { return }
        guard let hotkey = savedLayouts[index].hotkey else {
            // Unregister if no hotkey
            HotkeyManager.shared.unregisterHotkeyForLayout(at: index)
            return
        }

        HotkeyManager.shared.registerHotkey(hotkey, forLayoutIndex: index) { [weak self] in
            guard let self = self, index < self.savedLayouts.count else { return }
            DispatchQueue.main.async {
                self.applyLayoutAtIndex(at: index)
            }
        }
    }

    func applyLayoutAtIndex(at index: Int) {
        guard index >= 0 && index < savedLayouts.count else { return }
        let layout = savedLayouts[index]
        restoreLayout(layout)
    }

    func registerAllHotkeys() {
        // Unregister all first to avoid duplicates
        HotkeyManager.shared.unregisterAll()
        for (index, layout) in savedLayouts.enumerated() {
            if layout.hotkey != nil {
                registerHotkeyForLayout(at: index)
            }
        }
    }
}

