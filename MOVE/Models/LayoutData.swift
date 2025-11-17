import CoreGraphics
import Foundation

struct LayoutData: Codable {
    let name: String
    let windows: [WindowInfo]
    let desktopIcons: [DesktopIconInfo]?
    let includeDesktopIcons: Bool
    let dateCreated: Date
    var hotkey: HotkeyData?
}

struct HotkeyData: Codable {
    let keyCode: UInt16
    let modifiers: UInt
    let keyString: String // Human-readable string like "⌘⇧1"
}








