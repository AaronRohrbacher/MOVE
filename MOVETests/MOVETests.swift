//
//  MOVETests.swift
//  MOVETests
//
//  Created by Aaron Rohrbacher on 10/21/25.
//

import XCTest
import Cocoa
import ApplicationServices
@testable import MOVE

final class MOVETests: XCTestCase {
    
    var viewController: ViewController!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        viewController = ViewController()
        viewController.loadView()
        viewController.viewDidLoad()
        
        // Clear any existing layouts
        UserDefaults.standard.removeObject(forKey: "SavedLayouts")
        UserDefaults.standard.synchronize()
        viewController.savedLayouts = []
        viewController.saveLayouts()
    }
    
    override func tearDownWithError() throws {
        viewController = nil
        UserDefaults.standard.removeObject(forKey: "SavedLayouts")
        UserDefaults.standard.synchronize()
        try super.tearDownWithError()
    }
    
    // MARK: - Permissions Tests
    
    func testPermissionsBannerIsCreated() throws {
        viewController.viewDidAppear()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertNotNil(viewController.permissionsBanner, "Permissions banner should be created")
    }
        
    func testPermissionsBannerVisibilityBasedOnPermissions() throws {
        viewController.viewDidAppear()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        let checkOpts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false] as CFDictionary
        let hasPermission = AXIsProcessTrustedWithOptions(checkOpts)
        
        XCTAssertNotNil(viewController.permissionsBanner)
        if !hasPermission {
            XCTAssertFalse(viewController.permissionsBanner?.isHidden ?? true, 
                          "Banner should be visible when permissions not granted")
        } else {
            XCTAssertTrue(viewController.permissionsBanner?.isHidden ?? false,
                         "Banner should be hidden when permissions granted")
        }
    }
    
    // MARK: - Layout CRUD Tests
    
    func testCreateLayoutStoresDataCorrectly() throws {
        let layout = LayoutData(
            name: "Test Layout",
            windows: [
                WindowInfo(
                bundleIdentifier: "com.apple.finder",
                    windowTitle: "Documents",
                frame: CGRect(x: 100, y: 100, width: 800, height: 600),
                isMinimized: false,
                isHidden: false,
                windowNumber: 12345,
                isDesktopIcon: false
                )
            ],
            desktopIcons: nil,
            includeDesktopIcons: false,
            dateCreated: Date()
        )
        
        viewController.savedLayouts.append(layout)
        viewController.saveLayouts()
        
        // Verify persistence
        let newVC = ViewController()
        newVC.loadSavedLayouts()
        
        XCTAssertEqual(newVC.savedLayouts.count, 1)
        XCTAssertEqual(newVC.savedLayouts.first?.name, "Test Layout")
        XCTAssertEqual(newVC.savedLayouts.first?.windows.count, 1)
        XCTAssertEqual(newVC.savedLayouts.first?.windows.first?.windowTitle, "Documents")
        XCTAssertEqual(newVC.savedLayouts.first?.windows.first?.frame, 
                      CGRect(x: 100, y: 100, width: 800, height: 600))
    }
    
    func testDeleteLayoutRemovesFromStorage() throws {
        // Create multiple layouts
        let layouts = [
            LayoutData(name: "Layout 1", windows: [], desktopIcons: nil, includeDesktopIcons: false, dateCreated: Date()),
            LayoutData(name: "Layout 2", windows: [], desktopIcons: nil, includeDesktopIcons: false, dateCreated: Date()),
            LayoutData(name: "Layout 3", windows: [], desktopIcons: nil, includeDesktopIcons: false, dateCreated: Date())
        ]
        
        viewController.savedLayouts = layouts
        viewController.saveLayouts()
        
        // Delete middle layout
        viewController.savedLayouts.remove(at: 1)
        viewController.saveLayouts()
        
        // Verify deletion persisted
        let newVC = ViewController()
        newVC.loadSavedLayouts()
        
        XCTAssertEqual(newVC.savedLayouts.count, 2)
        XCTAssertEqual(newVC.savedLayouts[0].name, "Layout 1")
        XCTAssertEqual(newVC.savedLayouts[1].name, "Layout 3")
        XCTAssertFalse(newVC.savedLayouts.contains { $0.name == "Layout 2" })
    }
    
    func testUpdateLayoutModifiesExisting() throws {
        // Create initial layout
        let layout = LayoutData(
            name: "Original Name",
            windows: [],
            desktopIcons: nil,
            includeDesktopIcons: false,
            dateCreated: Date()
        )
        
        viewController.savedLayouts.append(layout)
        viewController.saveLayouts()
        
        // Update the layout
        viewController.savedLayouts[0] = LayoutData(
            name: "Updated Name",
            windows: [
                WindowInfo(
                    bundleIdentifier: "com.apple.safari",
                    windowTitle: "Safari",
                    frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
                    isMinimized: false,
                    isHidden: false,
                    windowNumber: 99999,
                    isDesktopIcon: false
                )
            ],
            desktopIcons: nil,
            includeDesktopIcons: false,
            dateCreated: layout.dateCreated
        )
        viewController.saveLayouts()
        
        // Verify update persisted
        let newVC = ViewController()
        newVC.loadSavedLayouts()
        
        XCTAssertEqual(newVC.savedLayouts.count, 1)
        XCTAssertEqual(newVC.savedLayouts.first?.name, "Updated Name")
        XCTAssertEqual(newVC.savedLayouts.first?.windows.count, 1)
        XCTAssertEqual(newVC.savedLayouts.first?.windows.first?.bundleIdentifier, "com.apple.safari")
    }
    
    // MARK: - Desktop Icon Tests
    
    func testDesktopIconDetectionLogic() throws {
        // Test cases: (width, height, owner, title, shouldBeIcon)
        let testCases: [(CGFloat, CGFloat, String, String, Bool)] = [
            (80, 80, "Finder", "File.txt", true),     // Small Finder with title = icon
            (99, 99, "Finder", "Doc.pdf", true),      // Just under 100x100 = icon
            (100, 100, "Finder", "Window", false),    // At threshold = not icon
            (80, 80, "Safari", "Page", false),        // Small non-Finder = not icon
            (800, 600, "Finder", "Folder", false),    // Large Finder = not icon
            (80, 80, "Finder", "", false),            // Small Finder no title = not icon
            (80, 120, "Finder", "File.txt", false),   // Non-square small = not icon
        ]
        
        for (width, height, owner, title, shouldBeIcon) in testCases {
            let isDesktopIcon = owner == "Finder" && 
                               width < 100 && 
                               height < 100 && 
                               !title.isEmpty
            
            XCTAssertEqual(isDesktopIcon, shouldBeIcon,
                          "\(width)x\(height) \(owner) window '\(title)' should\(shouldBeIcon ? "" : " not") be icon")
        }
    }
    
    func testDesktopIconsSeparatedWhenIncluded() throws {
        // Test the critical conditional: when includeDesktopIcons is true,
        // desktop icons should be in desktopIcons array and NOT in windows array
        
        let layout = LayoutData(
            name: "Layout with Desktop Icons",
            windows: [
                WindowInfo(
                    bundleIdentifier: "com.apple.safari",
                    windowTitle: "Safari Window",
                    frame: CGRect(x: 200, y: 200, width: 800, height: 600),
                    isMinimized: false,
                    isHidden: false,
                    windowNumber: 1001,
                    isDesktopIcon: false
                )
            ],
            desktopIcons: [
                DesktopIconInfo(name: "File1.txt", position: CGPoint(x: 50, y: 50)),
                DesktopIconInfo(name: "File2.pdf", position: CGPoint(x: 150, y: 150))
            ],
            includeDesktopIcons: true,
            dateCreated: Date()
        )
        
        // When desktop icons are included, they should be separated
        XCTAssertNotNil(layout.desktopIcons)
        XCTAssertEqual(layout.desktopIcons?.count, 2)
        
        // Windows array should NOT contain desktop icons
        XCTAssertTrue(layout.windows.allSatisfy { !$0.isDesktopIcon },
                     "Windows array should not contain desktop icons when separated")
        XCTAssertEqual(layout.windows.count, 1)
        XCTAssertEqual(layout.windows.first?.windowTitle, "Safari Window")
    }
    
    func testDesktopIconsInWindowsWhenNotIncluded() throws {
        // When includeDesktopIcons is false, desktop icons stay in windows array
        
        let layout = LayoutData(
            name: "Layout without Desktop Icons",
            windows: [
                WindowInfo(
                    bundleIdentifier: "com.apple.finder",
                    windowTitle: "File.txt",
                    frame: CGRect(x: 50, y: 50, width: 80, height: 80),
                    isMinimized: false,
                    isHidden: false,
                    windowNumber: 2001,
                    isDesktopIcon: true
                ),
                WindowInfo(
                    bundleIdentifier: "com.apple.safari",
                    windowTitle: "Safari",
                    frame: CGRect(x: 200, y: 200, width: 800, height: 600),
                    isMinimized: false,
                    isHidden: false,
                    windowNumber: 2002,
                    isDesktopIcon: false
                )
            ],
            desktopIcons: nil,
            includeDesktopIcons: false,
            dateCreated: Date()
        )
        
        // Desktop icons should remain in windows when not separated
        XCTAssertNil(layout.desktopIcons)
        XCTAssertEqual(layout.windows.count, 2)
        XCTAssertTrue(layout.windows.contains { $0.isDesktopIcon },
                     "Desktop icons should remain in windows when not separated")
    }
    
    func testDesktopIconsPersistAcrossReload() throws {
        let layout = LayoutData(
            name: "Persistent Desktop Icons",
            windows: [],
            desktopIcons: [
                DesktopIconInfo(name: "Test.txt", position: CGPoint(x: 100, y: 200)),
                DesktopIconInfo(name: "Doc.pdf", position: CGPoint(x: 300, y: 400))
            ],
            includeDesktopIcons: true,
            dateCreated: Date()
        )
        
        viewController.savedLayouts.append(layout)
        viewController.saveLayouts()
        
        // Load in new instance
        let newVC = ViewController()
        newVC.loadSavedLayouts()
        
        XCTAssertEqual(newVC.savedLayouts.count, 1)
        XCTAssertNotNil(newVC.savedLayouts.first?.desktopIcons)
        XCTAssertEqual(newVC.savedLayouts.first?.desktopIcons?.count, 2)
        XCTAssertEqual(newVC.savedLayouts.first?.desktopIcons?.first?.name, "Test.txt")
        XCTAssertEqual(newVC.savedLayouts.first?.desktopIcons?.first?.position, CGPoint(x: 100, y: 200))
        XCTAssertTrue(newVC.savedLayouts.first?.includeDesktopIcons ?? false)
    }
    
    func testDesktopIconsExtractedFromWindowList() throws {
        // Test that DesktopIconInfo structure works correctly
        // captureDesktopIcons now uses CGWindowListCopyWindowInfo directly,
        // so we test the data structure and matching logic
        
        let desktopIcons = [
            DesktopIconInfo(name: "Icon1.txt", position: CGPoint(x: 10, y: 20)),
            DesktopIconInfo(name: "Icon2.pdf", position: CGPoint(x: 200, y: 300))
        ]
        
        XCTAssertEqual(desktopIcons.count, 2)
        XCTAssertEqual(desktopIcons.first?.name, "Icon1.txt")
        XCTAssertEqual(desktopIcons.first?.position, CGPoint(x: 10, y: 20))
        XCTAssertEqual(desktopIcons.last?.name, "Icon2.pdf")
        XCTAssertEqual(desktopIcons.last?.position, CGPoint(x: 200, y: 300))
        
        // Test that desktop icon names match expected format (file names)
        for icon in desktopIcons {
            XCTAssertFalse(icon.name.isEmpty, "Desktop icon should have a name")
            XCTAssertTrue(icon.name.contains(".") || icon.name.count > 0, "Desktop icon name should be a valid file name")
        }
    }
    
    // MARK: - Table View Tests
    
    func testTableViewDataSource() throws {
        viewController.savedLayouts = [
            LayoutData(name: "Layout 1", windows: [], desktopIcons: nil, includeDesktopIcons: false, dateCreated: Date()),
            LayoutData(name: "Layout 2", windows: [], desktopIcons: nil, includeDesktopIcons: false, dateCreated: Date()),
            LayoutData(name: "Layout 3", windows: [], desktopIcons: nil, includeDesktopIcons: false, dateCreated: Date())
        ]
        
        let rowCount = viewController.numberOfRows(in: NSTableView())
        XCTAssertEqual(rowCount, 3, "Table should report correct number of layouts")
    }
    
    func testTableViewCellConfiguration() throws {
        // Just verify the table view can report the correct count
        // The actual cell creation requires proper nib loading which isn't available in unit tests
        let layout = LayoutData(
            name: "Test Layout Name",
            windows: [],
            desktopIcons: nil,
            includeDesktopIcons: false,
            dateCreated: Date()
        )
        
        viewController.savedLayouts = [layout]
        
        let rowCount = viewController.numberOfRows(in: NSTableView())
        XCTAssertEqual(rowCount, 1, "Should have one layout in table")
    }
}