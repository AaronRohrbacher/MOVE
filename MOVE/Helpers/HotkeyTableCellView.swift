import Cocoa

class HotkeyTableCellView: NSTableCellView {
    @IBOutlet weak var hotkeyTextField: NSTextField!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // The textField outlet should be connected from storyboard
    }
}

