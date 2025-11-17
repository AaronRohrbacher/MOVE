//
//  GridController.swift
//  MOVE
//
//  Created by Aaron Rohrbacher on 11/16/25.
//

import Cocoa

@objc(GridController)
class GridController: NSViewController {
    
    // MARK: - UI Elements
    var gridIconButtons: [NSButton] = []
    var rowSelectionButtons: [NSButton] = []
    var applyGridButton: NSButton!
    var additionalRowsStepper: NSStepper!
    var additionalRowsLabel: NSTextField!
    
    // MARK: - Properties
    var totalWindows: Int = 12  // Total windows to arrange (1-12)
    var selectedRowPosition: RowPosition = .none
    var additionalRows: Int = 0
    weak var mainViewController: ViewController?
    
    enum RowPosition: String, CaseIterable {
        case upper = "Upper"
        case lower = "Lower"
        case middle = "Middle"
        case none = "None"
    }
    
    override func loadView() {
        // If UI elements are provided from storyboard, we don't need our own view
        // Create a minimal view that won't be used
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
        self.view.isHidden = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // UI should come from storyboard - no programmatic creation
        setupUI()
    }
    
    func setupUIFromStoryboard() {
        // Setup actions for storyboard elements
        for button in gridIconButtons {
            button.target = self
            button.action = #selector(gridIconClicked(_:))
            button.wantsLayer = true
            button.layer?.cornerRadius = 6
            button.layer?.borderWidth = 2
            // Ensure images display properly and don't resize button
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown  // Only scale down, never up
            button.imageHugsTitle = true
            button.title = ""
            button.alternateTitle = ""
            if button.tag == 12 {
                button.state = .on
                button.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.25).cgColor
                button.layer?.borderColor = NSColor.controlAccentColor.cgColor
            } else {
                button.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
                button.layer?.borderColor = NSColor.separatorColor.cgColor
            }
        }
        
        for button in rowSelectionButtons {
            button.target = self
            button.action = #selector(rowButtonClicked(_:))
            button.wantsLayer = true
            button.layer?.cornerRadius = 4
            if button.title == "None" {
                button.state = .on
                button.contentTintColor = NSColor.controlAccentColor
                button.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
            } else {
                button.layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
        
        if let stepper = additionalRowsStepper {
            stepper.target = self
            stepper.action = #selector(additionalRowsChanged(_:))
        }
        
        if let button = applyGridButton {
            button.target = self
            button.action = #selector(applyGrid(_:))
        }
        
        // Setup UI state and initialize grid icons
        setupUI()
        updateGridIcons()
    }
    
    // UI creation removed - all UI should come from storyboard
    // Connect outlets in Interface Builder to enable editing in Xcode
    
    func createGridIcon(windowCount: Int, size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.isTemplate = false
        
        // Use flipped coordinate system for easier top-to-bottom drawing
        image.lockFocusFlipped(true)
        defer { image.unlockFocus() }
        
        // Fill background with system color that adapts to dark mode
        NSColor.controlBackgroundColor.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Calculate grid layout for icon - show layout based on current selection
        let (rows, cols, rowPosition) = calculateGridLayoutForIcon(windowCount: windowCount)
        
        guard rows > 0 && cols > 0 else {
            return image
        }
        
        // Calculate cell dimensions with padding
        let padding: CGFloat = 3
        let gap: CGFloat = 2
        let availableWidth = size.width - (padding * 2)
        let availableHeight = size.height - (padding * 2)
        
        // For Upper/Middle/Lower: make squares, positioned at top/middle/bottom
        // For None: use full grid
        let cellSize: CGFloat
        let startY: CGFloat
        
        if rowPosition != .none {
            // Make squares - use the smaller dimension to ensure squares fit
            let maxSquareSize = min(availableWidth / CGFloat(cols) - gap, availableHeight - gap)
            cellSize = maxSquareSize
            let totalRowWidth = CGFloat(cols) * cellSize + CGFloat(max(0, cols - 1)) * gap
            let startX = padding + (availableWidth - totalRowWidth) / 2 // Center horizontally
            
            // Position at top, middle, or bottom
            switch rowPosition {
            case .upper:
                startY = padding // Top of icon (flipped coordinates)
            case .middle:
                startY = padding + (availableHeight - cellSize) / 2 // Middle
            case .lower:
                startY = padding + availableHeight - cellSize // Bottom of icon
            default:
                startY = padding
            }
            
            // Draw squares
            var windowIndex = 0
            for col in 0..<cols {
                if windowIndex >= windowCount { break }
                
                let x = startX + CGFloat(col) * (cellSize + gap)
                
                let rect = NSRect(
                    x: x,
                    y: startY,
                    width: cellSize,
                    height: cellSize
                )
                
                // Draw cell with system blue that adapts to dark mode
                NSColor.controlAccentColor.setFill()
                rect.fill()
                
                // Draw border with system color that adapts to dark mode
                NSColor.separatorColor.setStroke()
                let path = NSBezierPath(rect: rect)
                path.lineWidth = 1.5
                path.stroke()
                
                windowIndex += 1
            }
        } else {
            // None selected: use full grid layout
            let cellWidth = (availableWidth - gap * CGFloat(max(0, cols - 1))) / CGFloat(cols)
            let cellHeight = (availableHeight - gap * CGFloat(max(0, rows - 1))) / CGFloat(rows)
            
            // Draw grid cells - show ALL windows
            // With flipped coordinates, row 0 is at top, increasing downward
            var windowIndex = 0
            for row in 0..<rows {
                for col in 0..<cols {
                    if windowIndex >= windowCount { break }
                    
                    let x = padding + CGFloat(col) * (cellWidth + gap)
                    let y = padding + CGFloat(row) * (cellHeight + gap)
                    
                    let rect = NSRect(
                        x: x,
                        y: y,
                        width: cellWidth,
                        height: cellHeight
                    )
                    
                    // Draw cell with system blue that adapts to dark mode
                    NSColor.controlAccentColor.setFill()
                    rect.fill()
                    
                    // Draw border with system color that adapts to dark mode
                    NSColor.separatorColor.setStroke()
                    let path = NSBezierPath(rect: rect)
                    path.lineWidth = 1.5
                    path.stroke()
                    
                    windowIndex += 1
                }
                if windowIndex >= windowCount { break }
            }
        }
        
        return image
    }
    
    private func calculateGridLayoutForIcon(windowCount: Int) -> (rows: Int, cols: Int, rowPosition: RowPosition) {
        // Show layout based on selected row position and additional rows
        switch selectedRowPosition {
        case .upper, .middle, .lower:
            // For Upper/Middle/Lower: show squares in a row, positioned at top/middle/bottom
            // Cap at reasonable number for visibility (max 6 squares)
            let cols = min(windowCount, 6)
            return (rows: 1, cols: cols, rowPosition: selectedRowPosition)
        case .none:
            // Multiple rows based on window count and additional rows
            let baseRows: Int
            switch windowCount {
            case 4:
                baseRows = 2
            case 8:
                baseRows = 2
            case 12:
                baseRows = 3
            default:
                baseRows = Int(sqrt(Double(windowCount)).rounded(.up))
            }
            
            let totalRows = baseRows + additionalRows
            let cols = Int(ceil(Double(windowCount) / Double(totalRows)))
            return (rows: totalRows, cols: max(1, cols), rowPosition: .none)
        }
    }
    
    @objc func gridIconClicked(_ sender: NSButton) {
        // Update selected icon
        for button in gridIconButtons {
            let wasSelected = button === sender
            button.state = wasSelected ? .on : .off
            
            // Update visual selection state
            if wasSelected {
                button.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.25).cgColor
                button.layer?.borderColor = NSColor.controlAccentColor.cgColor
            } else {
                button.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
                button.layer?.borderColor = NSColor.separatorColor.cgColor
            }
        }
        
        // Update total windows
        totalWindows = sender.tag
        
        // Update icons to reflect current selection
        updateGridIcons()
    }
    
