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
        // Call the onClick handler immediately
        onClick?()
        // Don't call super to prevent default text field behavior
    }
    
    override func mouseUp(with event: NSEvent) {
        // Don't call super to prevent default behavior
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Ensure we can receive clicks - return self if point is in bounds
        let pointInBounds = convert(point, from: superview)
        return bounds.contains(pointInBounds) ? self : super.hitTest(point)
    }
    
    override var acceptsFirstResponder: Bool {
        return false // We don't need to be first responder, just handle clicks
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    override var mouseDownCanMoveWindow: Bool {
        return false
    }
}

