import CoreGraphics
import Foundation

struct WindowInfo: Codable {
    let bundleIdentifier: String
    let windowTitle: String
    let frame: CGRect
    let isMinimized: Bool
    let isHidden: Bool
    let windowNumber: CGWindowID
}

