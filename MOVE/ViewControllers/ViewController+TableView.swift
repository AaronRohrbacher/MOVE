import Cocoa


extension ViewController: NSTableViewDataSource {
    func numberOfRows(in _: NSTableView) -> Int {
        return savedLayouts.count
    }
}

extension ViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < savedLayouts.count else { return nil }
        let layout = savedLayouts[row]

        if tableColumn?.identifier.rawValue == "layoutName" {
            if let cellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("LayoutCell"), owner: self) as? LayoutTableCellView {
                let windowCount = layout.windows.count

                cellView.configure(
                    title: layout.name,
                    info: "\(windowCount) window\(windowCount == 1 ? "" : "s")"
                )

                return cellView
            }

            let cellView = NSTableCellView()
            cellView.identifier = NSUserInterfaceItemIdentifier("LayoutCell")

            let titleField = NSTextField(labelWithString: "")
            titleField.translatesAutoresizingMaskIntoConstraints = false
            titleField.font = NSFont.systemFont(ofSize: 13)
            titleField.lineBreakMode = .byTruncatingTail
            cellView.addSubview(titleField)
            cellView.textField = titleField

            let infoField = NSTextField(labelWithString: "")
            infoField.translatesAutoresizingMaskIntoConstraints = false
            infoField.font = NSFont.systemFont(ofSize: 10)
            infoField.textColor = NSColor.secondaryLabelColor
            infoField.lineBreakMode = .byTruncatingTail
            cellView.addSubview(infoField)

            NSLayoutConstraint.activate([
                titleField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 5),
                titleField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -5),
                titleField.topAnchor.constraint(equalTo: cellView.topAnchor, constant: 6),

                infoField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 5),
                infoField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -5),
                infoField.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 2),
                infoField.bottomAnchor.constraint(lessThanOrEqualTo: cellView.bottomAnchor, constant: -6)
            ])

            let windowCount = layout.windows.count

            titleField.stringValue = layout.name
            infoField.stringValue = "\(windowCount) window\(windowCount == 1 ? "" : "s")"

            return cellView
        } else if tableColumn?.identifier.rawValue == "hotkey" {
            if let cellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("HotkeyButton"), owner: self) as? HotkeyTableCellView,
               cellView.hotkeyButton != nil {
                let defaultText = (tableColumn?.dataCell as? NSTextFieldCell)?.title ?? "Click to set hotkey"
                cellView.configure(
                    with: layout.hotkey?.keyString,
                    defaultText: defaultText,
                    row: row,
                    target: self,
                    action: #selector(hotkeyButtonClicked(_:))
                )
                return cellView
            } else {
                let button = NSButton()
                button.identifier = NSUserInterfaceItemIdentifier("HotkeyButton")

                if let template = hotkeyButtonTemplate {
                    button.bezelStyle = template.bezelStyle
                    button.isBordered = template.isBordered
                    button.font = template.font
                    button.alignment = template.alignment
                    button.wantsLayer = template.wantsLayer
                    if let templateLayer = template.layer {
                        button.layer?.cornerRadius = templateLayer.cornerRadius
                        button.layer?.backgroundColor = templateLayer.backgroundColor
                        button.layer?.borderWidth = templateLayer.borderWidth
                        button.layer?.borderColor = templateLayer.borderColor
                    }
                } else {
                    button.bezelStyle = .rounded
                    button.isBordered = false
                    button.font = NSFont.systemFont(ofSize: 11)
                    button.alignment = .center
                    button.wantsLayer = true
                    button.layer?.cornerRadius = 3
                    button.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
                    button.layer?.borderWidth = 1.0
                    button.layer?.borderColor = NSColor.separatorColor.cgColor
                }

                button.target = self
                button.action = #selector(hotkeyButtonClicked(_:))
                button.tag = row
                let defaultText = hotkeyButtonTemplate?.title ?? (tableColumn?.dataCell as? NSTextFieldCell)?.title ?? "Click to set hotkey"
                let hotkeyText = layout.hotkey?.keyString ?? defaultText
                button.title = hotkeyText
                button.contentTintColor = layout.hotkey != nil ? .controlAccentColor : .secondaryLabelColor
                return button
            }
        }

        return nil
    }

    func tableView(_: NSTableView, heightOfRow _: Int) -> CGFloat {
        return 52
    }

    private func registerHotkeyForLayout(at index: Int) {
        guard index >= 0 && index < savedLayouts.count else { return }
        guard let hotkey = savedLayouts[index].hotkey else {
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
        HotkeyManager.shared.unregisterAll()
        for (index, layout) in savedLayouts.enumerated() {
            if layout.hotkey != nil {
                registerHotkeyForLayout(at: index)
            }
        }
    }
}

