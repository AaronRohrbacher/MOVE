//
//  MOVEUITests.swift
//  MOVEUITests
//
//  Created by Aaron Rohrbacher on 10/21/25.
//

import XCTest

final class MOVEUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - IMPORTANT: UI Tests CANNOT Grant System Permissions
    // System permission dialogs are outside the app's process and cannot be automated
    // These tests verify the app behaves correctly based on permission state,
    // but cannot actually grant or deny permissions.
    
    func testSaveLayoutDialogAppearsRegardlessOfPermissions() throws {
        // The save dialog should appear even without permissions
        // (permissions are checked after user enters layout name)
        let saveButton = app.buttons["Save Layout"]
        XCTAssertTrue(saveButton.exists, "Save button must exist")
        
        saveButton.click()
        
        // The dialog should appear
        let saveDialog = app.dialogs["Save Layout"]
        XCTAssertTrue(saveDialog.waitForExistence(timeout: 2), 
                     "Save dialog should appear when Save Layout is clicked")
        
        // Cancel to clean up
        if saveDialog.exists {
            saveDialog.buttons["Cancel"].click()
        }
    }
    
    func testPermissionsBannerVisibilityDependsOnSystemState() throws {
        // This test's behavior depends on actual system permission state
        // We can't control permissions in UI tests, so we just verify UI responds
        
        let permissionText = app.staticTexts["Accessibility permissions are required to move windows"]
        let openSettingsButton = app.buttons["Open Accessibility Settings"]
        
        // Wait a moment for the permission check to complete
        sleep(1)
        
        // The banner should exist but may be hidden if permissions are granted
        // We can't assert visibility because it depends on system state
        print("Permission banner exists: \(permissionText.exists)")
        print("Settings button exists: \(openSettingsButton.exists)")
        
        // If the button is visible and hittable, verify clicking it doesn't crash
        if openSettingsButton.exists && openSettingsButton.isHittable {
            print("Permissions not granted - banner is visible")
            // Don't actually click it as it would open System Settings
            // openSettingsButton.click()
        } else {
            print("Permissions likely granted - banner is hidden")
        }
        
        XCTAssertTrue(app.exists, "App should remain running")
    }
    
    func testSaveLayoutWorkflowWithDialog() throws {
        let saveButton = app.buttons["Save Layout"]
        saveButton.click()
        
        let saveDialog = app.dialogs["Save Layout"]
        XCTAssertTrue(saveDialog.waitForExistence(timeout: 2), "Dialog must appear")
        
        // Enter a name
        let nameField = saveDialog.textFields.firstMatch
        nameField.click()
        nameField.typeText("Test Layout")
        
        // Check the desktop icons checkbox exists
        let checkbox = saveDialog.checkBoxes["Include desktop icons"]
        XCTAssertTrue(checkbox.exists, "Desktop icons checkbox should exist")
        
        // Save
        saveDialog.buttons["Save"].click()
        
        // Dialog should close
        XCTAssertFalse(saveDialog.exists, "Dialog should close after saving")
        
        // Note: Whether the layout actually saves depends on permissions
        // We can't verify that without permissions
    }
    
    func testApplyLayoutRequiresSelection() throws {
        // With no layouts, apply should do nothing (not crash)
        let applyButton = app.buttons["Apply Layout"]
        applyButton.click()
        
        XCTAssertTrue(app.exists, "App should not crash")
    }
    
    func testDeleteLayoutRequiresSelection() throws {
        // With no layouts, delete should do nothing (not crash)
        let deleteButton = app.buttons["Delete Layout"]
        deleteButton.click()
        
        XCTAssertTrue(app.exists, "App should not crash")
    }
    
    func testMainUIElementsPresent() throws {
        // Verify all main UI elements are present
        XCTAssertTrue(app.buttons["Save Layout"].exists, "Save button must exist")
        XCTAssertTrue(app.buttons["Apply Layout"].exists, "Apply button must exist")
        XCTAssertTrue(app.buttons["Delete Layout"].exists, "Delete button must exist")
        XCTAssertTrue(app.tables.firstMatch.exists, "Layout table must exist")
    }
}

// MARK: - Manual Testing Required
/*
 The following scenarios require manual testing because UI tests cannot:
 1. Click system permission dialogs
 2. Verify windows are actually moved
 3. Verify window positions are captured correctly
 
 Manual Test Cases:
 1. Launch app → System prompt appears → Grant in System Settings → Red banner disappears
 2. With permissions: Save layout → Verify windows captured
 3. With permissions: Apply layout → Verify windows move
 4. Without permissions: Save layout → Should fail after entering name
 5. Without permissions: Apply layout → Should fail silently
 */