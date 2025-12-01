# App Store Review Fixes Summary

This document summarizes the fixes made to address the three issues raised by Apple during App Store review.

## Issue 1: Entitlements Errors ✅ FIXED

### Problem:
- `com.apple.security.application-groups`: Value must be string, or array or dictionary of strings, but contains value "[]"
- `com.apple.security.temporary-exception.apple-events`: Value must be string, or array or dictionary of strings, but contains value "True"

### Solution:
- **Removed** the empty `application-groups` array (not needed for this app)
- **Changed** `apple-events` from boolean `true` to an array of strings: `["com.apple.finder"]`
  - This is correct because the app uses Apple Events to communicate with Finder for desktop icon management

### Files Changed:
- `MOVE/MOVE.entitlements`
- `MOVE/MoveRelease.entitlements`

## Issue 2: Window Menu Missing ✅ FIXED

### Problem:
When the user closes the main application window, there is no menu item to re-open it. Apple requires either:
- A Window menu that lists the main window, OR
- The app should quit when the main window is closed (for single-window apps)

### Solution:
Implemented a Window menu that:
- Lists all visible windows in the app
- Allows users to reopen closed windows via the menu
- Updates dynamically when windows are shown/hidden/closed
- Provides keyboard shortcuts (⌘1, ⌘2, etc.) for quick access

### Implementation Details:
- Added `NSWindowDelegate` conformance to `AppDelegate`
- Implemented `updateWindowMenu()` to dynamically populate the Window menu
- Added notification observers for window state changes
- Menu items are added after system items (Minimize, Zoom, Bring All to Front)

### Files Changed:
- `MOVE/AppDelegate.swift`

## Issue 3: Accessibility API Justification ✅ DOCUMENTED

### Problem:
Apple requires an explanation of:
- What feature requires Accessibility access
- Technical justification for using Accessibility API

### Solution:
Created comprehensive documentation explaining:
1. **Window Position Control**: The app uses Accessibility API to move and resize windows because macOS doesn't provide a public API for this
2. **Desktop Icon Management**: The app uses Accessibility API to read/set desktop icon positions because there's no public API for this
3. **Window Discovery**: The app uses Accessibility API to identify and match windows across launches

### Documentation Created:
- `ACCESSIBILITY_JUSTIFICATION.md` - Detailed technical justification

### For App Store Review Response:
When responding to Apple's review, you can use the following:

**Question:** What feature in your app requires Accessibility access, and what is the technical justification for it?

**Answer:**
MOVE requires Accessibility permissions for two core features:

1. **Window Position and Size Control**: The app saves and restores window positions/sizes. macOS does not provide a public API to programmatically move or resize windows belonging to other applications. The Accessibility API (`AXUIElement`) is the only supported mechanism to query and set window positions via `kAXPositionAttribute` and `kAXSizeAttribute`.

2. **Desktop Icon Position Management**: The app can save and restore desktop icon positions. macOS does not provide a public API for this. The Accessibility API is used to traverse Finder's accessibility hierarchy to locate and position desktop icon elements.

Alternative approaches (AppleScript, CGWindowList APIs) are either unreliable or read-only. The Accessibility API is the only supported, public API that enables these features.

See `ACCESSIBILITY_JUSTIFICATION.md` for complete technical details.

## Testing Recommendations

Before resubmitting, test:

1. **Entitlements**: Verify the app builds and runs correctly
2. **Window Menu**: 
   - Close the main window
   - Verify it appears in the Window menu
   - Click the menu item to reopen it
   - Verify keyboard shortcuts work (⌘1)
3. **Accessibility**: 
   - Test window layout save/restore
   - Test desktop icon position save/restore (if applicable)

## Next Steps

1. Build and test the app locally
2. Archive and submit to App Store
3. In the review notes, reference the fixes made:
   - Entitlements corrected
   - Window menu implemented
   - Accessibility justification provided (see `ACCESSIBILITY_JUSTIFICATION.md`)

