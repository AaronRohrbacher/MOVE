import Cocoa

extension ViewController: NSTableViewDataSource {
    func numberOfRows(in _: NSTableView) -> Int {
        return savedLayouts.count
    }
}

extension ViewController: NSTableViewDelegate {
    func tableView(_: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        guard row < savedLayouts.count else { return nil }
        let layout = savedLayouts[row]

        let cellView = NSTableCellView()
        cellView.identifier = NSUserInterfaceItemIdentifier("LayoutCell")

        let textField = NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = NSFont.systemFont(ofSize: 13)
        textField.lineBreakMode = .byTruncatingTail
        cellView.addSubview(textField)
        cellView.textField = textField

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        let dateString = dateFormatter.string(from: layout.dateCreated)

        let iconIndicator = layout.includeDesktopIcons ? "🖥️ " : ""
        textField.stringValue = "\(iconIndicator)\(layout.name) - \(layout.windows.count) windows - \(dateString)"

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 5),
            textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -5),
            textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
        ])

        return cellView
    }

    func tableView(_: NSTableView, heightOfRow _: Int) -> CGFloat {
        return 48
    }
}

