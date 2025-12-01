import Cocoa

@objc(GridController)
class GridController: NSViewController {
    var gridIconButtons: [NSButton] = []
    var rowSelectionButtons: [NSButton] = []
    var applyGridButton: NSButton!
    var additionalRowsStepper: NSStepper!
    var additionalRowsLabel: NSTextField!
    var totalWindows: Int = 12
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
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
        self.view.isHidden = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    func setupUIFromStoryboard() {
        for button in gridIconButtons {
            button.target = self
            button.action = #selector(gridIconClicked(_:))
            if !button.wantsLayer {
                button.wantsLayer = true
            }
            if button.layer?.cornerRadius == 0 {
                button.layer?.cornerRadius = 6
            }
            if button.layer?.borderWidth == 0 {
                button.layer?.borderWidth = 2
            }
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.imageHugsTitle = true
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
            if !button.wantsLayer {
                button.wantsLayer = true
            }
            if button.layer?.cornerRadius == 0 {
                button.layer?.cornerRadius = 4
            }
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
        
        setupUI()
        updateGridIcons()
    }
    
    func createGridIcon(windowCount: Int, size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.isTemplate = false
        image.lockFocusFlipped(true)
        defer { image.unlockFocus() }
        
        NSColor.controlBackgroundColor.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        let (rows, cols, rowPosition) = calculateGridLayoutForIcon(windowCount: windowCount)
        
        guard rows > 0 && cols > 0 else { return image }
        
        let padding: CGFloat = 3
        let gap: CGFloat = 2
        let availableWidth = size.width - (padding * 2)
        let availableHeight = size.height - (padding * 2)
        
        let cellSize: CGFloat
        let startY: CGFloat
        
        if rowPosition != .none {
            let maxSquareSize = min(availableWidth / CGFloat(cols) - gap, availableHeight - gap)
            cellSize = maxSquareSize
            let totalRowWidth = CGFloat(cols) * cellSize + CGFloat(max(0, cols - 1)) * gap
            let startX = padding + (availableWidth - totalRowWidth) / 2
            
            switch rowPosition {
            case .upper:
                startY = padding
            case .middle:
                startY = padding + (availableHeight - cellSize) / 2
            case .lower:
                startY = padding + availableHeight - cellSize
            default:
                startY = padding
            }
            
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
                
                NSColor.controlAccentColor.setFill()
                rect.fill()
                NSColor.separatorColor.setStroke()
                let path = NSBezierPath(rect: rect)
                path.lineWidth = 1.5
                path.stroke()
                
                windowIndex += 1
            }
        } else {
            let cellWidth = (availableWidth - gap * CGFloat(max(0, cols - 1))) / CGFloat(cols)
            let cellHeight = (availableHeight - gap * CGFloat(max(0, rows - 1))) / CGFloat(rows)
            
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
                
                NSColor.controlAccentColor.setFill()
                rect.fill()
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
        switch selectedRowPosition {
        case .upper, .middle, .lower:
            let cols = min(windowCount, 6)
            return (rows: 1, cols: cols, rowPosition: selectedRowPosition)
        case .none:
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
        for button in gridIconButtons {
            let wasSelected = button === sender
            button.state = wasSelected ? .on : .off
            
            if wasSelected {
                button.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.25).cgColor
                button.layer?.borderColor = NSColor.controlAccentColor.cgColor
            } else {
                button.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
                button.layer?.borderColor = NSColor.separatorColor.cgColor
            }
        }
        
        totalWindows = sender.tag
        updateGridIcons()
    }
    
    private func updateGridIcons() {
        for button in gridIconButtons {
            let windowCount = button.tag
            let iconSize: CGFloat = 55
            let imageSize = NSSize(width: iconSize - 8, height: iconSize - 8)
            let gridImage = createGridIcon(windowCount: windowCount, size: imageSize)
            gridImage.size = imageSize
            button.image = gridImage
            button.imageScaling = .scaleProportionallyDown
            button.needsDisplay = true
        }
    }
    
    private func setupUI() {
        if let stepper = additionalRowsStepper {
            stepper.minValue = 0
            stepper.maxValue = 4
            stepper.increment = 1
            stepper.intValue = 0
        }
        updateAdditionalRowsLabel()
        
        totalWindows = 12
        selectedRowPosition = .none
        updateGridIcons()
    }
    
    @objc func rowButtonClicked(_ sender: NSButton) {
        for button in rowSelectionButtons {
            let wasSelected = button === sender
            button.state = wasSelected ? .on : .off
            
            if wasSelected {
                button.contentTintColor = NSColor.controlAccentColor
                button.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
            } else {
                button.contentTintColor = nil
                button.layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
        
        if let position = RowPosition(rawValue: sender.title) {
            selectedRowPosition = position
            updateGridIcons()
        }
    }
    
    private func calculateGridLayout() -> (rows: Int, cols: Int) {
        switch selectedRowPosition {
        case .upper, .middle, .lower:
            return (rows: 1, cols: min(totalWindows, 6))
        case .none:
            let baseRows: Int
            switch totalWindows {
            case 4:
                baseRows = 2
            case 8:
                baseRows = 2
            case 12:
                baseRows = 3
            default:
                baseRows = Int(sqrt(Double(totalWindows)).rounded(.up))
            }
            
            let totalRows = baseRows + additionalRows
            let cols = Int(ceil(Double(totalWindows) / Double(totalRows)))
            return (rows: totalRows, cols: max(1, cols))
        }
    }
    
    @objc func additionalRowsChanged(_ sender: NSStepper) {
        additionalRows = Int(sender.intValue)
        updateAdditionalRowsLabel()
        updateGridIcons()
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
        guard let mainVC = mainViewController else { return }
        
        let windows = mainVC.captureCurrentLayout()
        guard !windows.isEmpty else { return }
        
        let gridFrames = calculateGridFrames(windowCount: windows.count)
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
        
        let gridLayout = LayoutData(
            name: "Grid Layout",
            windows: gridWindows,
            dateCreated: Date()
        )
        
        mainVC.restoreLayout(gridLayout)
    }
    
    func calculateGridFrames(windowCount: Int) -> [CGRect] {
        guard let screen = NSScreen.main else { return [] }
        let screenFrame = screen.visibleFrame
        let screenWidth = screenFrame.width
        let screenHeight = screenFrame.height
        
        let actualWindowCount = min(windowCount, totalWindows)
        guard actualWindowCount > 0 else { return [] }
        
        let (rows, cols) = calculateGridLayout()
        
        if selectedRowPosition != .none {
            let columnWidth = screenWidth / CGFloat(actualWindowCount)
            let rowHeight = screenHeight / 3.0
            
            let y: CGFloat
            switch selectedRowPosition {
            case .upper:
                y = screenFrame.origin.y
            case .middle:
                y = screenFrame.origin.y + (screenHeight - rowHeight) / 2.0
            case .lower:
                y = screenFrame.origin.y + screenHeight - rowHeight
            case .none:
                y = screenFrame.origin.y
            }
            
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
        
        let totalRows = rows
        let rowHeight = screenHeight / CGFloat(totalRows)
        let columnWidth = screenWidth / CGFloat(cols)
        
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
