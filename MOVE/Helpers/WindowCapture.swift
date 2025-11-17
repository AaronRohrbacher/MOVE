import ApplicationServices
import Cocoa

enum WindowCapture {
    static func captureCurrentLayout() -> [WindowInfo] {
        var windows: [WindowInfo] = []
        let myPID = getpid()

        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
        }

        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        for windowDict in windowList {
            guard
                let pid = windowDict[kCGWindowOwnerPID as String] as? pid_t,
                pid != myPID,
                let windowNumber = windowDict[kCGWindowNumber as String] as? CGWindowID,
                let bounds = windowDict[kCGWindowBounds as String] as? [String: Any],
                let x = bounds["X"] as? CGFloat,
                let y = bounds["Y"] as? CGFloat,
                let width = bounds["Width"] as? CGFloat,
                let height = bounds["Height"] as? CGFloat,
                let ownerName = windowDict[kCGWindowOwnerName as String] as? String
            else { continue }

            let windowTitle = (windowDict[kCGWindowName as String] as? String) ?? ""
            let windowLayer = windowDict[kCGWindowLayer as String] as? Int ?? 0

            if windowLayer != 0 { continue }
            if width < 50 || height < 50 { continue }

            var bundleId = ""
            let runningApps = NSWorkspace.shared.runningApplications
            if let app = runningApps.first(where: { $0.processIdentifier == pid }) {
                bundleId = app.bundleIdentifier ?? ownerName
            } else {
                bundleId = ownerName
            }

            let isMinimized = windowDict[kCGWindowIsOnscreen as String] as? Bool == false
            let isHidden = windowDict[kCGWindowAlpha as String] as? CGFloat ?? 1.0 < 0.1
            let frame = CGRect(x: x, y: y, width: width, height: height)
            let displayTitle = windowTitle.isEmpty ? ownerName : windowTitle

            windows.append(WindowInfo(
                bundleIdentifier: bundleId,
                windowTitle: displayTitle,
                frame: frame,
                isMinimized: isMinimized,
                isHidden: isHidden,
                windowNumber: windowNumber
            ))
        }

        return windows
    }
}








