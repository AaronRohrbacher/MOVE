import XCTest

final class CreateLayoutUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    func testCreateLayoutFlow() throws {
        let saveButton = app.buttons["Save Layout"]
        XCTAssertTrue(saveButton.exists)
        
        saveButton.click()
        
        let saveDialog = app.dialogs["Save Layout"]
        if saveDialog.waitForExistence(timeout: 2) {
            saveDialog.buttons["Cancel"].click()
        }
    }
}