    private func updateGridIcons() {
        // Update all icons to reflect current row selection and additional rows
        for button in gridIconButtons {
            let windowCount = button.tag
            let iconSize: CGFloat = 55
            let imageSize = NSSize(width: iconSize - 8, height: iconSize - 8)
            let gridImage = createGridIcon(windowCount: windowCount, size: imageSize)
            gridImage.size = imageSize
            button.image = gridImage
            button.imageScaling = .scaleProportionallyDown  // Only scale down, never up
            button.needsDisplay = true
        }
    }
    
    private func setupUI() {
        // Setup additional rows stepper
        if let stepper = additionalRowsStepper {
            stepper.minValue = 0
            stepper.maxValue = 4
            stepper.increment = 1
            stepper.intValue = 0
        }
        updateAdditionalRowsLabel()
        
        // Default to 12 windows, None (3 rows)
        totalWindows = 12
        selectedRowPosition = .none
        
        // Ensure icons are updated with current state
        updateGridIcons()
    }
    
    @objc func rowButtonClicked(_ sender: NSButton) {
        // Toggle button state with visual feedback
        for button in rowSelectionButtons {
            let wasSelected = button === sender
            button.state = wasSelected ? .on : .off
            
            // Update visual selection state with better styling
            if wasSelected {
                button.contentTintColor = NSColor.controlAccentColor
                button.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
            } else {
                button.contentTintColor = nil
                button.layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
        
        // Update selected position
        let title = sender.title
        if let position = RowPosition(rawValue: title) {
            selectedRowPosition = position
            updateGridIcons() // Update icons to reflect row selection
        }
    }
    
    private func calculateGridLayout() -> (rows: Int, cols: Int) {
        // If upper/middle/lower selected: 1 row, 4 windows per row
        // If none selected: 3 rows (default for 12 windows), 4 per row
        // Additional rows adds more rows when none is selected
        
        switch selectedRowPosition {
        case .upper, .middle, .lower:
            // 1 row, 4 windows per row
            return (rows: 1, cols: min(4, totalWindows))
        case .none:
            // Default: 3 rows for 12 windows (4 per row)
            // With additional rows: 3 + additionalRows
            let totalRows = 3 + additionalRows
            let windowsPerRow = max(1, totalWindows / totalRows)
            return (rows: totalRows, cols: windowsPerRow)
        }
    }
    
    @objc func additionalRowsChanged(_ sender: NSStepper) {
        additionalRows = Int(sender.intValue)
        updateAdditionalRowsLabel()
        updateGridIcons() // Update icons to reflect additional rows
    }
    
    private func updateAdditionalRowsLabel() {
        guard let label = additionalRowsLabel else { return }
        if additionalRows == 0 {
            label.stringValue = "No additional rows"
        } else {
            label.stringValue = "\(additionalRows) additional row\(additionalRows == 1 ? "" : "s")"
        }
    }
    
    
    @objc func applyGrid(_ sender: NSButton) {
        guard let mainVC = mainViewController else {
            // Silently fail - should not happen if properly initialized
            return
        }
        
        // Capture current windows using existing method
        let windows = mainVC.captureCurrentLayout()
        guard !windows.isEmpty else {
            // Silently fail - no windows to arrange
            return
        }
        
        // Calculate grid positions
        let gridFrames = calculateGridFrames(windowCount: windows.count)
        
        // Create WindowInfo objects with grid positions
        var gridWindows: [WindowInfo] = []
        for (index, window) in windows.enumerated() {
            if index < gridFrames.count {
                let gridWindow = WindowInfo(
                    bundleIdentifier: window.bundleIdentifier,
                    windowTitle: window.windowTitle,
                    frame: gridFrames[index],
                    isMinimized: false,
                    isHidden: false,
                    windowNumber: window.windowNumber
                )
                gridWindows.append(gridWindow)
            }
        }
        
        // Create a temporary layout and use existing restore
        let gridLayout = LayoutData(
            name: "Grid Layout",
            windows: gridWindows,
            desktopIcons: nil,
            includeDesktopIcons: false,
            dateCreated: Date()
        )
        
        // Use existing restore functionality
        mainVC.restoreLayout(gridLayout)
    }
    
    // MARK: - Grid Calculation
    func calculateGridFrames(windowCount: Int) -> [CGRect] {
        guard let screen = NSScreen.main else { return [] }
        let screenFrame = screen.visibleFrame
        let screenWidth = screenFrame.width
        let screenHeight = screenFrame.height
        
        // Use actual window count, but limit to totalWindows
        let actualWindowCount = min(windowCount, totalWindows)
        guard actualWindowCount > 0 else { return [] }
        
        // Calculate grid layout
        let (rows, cols) = calculateGridLayout()
        
        // For upper/middle/lower: single row, windows side by side
        if selectedRowPosition != .none {
            // Divide screen width by actual window count for side-by-side placement
            let columnWidth = screenWidth / CGFloat(actualWindowCount)
            // Use a reasonable row height (1/3 of screen)
            let rowHeight = screenHeight / 3.0
            
            // Calculate Y position based on row selection
            // macOS coordinate system: origin is bottom-left, Y increases upward
            let y: CGFloat
            switch selectedRowPosition {
            case .upper:
                // Upper: at bottom of screen (origin.y) - user says this should be "upper"
                y = screenFrame.origin.y
            case .middle:
                // Middle: vertically centered in screen
                y = screenFrame.origin.y + (screenHeight - rowHeight) / 2.0
            case .lower:
                // Lower: at top of screen (origin.y + height - rowHeight) - user says this should be "lower"
                y = screenFrame.origin.y + screenHeight - rowHeight
            case .none:
                y = screenFrame.origin.y // Shouldn't reach here
            }
            
            // Generate frames side by side, no overlapping, touching edges
            var frames: [CGRect] = []
            for i in 0..<actualWindowCount {
                let x = screenFrame.origin.x + CGFloat(i) * columnWidth
                let frame = CGRect(
                    x: x,
                    y: y,
                    width: columnWidth,
                    height: rowHeight
                )
                frames.append(frame)
            }
            return frames
        }
        
        // For .none: multiple rows
        let totalRows = rows
        let rowHeight = screenHeight / CGFloat(totalRows)
        let columnWidth = screenWidth / CGFloat(cols)
        
        // Generate frames - ensure no overlapping, side by side
        var frames: [CGRect] = []
        var windowIndex = 0
        
        for rowIndex in 0..<totalRows {
            let y = screenFrame.origin.y + CGFloat(totalRows - 1 - rowIndex) * rowHeight
            
            for colIndex in 0..<cols {
                if windowIndex >= actualWindowCount { break }
                
                let x = screenFrame.origin.x + CGFloat(colIndex) * columnWidth
                let frame = CGRect(
                    x: x,
                    y: y,
                    width: columnWidth,
                    height: rowHeight
                )
                frames.append(frame)
                windowIndex += 1
            }
            if windowIndex >= actualWindowCount { break }
        }
        
        return frames
    }
    
}
