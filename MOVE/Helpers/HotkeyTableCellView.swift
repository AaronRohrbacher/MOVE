import Cocoa

class HotkeyTableCellView: NSTableCellView {
    @IBOutlet weak var hotkeyButton: NSButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupButton()
    }
    
    private func setupButton() {
        guard let button = hotkeyButton else { return }
        button.bezelStyle = .rounded
        button.isBordered = false
        button.alignment = .center
        button.wantsLayer = true
        button.layer?.cornerRadius = 3
        button.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        button.layer?.borderWidth = 1.0
        button.layer?.borderColor = NSColor.separatorColor.cgColor
        button.font = NSFont.systemFont(ofSize: 11)
    }
    
    func configure(with hotkeyText: String?, defaultText: String, row: Int, target: AnyObject?, action: Selector?) {
        let text = hotkeyText ?? defaultText
        hotkeyButton?.title = text
        hotkeyButton?.contentTintColor = hotkeyText != nil ? .controlAccentColor : .secondaryLabelColor
        hotkeyButton?.tag = row
        if let target = target, let action = action {
            hotkeyButton?.target = target
            hotkeyButton?.action = action
        }
    }
}


