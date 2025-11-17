import Cocoa

class LayoutTableCellView: NSTableCellView {
    @IBOutlet weak var titleField: NSTextField!
    @IBOutlet weak var infoField: NSTextField!
    @IBOutlet weak var hotkeyField: NSTextField!
    
    var hotkeyClickHandler: (() -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupHotkeyField()
    }
    
    private func setupHotkeyField() {
        guard let hotkeyField = hotkeyField else { return }
        
        hotkeyField.isEditable = false
        hotkeyField.isSelectable = false
        hotkeyField.alignment = .right
        hotkeyField.font = NSFont.systemFont(ofSize: 11)
        hotkeyField.wantsLayer = true
        hotkeyField.layer?.cornerRadius = 4
        hotkeyField.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        // Make clickable
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(hotkeyFieldClicked))
        hotkeyField.addGestureRecognizer(clickGesture)
    }
    
    @objc private func hotkeyFieldClicked() {
        hotkeyClickHandler?()
    }
    
    func configure(with layout: LayoutData, row: Int) {
        let iconIndicator = layout.includeDesktopIcons ? "🖥️ " : ""
        let windowCount = layout.windows.count
        let iconCount = layout.desktopIcons?.count ?? 0
        
        titleField?.stringValue = "\(iconIndicator)\(layout.name)"
        
        var infoParts: [String] = []
        infoParts.append("\(windowCount) window\(windowCount == 1 ? "" : "s")")
        if iconCount > 0 {
            infoParts.append("\(iconCount) icon\(iconCount == 1 ? "" : "s")")
        }
        infoField?.stringValue = infoParts.joined(separator: ", ")
        
        hotkeyField?.stringValue = layout.hotkey?.keyString ?? "Click to set hotkey"
        hotkeyField?.textColor = layout.hotkey != nil ? .controlAccentColor : .secondaryLabelColor
        hotkeyField?.tag = row
    }
}

