import Cocoa

class LayoutTableCellView: NSTableCellView {
    static let titleFieldTag = 9001
    static let infoFieldTag = 9002

    @IBOutlet weak var titleField: NSTextField? {
        didSet { textField = titleField }
    }
    @IBOutlet weak var infoField: NSTextField?

    override func awakeFromNib() {
        super.awakeFromNib()
        resolveFallbackOutlets()
    }

    func configure(title: String, info: String) {
        resolveFallbackOutlets()
        titleField?.stringValue = title
        infoField?.stringValue = info
    }

    private func resolveFallbackOutlets() {
        if titleField == nil {
            titleField = viewWithTag(Self.titleFieldTag) as? NSTextField
            if textField == nil {
                textField = titleField
            }
        }
        if infoField == nil {
            infoField = viewWithTag(Self.infoFieldTag) as? NSTextField
        }
    }
}

