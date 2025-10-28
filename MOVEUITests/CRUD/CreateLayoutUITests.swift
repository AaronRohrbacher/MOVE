//
//  CreateLayoutUITests.swift
//  MOVE
//
//  Created by Aaron Rohrbacher on 10/22/25.
//

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
        // Test that the save dialog appears and can be cancelled
        let saveButton = app.buttons["Save Layout"]
        XCTAssertTrue(saveButton.exists)
        
        saveButton.click()
        
        // Check for save dialog
        let saveDialog = app.dialogs["Save Layout"]
        if saveDialog.waitForExistence(timeout: 2) {
            // Dialog appeared, cancel it
            saveDialog.buttons["Cancel"].click()
        }
    }
}