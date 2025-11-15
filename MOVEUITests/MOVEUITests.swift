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
        try super.setUpWithError()
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments.append("--clear-user-defaults")
        app.launch()
        
        
        // Wait for app to fully load
        let window = app.windows["MOVE"]
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Main window should exist")
    }
    
    override func tearDownWithError() throws {
        if app != nil {
            app.terminate()
        }
        app = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Helper Methods
    
    private func saveLayoutWithName(_ name: String, includeDesktopIcons: Bool = false) {
        // Click Save Current Layout button
        let saveButton = app.buttons["Save Current Layout"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.click()
        
        // Wait for NSAlert modal to appear - it shows as a sheet
        let sheet = app.sheets["Save Layout"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 3), "Save Layout sheet should appear")
        
        // The text field is the initial first responder, so we can type directly
        // But first clear any existing text
        app.typeKey("a", modifierFlags: .command) // Select all
        app.typeText(name)
        
        // Toggle desktop icons if requested
        if includeDesktopIcons {
            let checkbox = sheet.checkBoxes["Include desktop icons"]
            if checkbox.waitForExistence(timeout: 1) {
                checkbox.click()
            }
        }
        
        // Click Save button in the sheet
        let saveDialogButton = sheet.buttons["Save"]
        XCTAssertTrue(saveDialogButton.waitForExistence(timeout: 2), "Save button should exist in sheet")
        saveDialogButton.click()
        
        // Wait for sheet to close
        XCTAssertFalse(sheet.waitForExistence(timeout: 2), "Sheet should close after saving")
    }
    
    private func verifyLayoutInTable(_ name: String) -> Bool {
        let table = app.tables.firstMatch
        guard table.waitForExistence(timeout: 2) else { return false }
        
        // Look for the layout in the table
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", name)
        let cell = table.cells.matching(predicate).firstMatch
        return cell.waitForExistence(timeout: 2)
    }
    
    private func selectLayoutInTable(_ name: String) -> Bool {
        let table = app.tables.firstMatch
        guard table.waitForExistence(timeout: 2) else { return false }
        
        // Find and click the layout
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", name)
        let cell = table.cells.matching(predicate).firstMatch
        
        if cell.waitForExistence(timeout: 2) {
            cell.click()
            return true
        }
        return false
    }
    
    // MARK: - App Launch Tests
    
    func testAppLaunchesWithRequiredElements() throws {
        // Verify main window
        let window = app.windows["MOVE"]
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Main window should exist")
        
        // Verify essential buttons - wait for them to appear
        XCTAssertTrue(app.buttons["Save Current Layout"].waitForExistence(timeout: 3), "Save Current Layout button should exist")
        XCTAssertTrue(app.buttons["Apply Layout"].waitForExistence(timeout: 3), "Apply Layout button should exist")
        XCTAssertTrue(app.buttons["Delete Layout"].waitForExistence(timeout: 3), "Delete Layout button should exist")
        
        // Verify table exists
        XCTAssertTrue(app.tables.firstMatch.waitForExistence(timeout: 3), "Table view should exist")
    }
    
    // MARK: - Save Layout Tests
    
    func testSaveLayoutCreatesEntry() throws {
        // Save a layout
        saveLayoutWithName("Test Layout 1")
        
        // Verify it appears in the table
        XCTAssertTrue(verifyLayoutInTable("Test Layout 1"), "Saved layout should appear in table")
    }
    
    func testSaveMultipleLayouts() throws {
        // Save multiple layouts
        saveLayoutWithName("Layout A")
        saveLayoutWithName("Layout B")
        saveLayoutWithName("Layout C")
        
        // Verify all appear in table
        XCTAssertTrue(verifyLayoutInTable("Layout A"), "Layout A should be in table")
        XCTAssertTrue(verifyLayoutInTable("Layout B"), "Layout B should be in table")
        XCTAssertTrue(verifyLayoutInTable("Layout C"), "Layout C should be in table")
    }
    
    func testSaveLayoutWithDesktopIcons() throws {
        // Save layout with desktop icons enabled
        saveLayoutWithName("Desktop Icons Layout", includeDesktopIcons: true)
        
        // Verify it appears
        XCTAssertTrue(verifyLayoutInTable("Desktop Icons Layout"), "Layout with desktop icons should be saved")
    }
    
    func testCancelSaveDialog() throws {
        // Open save dialog
        app.buttons["Save Current Layout"].click()
        
        // Wait for sheet
        let sheet = app.sheets["Save Layout"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 3))
        
        // Click Cancel button in sheet
        let cancelButton = sheet.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 2))
        cancelButton.click()
        
        // Sheet should close
        XCTAssertFalse(sheet.waitForExistence(timeout: 2))
    }
    
    // MARK: - Apply Layout Tests
    
    func testApplyLayoutButtonEnabledWhenLayoutSelected() throws {
        // Save a layout first
        saveLayoutWithName("Apply Test Layout")
        
        // Initially Apply button might be disabled
        let applyButton = app.buttons["Apply Layout"]
        
        // Select the layout
        XCTAssertTrue(selectLayoutInTable("Apply Test Layout"), "Should select layout")
        
        // Apply button should be enabled (clickable)
        XCTAssertTrue(applyButton.waitForExistence(timeout: 1))
        XCTAssertTrue(applyButton.isEnabled, "Apply button should be enabled when layout selected")
    }
    
    func testApplyLayout() throws {
        // Save a layout
        saveLayoutWithName("Layout to Apply")
        
        // Select it
        XCTAssertTrue(selectLayoutInTable("Layout to Apply"))
        
        // Click Apply
        let applyButton = app.buttons["Apply Layout"]
        XCTAssertTrue(applyButton.waitForExistence(timeout: 1))
        applyButton.click()
        
        // App should still be running (no crash)
        XCTAssertTrue(app.waitForExistence(timeout: 1), "App should remain running after apply")
    }
    
    // MARK: - Delete Layout Tests
    
    func testDeleteLayout() throws {
        // Save two layouts
        saveLayoutWithName("Keep This Layout")
        saveLayoutWithName("Delete This Layout")
        
        // Verify both exist
        XCTAssertTrue(verifyLayoutInTable("Keep This Layout"))
        XCTAssertTrue(verifyLayoutInTable("Delete This Layout"))
        
        // Select the one to delete
        XCTAssertTrue(selectLayoutInTable("Delete This Layout"))
        
        // Click Delete
        let deleteButton = app.buttons["Delete Layout"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 1))
        deleteButton.click()
        
        // Give time for deletion
        Thread.sleep(forTimeInterval: 0.5)
        
        // Verify deleted layout is gone but other remains
        XCTAssertTrue(verifyLayoutInTable("Keep This Layout"), "Kept layout should still exist")
        XCTAssertFalse(verifyLayoutInTable("Delete This Layout"), "Deleted layout should be gone")
    }
    
    func testDeleteAllLayouts() throws {
        // Save layouts
        saveLayoutWithName("Layout 1")
        saveLayoutWithName("Layout 2")
        
        // Delete Layout 2
        XCTAssertTrue(selectLayoutInTable("Layout 2"))
        app.buttons["Delete Layout"].click()
        Thread.sleep(forTimeInterval: 0.5)
        
        // Delete Layout 1
        XCTAssertTrue(selectLayoutInTable("Layout 1"))
        app.buttons["Delete Layout"].click()
        Thread.sleep(forTimeInterval: 0.5)
        
        // Table should be empty
        let table = app.tables.firstMatch
        let cellCount = table.cells.count
        XCTAssertEqual(cellCount, 0, "Table should be empty after deleting all layouts")
    }
    
    // MARK: - Table View Tests
    
    func testTableSelection() throws {
        // Save multiple layouts
        saveLayoutWithName("First Layout")
        saveLayoutWithName("Second Layout")
        
        // Select first
        XCTAssertTrue(selectLayoutInTable("First Layout"))
        
        // Select second (should deselect first)
        XCTAssertTrue(selectLayoutInTable("Second Layout"))
        
        // Both should exist but only one selected
        XCTAssertTrue(verifyLayoutInTable("First Layout"))
        XCTAssertTrue(verifyLayoutInTable("Second Layout"))
    }
    
    // MARK: - Desktop Icons Tests
    
    func testDesktopIconCheckboxToggle() throws {
        // Open save dialog
        app.buttons["Save Current Layout"].click()
        
        // Wait for sheet
        let sheet = app.sheets["Save Layout"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 3))
        
        // Find checkbox in sheet
        let checkbox = sheet.checkBoxes["Include desktop icons"]
        XCTAssertTrue(checkbox.waitForExistence(timeout: 2), "Checkbox should exist")
        
        // Should be unchecked initially
        let initialValue = checkbox.value as? Bool ?? true
        XCTAssertFalse(initialValue, "Checkbox should be unchecked by default")
        
        // Click to check
        checkbox.click()
        Thread.sleep(forTimeInterval: 0.2)
        let checkedValue = checkbox.value as? Bool ?? false
        XCTAssertTrue(checkedValue, "Checkbox should be checked after click")
        
        // Click to uncheck
        checkbox.click()
        Thread.sleep(forTimeInterval: 0.2)
        let uncheckedValue = checkbox.value as? Bool ?? true
        XCTAssertFalse(uncheckedValue, "Checkbox should be unchecked after second click")
        
        // Cancel dialog
        sheet.buttons["Cancel"].click()
        XCTAssertFalse(sheet.waitForExistence(timeout: 2))
    }
    
    
    // MARK: - Integration Tests
    
    func testFullCRUDFlow() throws {
        // Create
        saveLayoutWithName("CRUD Test Layout", includeDesktopIcons: true)
        XCTAssertTrue(verifyLayoutInTable("CRUD Test Layout"), "Layout should be created")
        
        // Read (select and verify it's there)
        XCTAssertTrue(selectLayoutInTable("CRUD Test Layout"), "Should be able to select layout")
        
        // Update (we can't directly update, but we can apply it)
        let applyButton = app.buttons["Apply Layout"]
        XCTAssertTrue(applyButton.isEnabled, "Apply button should be enabled")
        applyButton.click()
        
        // Delete
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertTrue(selectLayoutInTable("CRUD Test Layout"), "Should reselect for deletion")
        app.buttons["Delete Layout"].click()
        
        // Verify deleted
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertFalse(verifyLayoutInTable("CRUD Test Layout"), "Layout should be deleted")
    }
}