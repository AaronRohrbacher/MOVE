# Accessibility API Usage Justification

## Overview
MOVE (Macintosh Orchestrator of Visual Ease) requires Accessibility permissions to provide its core functionality of saving and restoring window layouts.

## Features Requiring Accessibility Access

### 1. Window Position and Size Control
**Feature:** The app allows users to save the current positions and sizes of all application windows, and later restore them to those exact positions.

**Technical Justification:**
- macOS does not provide a public API to programmatically move or resize windows belonging to other applications
- The Accessibility API (`AXUIElement`) is the only supported mechanism to:
  - Query window positions and sizes via `kAXPositionAttribute` and `kAXSizeAttribute`
  - Set window positions and sizes via `AXUIElementSetAttributeValue()`
  - Identify windows by title via `kAXTitleAttribute`
  - Access window lists via `kAXWindowsAttribute`

**Code Location:**
- `MOVE/ViewController.swift`: `setWindowFrame()`, `moveWindowByTitle()`, `moveFirstWindow()`
- `MOVE/Helpers/WindowRestore.swift`: Window restoration functionality

### 2. Window Discovery and Identification
**Feature:** The app needs to identify and match windows across application launches to restore them correctly.

**Technical Justification:**
- Window identification requires:
  - Access to window titles via `kAXTitleAttribute`
  - Access to application bundle identifiers
  - Ability to query all windows of an application via `kAXWindowsAttribute`
  - Access to main/focused window information via `kAXMainWindowAttribute` and `kAXFocusedWindowAttribute`

**Code Location:**
- `MOVE/ViewController.swift`: `captureCurrentLayout()`, `restoreWindow()`, `moveWindowByTitle()`

## Alternative Approaches Considered

1. **AppleScript/Apple Events:** 
   - Limited support for window positioning (only some applications support it)
   - Cannot reliably set window positions for all applications

2. **CGWindowList APIs:**
   - Can only read window information, cannot set positions

3. **Private APIs:**
   - Not allowed for App Store distribution
   - Would break with system updates

## Privacy and Security

- The app only accesses window position and size information
- No user content (file contents, text, etc.) is accessed
- All operations are performed locally on the user's machine
- The app requests permission explicitly and explains the purpose in `Info.plist` (`NSAccessibilityUsageDescription`)

## Conclusion

The Accessibility API is the only supported, public API available on macOS that allows:
1. Programmatic control of window positions and sizes
2. Reliable window identification across application launches

Without Accessibility permissions, the core functionality of MOVE cannot be implemented.

