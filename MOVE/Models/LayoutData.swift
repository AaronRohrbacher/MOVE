import CoreGraphics
import Foundation

struct LayoutData: Codable {
    let name: String
    let windows: [WindowInfo]
    let dateCreated: Date
    var hotkey: HotkeyData?
}

struct HotkeyData: Codable {
    let keyCode: UInt16
    let modifiers: UInt
    let keyString: String
}








