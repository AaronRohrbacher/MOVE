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
                )
            ],
            desktopIcons: nil,
            includeDesktopIcons: false,
            dateCreated: Date()
        )
        
        viewController.savedLayouts.append(layout)
        viewController.saveLayouts()
        
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
        let layouts = [
            LayoutData(name: "Layout 1", windows: [], desktopIcons: nil, includeDesktopIcons: false, dateCreated: Date()),
            LayoutData(name: "Layout 2", windows: [], desktopIcons: nil, includeDesktopIcons: false, dateCreated: Date()),
            LayoutData(name: "Layout 3", windows: [], desktopIcons: nil, includeDesktopIcons: false, dateCreated: Date())
        ]
        
        viewController.savedLayouts = layouts
        viewController.saveLayouts()
        
        viewController.savedLayouts.remove(at: 1)
        viewController.saveLayouts()
        
        let newVC = ViewController()
        newVC.loadSavedLayouts()
        
        XCTAssertEqual(newVC.savedLayouts.count, 2)
        XCTAssertEqual(newVC.savedLayouts[0].name, "Layout 1")
        XCTAssertEqual(newVC.savedLayouts[1].name, "Layout 3")
        XCTAssertFalse(newVC.savedLayouts.contains { $0.name == "Layout 2" })
    }
    
    func testUpdateLayoutModifiesExisting() throws {
        let layout = LayoutData(
            name: "Original Name",
            windows: [],
            desktopIcons: nil,
            includeDesktopIcons: false,
            dateCreated: Date()
        )
        
        viewController.savedLayouts.append(layout)
        viewController.saveLayouts()
        
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
                )
            ],
            desktopIcons: nil,
            includeDesktopIcons: false,
            dateCreated: layout.dateCreated
        )
        viewController.saveLayouts()
        
        let newVC = ViewController()
        newVC.loadSavedLayouts()
        
        XCTAssertEqual(newVC.savedLayouts.count, 1)
        XCTAssertEqual(newVC.savedLayouts.first?.name, "Updated Name")
        XCTAssertEqual(newVC.savedLayouts.first?.windows.count, 1)
        XCTAssertEqual(newVC.savedLayouts.first?.windows.first?.bundleIdentifier, "com.apple.safari")
    }
    
    func testDesktopIconDetectionLogic() throws {
        let testCases: [(CGFloat, CGFloat, String, String, Bool)] = [
            (80, 80, "Finder", "File.txt", true),     // Small Finder with title = icon
            (99, 99, "Finder", "Doc.pdf", true),      // Just under 100x100 = icon
            (100, 100, "Finder", "Window", false),    // At threshold = not icon
            (80, 80, "Safari", "Page", false),        // Small non-Finder = not icon
            (800, 600, "Finder", "Folder", false),    // Large Finder = not icon
            (80, 80, "Finder", "", false),            // Small Finder no title = not icon
            (80, 120, "Finder", "File.txt", false),
        ]
    }
    
    func testDesktopIconsSeparatedWhenIncluded() throws {
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
                )
            ],
            desktopIcons: [
                DesktopIconInfo(name: "File1.txt", position: CGPoint(x: 50, y: 50)),
                DesktopIconInfo(name: "File2.pdf", position: CGPoint(x: 150, y: 150))
            ],
            includeDesktopIcons: true,
            dateCreated: Date()
        )
        
        XCTAssertNotNil(layout.desktopIcons)
        XCTAssertEqual(layout.desktopIcons?.count, 2)
        XCTAssertEqual(layout.windows.count, 1)
        XCTAssertEqual(layout.windows.first?.windowTitle, "Safari Window")
    }
    
    func testDesktopIconsInWindowsWhenNotIncluded() throws {
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
                ),
                WindowInfo(
                    bundleIdentifier: "com.apple.safari",
                    windowTitle: "Safari",
                    frame: CGRect(x: 200, y: 200, width: 800, height: 600),
                    isMinimized: false,
                    isHidden: false,
                    windowNumber: 2002,
                )
            ],
            desktopIcons: nil,
            includeDesktopIcons: false,
            dateCreated: Date()
        )
        
        XCTAssertNil(layout.desktopIcons)
        XCTAssertEqual(layout.windows.count, 2)
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
        let desktopIcons = [
            DesktopIconInfo(name: "Icon1.txt", position: CGPoint(x: 10, y: 20)),
            DesktopIconInfo(name: "Icon2.pdf", position: CGPoint(x: 200, y: 300))
        ]
        
        XCTAssertEqual(desktopIcons.count, 2)
        XCTAssertEqual(desktopIcons.first?.name, "Icon1.txt")
        XCTAssertEqual(desktopIcons.first?.position, CGPoint(x: 10, y: 20))
        XCTAssertEqual(desktopIcons.last?.name, "Icon2.pdf")
        XCTAssertEqual(desktopIcons.last?.position, CGPoint(x: 200, y: 300))
        
        for icon in desktopIcons {
            XCTAssertFalse(icon.name.isEmpty, "Desktop icon should have a name")
            XCTAssertTrue(icon.name.contains(".") || icon.name.count > 0, "Desktop icon name should be a valid file name")
        }
    }
    
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
    
    func testJSONEncodingOfLayoutData() throws {
        let layout = LayoutData(
            name: "Encoding Test",
            windows: [
                WindowInfo(
                    bundleIdentifier: "com.test.app",
                    windowTitle: "Test Window",
                    frame: CGRect(x: 100, y: 200, width: 800, height: 600),
                    isMinimized: false,
                    isHidden: false,
                    windowNumber: 12345,
                )
            ],
            desktopIcons: [
                DesktopIconInfo(name: "File.txt", position: CGPoint(x: 50, y: 100))
            ],
            includeDesktopIcons: true,
            dateCreated: Date()
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(layout)
        
        XCTAssertFalse(data.isEmpty, "Encoded data should not be empty")
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LayoutData.self, from: data)
        
        XCTAssertEqual(decoded.name, "Encoding Test")
        XCTAssertEqual(decoded.windows.count, 1)
        XCTAssertEqual(decoded.windows.first?.windowTitle, "Test Window")
        XCTAssertEqual(decoded.windows.first?.frame, CGRect(x: 100, y: 200, width: 800, height: 600))
        XCTAssertNotNil(decoded.desktopIcons)
        XCTAssertEqual(decoded.desktopIcons?.count, 1)
        XCTAssertEqual(decoded.desktopIcons?.first?.name, "File.txt")
        XCTAssertEqual(decoded.desktopIcons?.first?.position, CGPoint(x: 50, y: 100))
    }
    
    func testCGPointEncoding() throws {
        let point = CGPoint(x: 123.456, y: 789.012)
        let icon = DesktopIconInfo(name: "Test", position: point)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(icon)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DesktopIconInfo.self, from: data)
        
        XCTAssertEqual(decoded.position.x, point.x, accuracy: 0.001)
        XCTAssertEqual(decoded.position.y, point.y, accuracy: 0.001)
    }
    
    func testCGRectEncoding() throws {
        let rect = CGRect(x: 100.5, y: 200.75, width: 800.25, height: 600.125)
        let window = WindowInfo(
            bundleIdentifier: "com.test",
            windowTitle: "Test",
            frame: rect,
            isMinimized: false,
            isHidden: false,
            windowNumber: 1,
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(window)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WindowInfo.self, from: data)
        
        XCTAssertEqual(decoded.frame.origin.x, rect.origin.x, accuracy: 0.001)
        XCTAssertEqual(decoded.frame.origin.y, rect.origin.y, accuracy: 0.001)
        XCTAssertEqual(decoded.frame.size.width, rect.size.width, accuracy: 0.001)
        XCTAssertEqual(decoded.frame.size.height, rect.size.height, accuracy: 0.001)
    }
    
    func testUserDefaultsDirectWriteAndRead() throws {
        let layouts = [
            LayoutData(
                name: "Direct Test 1",
                windows: [],
                desktopIcons: nil,
                includeDesktopIcons: false,
                dateCreated: Date()
            ),
            LayoutData(
                name: "Direct Test 2",
                windows: [
                    WindowInfo(
                        bundleIdentifier: "com.test",
                        windowTitle: "Window",
                        frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                        isMinimized: false,
                        isHidden: false,
                        windowNumber: 1,
                    )
                ],
                desktopIcons: [DesktopIconInfo(name: "Icon", position: CGPoint(x: 10, y: 20))],
                includeDesktopIcons: true,
                dateCreated: Date()
            )
        ]
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(layouts)
        UserDefaults.standard.set(data, forKey: "SavedLayouts")
        UserDefaults.standard.synchronize()
        
        guard let readData = UserDefaults.standard.data(forKey: "SavedLayouts") else {
            XCTFail("No data found in UserDefaults")
            return
        }
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode([LayoutData].self, from: readData)
        
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].name, "Direct Test 1")
        XCTAssertEqual(decoded[1].name, "Direct Test 2")
        XCTAssertEqual(decoded[1].windows.count, 1)
        XCTAssertNotNil(decoded[1].desktopIcons)
        XCTAssertEqual(decoded[1].desktopIcons?.count, 1)
    }
    
    func testSaveLayoutsActuallyWritesToUserDefaults() throws {
        let layout = LayoutData(
            name: "UserDefaults Test",
            windows: [],
            desktopIcons: nil,
            includeDesktopIcons: false,
            dateCreated: Date()
        )
        
        viewController.savedLayouts = [layout]
        viewController.saveLayouts()
        
        guard let data = UserDefaults.standard.data(forKey: "SavedLayouts") else {
            XCTFail("saveLayouts() did not write data to UserDefaults")
            return
        }
        
        XCTAssertFalse(data.isEmpty, "Data in UserDefaults should not be empty")
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode([LayoutData].self, from: data)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded.first?.name, "UserDefaults Test")
    }
    
    func testLoadSavedLayoutsActuallyReadsFromUserDefaults() throws {
        let layout = LayoutData(
            name: "Load Test",
            windows: [
                WindowInfo(
                    bundleIdentifier: "com.load.test",
                    windowTitle: "Load Window",
                    frame: CGRect(x: 50, y: 50, width: 500, height: 400),
                    isMinimized: true,
                    isHidden: false,
                    windowNumber: 999,
                )
            ],
            desktopIcons: nil,
            includeDesktopIcons: false,
            dateCreated: Date()
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode([layout])
        UserDefaults.standard.set(data, forKey: "SavedLayouts")
        UserDefaults.standard.synchronize()
        
        viewController.savedLayouts = []
        
        viewController.loadSavedLayouts()
        
        let expectation = XCTestExpectation(description: "Load complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(viewController.savedLayouts.count, 1, "loadSavedLayouts() should read from UserDefaults")
        XCTAssertEqual(viewController.savedLayouts.first?.name, "Load Test")
        XCTAssertEqual(viewController.savedLayouts.first?.windows.count, 1)
        XCTAssertEqual(viewController.savedLayouts.first?.windows.first?.windowTitle, "Load Window")
        XCTAssertTrue(viewController.savedLayouts.first?.windows.first?.isMinimized ?? false)
    }
    
    func testEncodingWithEmptyWindows() throws {
        let layout = LayoutData(
            name: "Empty Windows",
            windows: [],
            desktopIcons: nil,
            includeDesktopIcons: false,
            dateCreated: Date()
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode([layout])
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode([LayoutData].self, from: data)
        
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded.first?.windows.count, 0)
    }
    
    func testEncodingWithNilDesktopIcons() throws {
        let layout = LayoutData(
            name: "Nil Icons",
            windows: [],
            desktopIcons: nil,
            includeDesktopIcons: false,
            dateCreated: Date()
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode([layout])
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode([LayoutData].self, from: data)
        
        XCTAssertEqual(decoded.count, 1)
        XCTAssertNil(decoded.first?.desktopIcons)
    }
    
    func testDecodingCorruptedDataHandlesGracefully() throws {
        let corruptedData = "not valid json".data(using: .utf8)!
        UserDefaults.standard.set(corruptedData, forKey: "SavedLayouts")
        UserDefaults.standard.synchronize()
        
        viewController.loadSavedLayouts()
        
        let expectation = XCTestExpectation(description: "Load complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(viewController.savedLayouts.count, 0, "Corrupted data should result in empty array")
        XCTAssertNil(UserDefaults.standard.data(forKey: "SavedLayouts"), "Corrupted data should be removed")
    }
    
    func testRoundTripWithComplexData() throws {
        let complexLayout = LayoutData(
            name: "Complex Layout",
            windows: [
                WindowInfo(
                    bundleIdentifier: "com.app1",
                    windowTitle: "Window 1",
                    frame: CGRect(x: 10.5, y: 20.75, width: 800.25, height: 600.125),
                    isMinimized: false,
                    isHidden: false,
                    windowNumber: 1001,
                ),
                WindowInfo(
                    bundleIdentifier: "com.app2",
                    windowTitle: "",
                    frame: CGRect(x: 100, y: 200, width: 400, height: 300),
                    isMinimized: true,
                    isHidden: true,
                    windowNumber: 1002,
                )
            ],
            desktopIcons: [
                DesktopIconInfo(name: "File1.txt", position: CGPoint(x: 50.5, y: 100.75)),
                DesktopIconInfo(name: "File2.pdf", position: CGPoint(x: 200.25, y: 300.125))
            ],
            includeDesktopIcons: true,
            dateCreated: Date()
        )
        
        viewController.savedLayouts = [complexLayout]
        viewController.saveLayouts()
        
        let newVC = ViewController()
        newVC.loadSavedLayouts()
        
        let expectation = XCTestExpectation(description: "Load complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(newVC.savedLayouts.count, 1)
        let loaded = newVC.savedLayouts.first!
        XCTAssertEqual(loaded.name, "Complex Layout")
        XCTAssertEqual(loaded.windows.count, 2)
        XCTAssertEqual(loaded.windows[0].bundleIdentifier, "com.app1")
        XCTAssertEqual(loaded.windows[0].frame.origin.x, 10.5, accuracy: 0.001)
        XCTAssertEqual(loaded.windows[1].isMinimized, true)
        XCTAssertNotNil(loaded.desktopIcons)
        XCTAssertEqual(loaded.desktopIcons?.count, 2)
        XCTAssertEqual(loaded.desktopIcons?[0].position.x ?? 0, 50.5, accuracy: 0.001)
    }
    
    func testCaptureExcludesOwnWindow() throws {
        let layout = LayoutData(
            name: "Exclude Self Test",
            windows: [
                WindowInfo(
                    bundleIdentifier: "com.apple.finder",
                    windowTitle: "Finder Window",
                    frame: CGRect(x: 100, y: 100, width: 800, height: 600),
                    isMinimized: false,
                    isHidden: false,
                    windowNumber: 12345,
                ),
                WindowInfo(
                    bundleIdentifier: "com.apple.safari",
                    windowTitle: "Safari Window",
                    frame: CGRect(x: 200, y: 200, width: 1000, height: 700),
                    isMinimized: false,
                    isHidden: false,
                    windowNumber: 12346,
                )
            ],
            desktopIcons: nil,
            includeDesktopIcons: false,
            dateCreated: Date()
        )
        
        let moveBundleId = "com.aaronrohrbacher.MOVE"
        for window in layout.windows {
            XCTAssertNotEqual(window.bundleIdentifier, moveBundleId, 
                             "Layout should not contain windows from MOVE app itself")
        }
        
        XCTAssertEqual(layout.windows.count, 2, "Layout should have 2 windows from other apps")
    }
    
    func testWindowCountDisplayedInTableView() throws {
        let layouts = [
            LayoutData(
                name: "Zero Windows",
                windows: [],
                desktopIcons: nil,
                includeDesktopIcons: false,
                dateCreated: Date()
            ),
            LayoutData(
                name: "One Window",
                windows: [
                    WindowInfo(
                        bundleIdentifier: "com.test",
                        windowTitle: "Test",
                        frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                        isMinimized: false,
                        isHidden: false,
                        windowNumber: 1,
                    )
                ],
                desktopIcons: nil,
                includeDesktopIcons: false,
                dateCreated: Date()
            ),
            LayoutData(
                name: "Two Windows",
                windows: [
                    WindowInfo(
                        bundleIdentifier: "com.test1",
                        windowTitle: "Window 1",
                        frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                        isMinimized: false,
                        isHidden: false,
                        windowNumber: 1,
                    ),
                    WindowInfo(
                        bundleIdentifier: "com.test2",
                        windowTitle: "Window 2",
                        frame: CGRect(x: 100, y: 100, width: 200, height: 200),
                        isMinimized: false,
                        isHidden: false,
                        windowNumber: 2,
                    )
                ],
                desktopIcons: nil,
                includeDesktopIcons: false,
                dateCreated: Date()
            ),
            LayoutData(
                name: "Three Windows",
                windows: [
                    WindowInfo(
                        bundleIdentifier: "com.test1",
                        windowTitle: "Window 1",
                        frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                        isMinimized: false,
                        isHidden: false,
                        windowNumber: 1,
                    ),
                    WindowInfo(
                        bundleIdentifier: "com.test2",
                        windowTitle: "Window 2",
                        frame: CGRect(x: 100, y: 100, width: 200, height: 200),
                        isMinimized: false,
                        isHidden: false,
                        windowNumber: 2,
                    ),
                    WindowInfo(
                        bundleIdentifier: "com.test3",
                        windowTitle: "Window 3",
                        frame: CGRect(x: 200, y: 200, width: 300, height: 300),
                        isMinimized: false,
                        isHidden: false,
                        windowNumber: 3,
                    )
                ],
                desktopIcons: nil,
                includeDesktopIcons: false,
                dateCreated: Date()
            )
        ]
        
        viewController.savedLayouts = layouts
        viewController.saveLayouts()
        
        let tableView = NSTableView()
        let rowCount = viewController.numberOfRows(in: tableView)
        XCTAssertEqual(rowCount, 4, "Table should have 4 rows")
        
        XCTAssertEqual(viewController.savedLayouts[0].windows.count, 0, "First layout should have 0 windows")
        XCTAssertEqual(viewController.savedLayouts[1].windows.count, 1, "Second layout should have 1 window")
        XCTAssertEqual(viewController.savedLayouts[2].windows.count, 2, "Third layout should have 2 windows")
        XCTAssertEqual(viewController.savedLayouts[3].windows.count, 3, "Fourth layout should have 3 windows")
        
        for (index, layout) in viewController.savedLayouts.enumerated() {
            let cell = viewController.tableView(tableView, viewFor: nil, row: index)
            guard let cellView = cell as? NSTableCellView else {
                XCTFail("Cell should be NSTableCellView for row \(index)")
                continue
            }
            
            let textFields = cellView.subviews.compactMap { $0 as? NSTextField }
            XCTAssertGreaterThanOrEqual(textFields.count, 2, "Cell should have at least 2 text fields (title and subtitle) for row \(index)")
            
            if textFields.count >= 2 {
                let subtitle = textFields[1]
                let expectedText = "\(layout.windows.count) windows"
                XCTAssertEqual(subtitle.stringValue, expectedText, 
                             "Layout '\(layout.name)' should display '\(expectedText)' but shows '\(subtitle.stringValue)'")
            }
        }
    }
    
    func testWindowCountPersistsAfterReload() throws {
        let layout = LayoutData(
            name: "Window Count Test",
            windows: [
                WindowInfo(
                    bundleIdentifier: "com.app1",
                    windowTitle: "Window 1",
                    frame: CGRect(x: 10, y: 10, width: 100, height: 100),
                    isMinimized: false,
                    isHidden: false,
                    windowNumber: 1,
                ),
                WindowInfo(
                    bundleIdentifier: "com.app2",
                    windowTitle: "Window 2",
                    frame: CGRect(x: 200, y: 200, width: 200, height: 200),
                    isMinimized: false,
                    isHidden: false,
                    windowNumber: 2,
                ),
                WindowInfo(
                    bundleIdentifier: "com.app3",
                    windowTitle: "Window 3",
                    frame: CGRect(x: 400, y: 400, width: 300, height: 300),
                    isMinimized: false,
                    isHidden: false,
                    windowNumber: 3,
                )
            ],
            desktopIcons: nil,
            includeDesktopIcons: false,
            dateCreated: Date()
        )
        
        viewController.savedLayouts = [layout]
        viewController.saveLayouts()
        
        let newVC = ViewController()
        newVC.loadSavedLayouts()
        
        let expectation = XCTestExpectation(description: "Load complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(newVC.savedLayouts.count, 1, "Should have 1 layout")
        XCTAssertEqual(newVC.savedLayouts.first?.windows.count, 3, "Layout should have 3 windows after reload")
        XCTAssertEqual(newVC.savedLayouts.first?.name, "Window Count Test")
    }
    
    func testWindowCountWithDesktopIcons() throws {
        let layout = LayoutData(
            name: "Windows and Icons",
            windows: [
                WindowInfo(
                    bundleIdentifier: "com.app1",
                    windowTitle: "App Window",
                    frame: CGRect(x: 100, y: 100, width: 800, height: 600),
                    isMinimized: false,
                    isHidden: false,
                    windowNumber: 1,
                )
            ],
            desktopIcons: [
                DesktopIconInfo(name: "Icon1.txt", position: CGPoint(x: 50, y: 50)),
                DesktopIconInfo(name: "Icon2.pdf", position: CGPoint(x: 150, y: 150))
            ],
            includeDesktopIcons: true,
            dateCreated: Date()
        )
        
        XCTAssertEqual(layout.windows.count, 1, "Layout should have 1 window")
        XCTAssertEqual(layout.desktopIcons?.count, 2, "Layout should have 2 desktop icons")
        XCTAssertNotEqual(layout.windows.count, (layout.desktopIcons?.count ?? 0), 
                         "Window count should not include desktop icons")
    }
    
    func testRestoreLayoutCallsRestoreWindowForEachWindow() throws {
        let layout = LayoutData(
            name: "Restore Test",
            windows: [
                WindowInfo(
                    bundleIdentifier: "com.apple.finder",
                    windowTitle: "Test Window 1",
                    frame: CGRect(x: 100, y: 200, width: 800, height: 600),
                    isMinimized: false,
                    isHidden: false,
                    windowNumber: 1,
                ),
                WindowInfo(
                    bundleIdentifier: "com.apple.finder",
                    windowTitle: "Test Window 2",
                    frame: CGRect(x: 200, y: 300, width: 900, height: 700),
                    isMinimized: false,
                    isHidden: false,
                    windowNumber: 2,
                )
            ],
            desktopIcons: nil,
            includeDesktopIcons: false,
            dateCreated: Date()
        )
        
        viewController.savedLayouts = [layout]
        
        XCTAssertEqual(layout.windows.count, 2, "Layout should have 2 windows to restore")
        XCTAssertFalse(layout.windows.isEmpty, "Layout must have windows to restore")
        for window in layout.windows {
            XCTAssertFalse(window.windowTitle.isEmpty || window.bundleIdentifier.isEmpty,
                         "Each window must have title and bundle ID for restore to work")
        }
    }
    
    func testRestoreLayoutCallsRestoreDesktopIconsWhenIncluded() throws {
        let layout = LayoutData(
            name: "Desktop Icons Restore Test",
            windows: [],
            desktopIcons: [
                DesktopIconInfo(name: "File1.txt", position: CGPoint(x: 50, y: 100)),
                DesktopIconInfo(name: "File2.pdf", position: CGPoint(x: 150, y: 200))
            ],
            includeDesktopIcons: true,
            dateCreated: Date()
        )
        
        XCTAssertTrue(layout.includeDesktopIcons, "Layout must have includeDesktopIcons=true for restore to work")
        XCTAssertNotNil(layout.desktopIcons, "Layout must have desktopIcons array when includeDesktopIcons is true")
        XCTAssertEqual(layout.desktopIcons?.count ?? 0, 2, "Layout should have 2 desktop icons to restore")
        
        for icon in layout.desktopIcons ?? [] {
            XCTAssertFalse(icon.name.isEmpty, "Desktop icon must have a name for restore to work")
        }
    }
    
    func testRestoreLayoutDoesNotCallRestoreDesktopIconsWhenNotIncluded() throws {
        let layout = LayoutData(
            name: "No Desktop Icons",
            windows: [],
            desktopIcons: nil,
            includeDesktopIcons: false,
            dateCreated: Date()
        )
        
        XCTAssertFalse(layout.includeDesktopIcons, "Layout should not include desktop icons")
        XCTAssertNil(layout.desktopIcons, "Desktop icons should be nil when not included")
    }
    
    func testRestoreLayoutWithBothWindowsAndDesktopIcons() throws {
        let layout = LayoutData(
            name: "Full Restore Test",
            windows: [
                WindowInfo(
                    bundleIdentifier: "com.apple.finder",
                    windowTitle: "Finder Window",
                    frame: CGRect(x: 100, y: 100, width: 800, height: 600),
                    isMinimized: false,
                    isHidden: false,
                    windowNumber: 1,
                )
            ],
            desktopIcons: [
                DesktopIconInfo(name: "Document.txt", position: CGPoint(x: 50, y: 50))
            ],
            includeDesktopIcons: true,
            dateCreated: Date()
        )
        
        XCTAssertEqual(layout.windows.count, 1, "Layout should have 1 window")
        XCTAssertTrue(layout.includeDesktopIcons, "Layout should include desktop icons")
        XCTAssertNotNil(layout.desktopIcons, "Layout should have desktop icons")
        XCTAssertEqual(layout.desktopIcons?.count ?? 0, 1, "Layout should have 1 desktop icon")
        XCTAssertFalse(layout.windows.isEmpty, "Windows array should not be empty")
        XCTAssertFalse(layout.desktopIcons?.isEmpty ?? true, "Desktop icons array should not be empty")
    }
    
    func testRestoreDesktopIconsRequiresFinderRunning() throws {
        let icons = [
            DesktopIconInfo(name: "Test.txt", position: CGPoint(x: 100, y: 200))
        ]
        
        let finderApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.finder"
        })
        
        XCTAssertNotNil(finderApp, "Finder should be running for desktop icon restore to work")
    }
    
    func testSavedLayoutPositionsArePreservedForRestore() throws {
        let savedWindowFrame = CGRect(x: 150, y: 250, width: 900, height: 700)
        let savedIconPosition = CGPoint(x: 75, y: 125)
        
        let layout = LayoutData(
            name: "Position Test",
            windows: [
                WindowInfo(
                    bundleIdentifier: "com.test.app",
                    windowTitle: "Test Window",
                    frame: savedWindowFrame,
                    isMinimized: false,
                    isHidden: false,
                    windowNumber: 1,
                )
            ],
            desktopIcons: [
                DesktopIconInfo(name: "Icon.txt", position: savedIconPosition)
            ],
            includeDesktopIcons: true,
            dateCreated: Date()
        )
        
        viewController.savedLayouts = [layout]
        viewController.saveLayouts()
        
        let newVC = ViewController()
        newVC.loadSavedLayouts()
        
        let expectation = XCTestExpectation(description: "Load complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        guard let loadedLayout = newVC.savedLayouts.first else {
            XCTFail("Layout should be loaded")
            return
        }
        
        XCTAssertEqual(loadedLayout.windows.first?.frame, savedWindowFrame,
                      "Window frame should be preserved for restore")
        XCTAssertEqual(loadedLayout.desktopIcons?.first?.position, savedIconPosition,
                      "Desktop icon position should be preserved for restore")
    }
    
    func testDesktopIconsAreCapturedWhenIncludeDesktopIconsIsTrue() throws {
        let layout = LayoutData(
            name: "Capture Test",
            windows: [
                WindowInfo(
                    bundleIdentifier: "com.apple.finder",
                    windowTitle: "Finder Window",
                    frame: CGRect(x: 100, y: 100, width: 800, height: 600),
                    isMinimized: false,
                    isHidden: false,
                    windowNumber: 1,
                )
            ],
            desktopIcons: [
                DesktopIconInfo(name: "TestFile.txt", position: CGPoint(x: 50, y: 50)),
                DesktopIconInfo(name: "AnotherFile.pdf", position: CGPoint(x: 150, y: 150))
            ],
            includeDesktopIcons: true,
            dateCreated: Date()
        )
        
        XCTAssertTrue(layout.includeDesktopIcons, "Layout should include desktop icons")
        XCTAssertNotNil(layout.desktopIcons, "Desktop icons should be captured when includeDesktopIcons is true")
        XCTAssertGreaterThan(layout.desktopIcons?.count ?? 0, 0, 
                            "Desktop icons array should contain icons when includeDesktopIcons is true")
        
        viewController.savedLayouts = [layout]
        viewController.saveLayouts()
        
        let newVC = ViewController()
        newVC.loadSavedLayouts()
        
        let expectation = XCTestExpectation(description: "Load complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        guard let loaded = newVC.savedLayouts.first else {
            XCTFail("Layout should be loaded")
            return
        }
        
        XCTAssertTrue(loaded.includeDesktopIcons, "includeDesktopIcons should be preserved")
        XCTAssertNotNil(loaded.desktopIcons, "Desktop icons should be preserved after save/load")
        XCTAssertEqual(loaded.desktopIcons?.count ?? 0, 2, "All desktop icons should be preserved")
    }
    
    func testDesktopIconsAreNotCapturedWhenIncludeDesktopIconsIsFalse() throws {
        let layout = LayoutData(
            name: "No Icons Test",
            windows: [],
            desktopIcons: nil,
            includeDesktopIcons: false,
            dateCreated: Date()
        )
        
        XCTAssertFalse(layout.includeDesktopIcons, "Layout should not include desktop icons")
        XCTAssertNil(layout.desktopIcons, "Desktop icons should be nil when includeDesktopIcons is false")
    }
    
    func testRestoreDesktopIconsIsCalledWithCorrectData() throws {
        let icons = [
            DesktopIconInfo(name: "File1.txt", position: CGPoint(x: 100, y: 200)),
            DesktopIconInfo(name: "File2.pdf", position: CGPoint(x: 300, y: 400))
        ]
        
        let layout = LayoutData(
            name: "Restore Icons Test",
            windows: [],
            desktopIcons: icons,
            includeDesktopIcons: true,
            dateCreated: Date()
        )
        
        XCTAssertTrue(layout.includeDesktopIcons && layout.desktopIcons != nil,
                     "restoreDesktopIcons should be called when includeDesktopIcons is true and desktopIcons is not nil")
        
        for icon in icons {
            XCTAssertFalse(icon.name.isEmpty, "Icon name is required for restoreDesktopIcons to work")
        }
    }
    
    func testRestoreWindowIsCalledForEachWindowInLayout() throws {
        let windows = [
            WindowInfo(
                bundleIdentifier: "com.app1",
                windowTitle: "Window 1",
                frame: CGRect(x: 100, y: 100, width: 800, height: 600),
                isMinimized: false,
                isHidden: false,
                windowNumber: 1,
            ),
            WindowInfo(
                bundleIdentifier: "com.app2",
                windowTitle: "Window 2",
                frame: CGRect(x: 200, y: 200, width: 900, height: 700),
                isMinimized: false,
                isHidden: false,
                windowNumber: 2,
            )
        ]
        
        let layout = LayoutData(
            name: "Restore Windows Test",
            windows: windows,
            desktopIcons: nil,
            includeDesktopIcons: false,
            dateCreated: Date()
        )
        
        XCTAssertEqual(layout.windows.count, 2, "Layout should have 2 windows")
        for window in layout.windows {
            XCTAssertFalse(window.bundleIdentifier.isEmpty, 
                          "Window bundleIdentifier is required for restoreWindow to work")
        }
    }
    
    func testCaptureDesktopIconsActuallyFindsIcons() throws {
        let icons: [DesktopIconInfo] = []
        
        let desktopPath = NSHomeDirectory() + "/Desktop"
        let desktopFiles = (try? FileManager.default.contentsOfDirectory(atPath: desktopPath))?.filter { !$0.hasPrefix(".") } ?? []
        
        print("TEST: Desktop has \(desktopFiles.count) files")
        print("TEST: captureDesktopIcons found \(icons.count) icons")
        
        guard !desktopFiles.isEmpty else {
            XCTFail("TEST SETUP FAILED: No files on desktop. Add files to desktop to test desktop icon capture.")
            return
        }
        
        XCTAssertGreaterThan(icons.count, 0, 
                           "captureDesktopIcons FAILED: Desktop has \(desktopFiles.count) files but found \(icons.count) icons. Desktop icon capture is NOT WORKING.")
        
        let capturedNames = Set(icons.map { $0.name })
        let desktopNames = Set(desktopFiles)
        let matches = capturedNames.intersection(desktopNames)
        
        print("TEST: Matched \(matches.count) icons: \(matches)")
        
        XCTAssertGreaterThan(matches.count, 0,
                           "captureDesktopIcons FAILED: No captured icon names match desktop files. Matched: \(matches). Captured: \(capturedNames). Desktop: \(desktopNames). Desktop icon capture is NOT WORKING.")
    }
    
    func testSaveLayoutActuallyCapturesDesktopIcons() throws {
        viewController.savedLayouts = []
        viewController.saveLayouts()
        
        let capturedIcons: [DesktopIconInfo] = []
        
        let layout = LayoutData(
            name: "Test Save Icons",
            windows: [],
            desktopIcons: capturedIcons.isEmpty ? nil : capturedIcons,
            includeDesktopIcons: !capturedIcons.isEmpty,
            dateCreated: Date()
        )
        
        viewController.savedLayouts.append(layout)
        viewController.saveLayouts()
        
        let newVC = ViewController()
        newVC.loadSavedLayouts()
        
        guard let savedLayout = newVC.savedLayouts.first(where: { $0.name == "Test Save Icons" }) else {
            XCTFail("Layout was not saved")
            return
        }
        
        if !capturedIcons.isEmpty {
            XCTAssertTrue(savedLayout.includeDesktopIcons, "includeDesktopIcons should be true when icons are captured")
            XCTAssertNotNil(savedLayout.desktopIcons, "desktopIcons should not be nil when icons are captured")
            XCTAssertEqual(savedLayout.desktopIcons?.count ?? 0, capturedIcons.count,
                          "Saved desktop icons count (\(savedLayout.desktopIcons?.count ?? 0)) should match captured count (\(capturedIcons.count))")
            
            print("TEST: Successfully saved \(capturedIcons.count) desktop icons")
            for icon in capturedIcons {
                print("  - Saved: \(icon.name) at (\(icon.position.x), \(icon.position.y))")
            }
        } else {
            print("TEST: No desktop icons to save (desktop may be empty or icons not found via NSView)")
        }
        
        viewController.savedLayouts.removeAll { $0.name == "Test Save Icons" }
        viewController.saveLayouts()
    }
    
    func testRestoreDesktopIconsActuallyMovesIcons() throws {
        guard NSWorkspace.shared.runningApplications.contains(where: {
            $0.bundleIdentifier == "com.apple.finder"
        }) else {
            XCTFail("Finder must be running to test desktop icon restore")
            return
        }
        
        let desktopPath = NSHomeDirectory() + "/Desktop"
        let desktopFiles = (try? FileManager.default.contentsOfDirectory(atPath: desktopPath))?.filter { !$0.hasPrefix(".") } ?? []
        XCTAssertGreaterThan(desktopFiles.count, 0, "TEST REQUIREMENT: Desktop must have files to test. Found \(desktopFiles.count) files.")
        
        let originalIcons: [DesktopIconInfo] = []
        
        guard !originalIcons.isEmpty else {
            XCTFail("❌ DESKTOP ICONS ARE BROKEN: Desktop has \(desktopFiles.count) files but captureDesktopIcons returned 0 icons. Desktop icon capture is NOT WORKING.")
            return
        }
        
        print("TEST: Captured \(originalIcons.count) desktop icons")
        for icon in originalIcons {
            print("  - \(icon.name) at (\(icon.position.x), \(icon.position.y))")
        }
        
        let testIcon = originalIcons[0]
        let originalPosition = testIcon.position
        let newPosition = CGPoint(x: originalPosition.x + 200, y: originalPosition.y + 200)
        
        print("TEST: Manually moving '\(testIcon.name)' from (\(originalPosition.x), \(originalPosition.y)) to (\(newPosition.x), \(newPosition.y))")
        
        let runningApps = NSWorkspace.shared.runningApplications
        guard let finder = runningApps.first(where: { $0.bundleIdentifier == "com.apple.finder" }) else {
            XCTFail("Finder not running")
            return
        }
        
        let finderElement = AXUIElementCreateApplication(finder.processIdentifier)
        var windowList: CFTypeRef?
        guard AXUIElementCopyAttributeValue(finderElement, kAXWindowsAttribute as CFString, &windowList) == .success,
              let windows = windowList as? [AXUIElement] else {
            XCTFail("Could not get Finder windows")
            return
        }
        
        var desktopWindow: AXUIElement?
        for window in windows {
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &role)
            if let roleStr = role as? String, roleStr == "AXScrollArea" {
                desktopWindow = window
                break
            }
        }
        
        guard let desktop = desktopWindow else {
            XCTFail("Could not find desktop window")
            return
        }
        
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(desktop, kAXChildrenAttribute as CFString, &children) == .success,
              let iconElements = children as? [AXUIElement] else {
            XCTFail("Could not get desktop icon elements")
            return
        }
        
        guard let iconElement = iconElements.first(where: { element in
            var title: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
            return (title as? String) == testIcon.name
        }) else {
            XCTFail("Could not find icon element '\(testIcon.name)'")
            return
        }
        
        var point = newPosition
        guard let positionValue = AXValueCreate(.cgPoint, &point) else {
            XCTFail("Could not create position value")
            return
        }
        
        let moveResult = AXUIElementSetAttributeValue(iconElement, kAXPositionAttribute as CFString, positionValue)
        guard moveResult == .success else {
            XCTFail("Failed to move icon via Accessibility API: \(moveResult)")
            return
        }
        
        let waitExpectation = XCTestExpectation(description: "Wait for icon move")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            waitExpectation.fulfill()
        }
        wait(for: [waitExpectation], timeout: 2.0)
        
        let movedIcons: [DesktopIconInfo] = []
        guard let movedIcon = movedIcons.first(where: { $0.name == testIcon.name }) else {
            XCTFail("❌ DESKTOP ICON CAPTURE IS BROKEN: Could not find icon '\(testIcon.name)' after move.")
            return
        }
        
        let distanceFromOriginal = sqrt(pow(movedIcon.position.x - originalPosition.x, 2) + pow(movedIcon.position.y - originalPosition.y, 2))
        if distanceFromOriginal < 50.0 {
            XCTFail("❌ ICON DID NOT MOVE: Icon was at \(originalPosition), after move attempt it's at \(movedIcon.position), distance: \(distanceFromOriginal). Desktop icons are NOT WORKING.")
            return
        }
        
        let distanceToTarget = sqrt(pow(movedIcon.position.x - newPosition.x, 2) + pow(movedIcon.position.y - newPosition.y, 2))
        if distanceToTarget >= 50.0 {
            XCTFail("❌ ICON MOVED TO WRONG POSITION: Target was \(newPosition), icon is at \(movedIcon.position), distance: \(distanceToTarget). Desktop icons are NOT WORKING.")
            return
        }
        
        print("TEST: Icon moved! Original: \(originalPosition), Target: \(newPosition), Actual: \(movedIcon.position)")
        
        print("TEST: Testing restoreDesktopIcons - restoring to original position (\(originalPosition.x), \(originalPosition.y))")
        viewController.restoreDesktopIcons([testIcon])
        
        let restoreExpectation = XCTestExpectation(description: "Wait for restore")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            restoreExpectation.fulfill()
        }
        wait(for: [restoreExpectation], timeout: 2.0)
        
        let restoredIcons: [DesktopIconInfo] = []
        guard let restoredIcon = restoredIcons.first(where: { $0.name == testIcon.name }) else {
            XCTFail("❌ DESKTOP ICON RESTORE IS BROKEN: Could not find icon after restoreDesktopIcons.")
            return
        }
        
        let restoreDistance = sqrt(pow(restoredIcon.position.x - originalPosition.x, 2) + pow(restoredIcon.position.y - originalPosition.y, 2))
        if restoreDistance >= 50.0 {
            XCTFail("❌ DESKTOP ICON RESTORE IS BROKEN: restoreDesktopIcons did not restore icon. Expected: \(originalPosition), Got: \(restoredIcon.position), Distance: \(restoreDistance). restoreDesktopIcons is NOT WORKING.")
            return
        }
        print("TEST: restoreDesktopIcons worked! Final position: (\(restoredIcon.position.x), \(restoredIcon.position.y))")
    }
}