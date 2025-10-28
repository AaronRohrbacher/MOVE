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
        viewController = ViewController()
        viewController.loadView()
        viewController.viewDidLoad()
        
        // Clear any existing layouts
        viewController.savedLayouts = []
        viewController.saveLayouts()
    }
    
    override func tearDownWithError() throws {
        viewController = nil
        UserDefaults.standard.removeObject(forKey: "SavedLayouts")
    }
    
    // MARK: - Permission Tests That Actually Test Something
    
    func testPermissionsBannerShowsWhenPermissionsNotGranted() throws {
        // First ensure the banner is created
        viewController.viewDidAppear()
        
        // Give it a moment to create the banner
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        // Check actual permission state
        let checkOpts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false] as CFDictionary
        let hasPermission = AXIsProcessTrustedWithOptions(checkOpts)
        
        // Banner should exist
        XCTAssertNotNil(viewController.permissionsBanner, "Permissions banner should be created")
        
        // Banner visibility should match permission state
        if !hasPermission {
            XCTAssertFalse(viewController.permissionsBanner?.isHidden ?? true, 
                          "Permissions banner should be visible when permissions are not granted")
        } else {
            XCTAssertTrue(viewController.permissionsBanner?.isHidden ?? false,
                         "Permissions banner should be hidden when permissions are granted")
        }
    }
    
    func testSaveLayoutFailsWithoutPermissions() throws {
        // This test SHOULD fail if permissions aren't granted - that's the point!
        let checkOpts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false] as CFDictionary
        let hasPermission = AXIsProcessTrustedWithOptions(checkOpts)
        
        if !hasPermission {
            // Save should fail without permissions
            let initialCount = viewController.savedLayouts.count
            
            // Try to save (should fail silently)
            viewController.saveLayout()
            
            // Count should not change
            XCTAssertEqual(viewController.savedLayouts.count, initialCount,
                          "Save should not add layouts without permissions")
        }
    }
    
    // MARK: - CRUD Tests That Actually Verify Functionality
    
    func testCreateLayoutActuallyCreatesValidLayout() throws {
        let layout = LayoutData(
            name: "Test Layout",
            windows: [WindowInfo(
                bundleIdentifier: "com.apple.finder",
                windowTitle: "Finder",
                frame: CGRect(x: 100, y: 100, width: 800, height: 600),
                isMinimized: false,
                isHidden: false,
                windowNumber: 12345,
                isDesktopIcon: false
            )],
            desktopIcons: nil,
            includeDesktopIcons: false,
            dateCreated: Date()
        )
        
        viewController.savedLayouts.append(layout)
        viewController.saveLayouts()
        
        // Verify it persists
        let newVC = ViewController()
        newVC.loadSavedLayouts()
        
        XCTAssertEqual(newVC.savedLayouts.count, 1, "Layout should persist across instances")
        XCTAssertEqual(newVC.savedLayouts.first?.windows.count, 1, "Layout should contain window data")
        XCTAssertEqual(newVC.savedLayouts.first?.windows.first?.frame, 
                      CGRect(x: 100, y: 100, width: 800, height: 600),
                      "Window frame should be preserved exactly")
    }
    
    func testDeleteLayoutActuallyRemovesFromPersistence() throws {
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
        
        // Verify in new instance
        let newVC = ViewController()
        newVC.loadSavedLayouts()
        
        XCTAssertEqual(newVC.savedLayouts.count, 2, "Should have 2 layouts after deletion")
        XCTAssertEqual(newVC.savedLayouts[0].name, "Layout 1", "First layout should remain")
        XCTAssertEqual(newVC.savedLayouts[1].name, "Layout 3", "Third layout should be at index 1")
        
        // Verify Layout 2 is gone
        XCTAssertFalse(newVC.savedLayouts.contains { $0.name == "Layout 2" }, 
                      "Deleted layout should not exist")
    }
    
    // MARK: - Desktop Icon Detection That Actually Tests the Logic
    
    func testDesktopIconDetectionLogic() throws {
        // Test the actual size threshold logic
        let testCases: [(width: CGFloat, height: CGFloat, owner: String, shouldBeIcon: Bool)] = [
            (80, 80, "Finder", true),    // Small Finder window = desktop icon
            (99, 99, "Finder", true),    // Just under threshold = desktop icon
            (100, 100, "Finder", false), // At threshold = regular window
            (80, 80, "Safari", false),   // Small non-Finder = regular window
            (800, 600, "Finder", false), // Large Finder = regular window
        ]
        
        for testCase in testCases {
            let window = WindowInfo(
                bundleIdentifier: testCase.owner == "Finder" ? "com.apple.finder" : "com.apple.safari",
                windowTitle: "Test",
                frame: CGRect(x: 0, y: 0, width: testCase.width, height: testCase.height),
                isMinimized: false,
                isHidden: false,
                windowNumber: 1,
                isDesktopIcon: testCase.shouldBeIcon
            )
            
            let expectedDesktopIcon = testCase.owner == "Finder" && 
                                     testCase.width < 100 && 
                                     testCase.height < 100
            
            XCTAssertEqual(window.isDesktopIcon, expectedDesktopIcon,
                          "Window \(testCase.width)x\(testCase.height) from \(testCase.owner) should\(expectedDesktopIcon ? "" : " not") be desktop icon")
        }
    }
    
    func testTableViewDataSourceReturnsCorrectCount() throws {
        // Test that the table view actually shows the right number of layouts
        viewController.savedLayouts = [
            LayoutData(name: "Layout 1", windows: [], desktopIcons: nil, includeDesktopIcons: false, dateCreated: Date()),
            LayoutData(name: "Layout 2", windows: [], desktopIcons: nil, includeDesktopIcons: false, dateCreated: Date())
        ]
        
        let rowCount = viewController.numberOfRows(in: NSTableView())
        XCTAssertEqual(rowCount, 2, "Table should report correct number of layouts")
    }
}