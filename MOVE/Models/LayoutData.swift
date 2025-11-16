import CoreGraphics
import Foundation

struct LayoutData: Codable {
    let name: String
    let windows: [WindowInfo]
    let desktopIcons: [DesktopIconInfo]?
    let includeDesktopIcons: Bool
    let dateCreated: Date
}

