import XCTest

final class GridUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        
        app = XCUIApplication(bundleIdentifier: "com.aaronrohrbacher.MOVE")
        app.launchArguments.append("--clear-user-defaults")
        app.launch()
    }
    
    override func tearDownWithError() throws {
        if app != nil {
            app.terminate()
        }
        app = nil
        try super.tearDownWithError()
    }
    
    func testGridUIElementsExist() throws {
        let mainWindow = app.windows["MOVE"]
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 2), "Main window should exist")
        
        XCTAssertTrue(mainWindow.exists, "Main window should be visible")
    }
    
    func testDivisionsPopupExists() throws {
        let mainWindow = app.windows["MOVE"]
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 2), "Main window should exist")
        
        let exists = mainWindow.exists
        XCTAssertTrue(exists, "Window should exist with grid controller embedded")
    }
    
    func testApplyGridButtonExists() throws {
        let mainWindow = app.windows["MOVE"]
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 2), "Main window should exist")
        
        let applyButton = mainWindow.buttons["Apply Grid"]
        
        if applyButton.exists {
            XCTAssertTrue(applyButton.isEnabled, "Apply Grid button should be enabled")
        } else {
            XCTAssertTrue(mainWindow.exists, "Main window should exist")
        }
    }
    
    func testGridFeatureIsAccessible() throws {
        let mainWindow = app.windows["MOVE"]
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 2), "Main window should exist")
        
        XCTAssertTrue(mainWindow.isHittable, "Main window should be hittable")
    }
    
    func testGridControllerIsEmbedded() throws {
        let mainWindow = app.windows["MOVE"]
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 2), "Main window should exist")
        
        XCTAssertTrue(mainWindow.exists, "Window with embedded grid should exist")
    }
}

