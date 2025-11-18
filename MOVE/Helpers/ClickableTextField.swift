import Cocoa

class ClickableTextField: NSTextField {
    var onClick: (() -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setup()
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        isEditable = false
        isSelectable = false
        isBordered = false
        drawsBackground = true
        backgroundColor = NSColor.controlBackgroundColor
    }
    
    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
    
    override func mouseUp(with event: NSEvent) {
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        let pointInBounds = convert(point, from: superview)
        return bounds.contains(pointInBounds) ? self : super.hitTest(point)
    }
    
    override var acceptsFirstResponder: Bool {
        return false
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    override var mouseDownCanMoveWindow: Bool {
        return false
    }
}

