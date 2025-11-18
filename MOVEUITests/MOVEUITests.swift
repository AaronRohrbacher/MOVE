import XCTest

final class MOVEUITests: XCTestCase {
    
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
    
    private func saveLayoutWithName(_ name: String, includeDesktopIcons: Bool = false) {
        var saveButton = app.buttons["SaveCurrentLayoutButton"]
        if !saveButton.exists {
            saveButton = app.buttons["Save Current Layout"]
        }
        XCTAssertTrue(saveButton.exists, "Save button should exist")
        saveButton.click()
        
        let mainWindow = app.windows["MOVE"]
        var dialogWindow = app.windows["SaveLayoutWindow"]
        if !dialogWindow.exists {
            dialogWindow = mainWindow.sheets.firstMatch
        }
        XCTAssertTrue(dialogWindow.exists, "Save Layout window should appear")
        
        let nameField = app.textFields["SaveLayoutNameField"]
        XCTAssertTrue(nameField.exists, "Name field should exist")
        nameField.click()
        nameField.typeKey("a", modifierFlags: .command)
        nameField.typeText(name)
        
        if includeDesktopIcons {
            let checkbox = app.checkBoxes["SaveLayoutCheckbox"]
            XCTAssertTrue(checkbox.exists, "Checkbox should exist")
            if checkbox.value as? Int == 0 {
                checkbox.click()
            }
        }
        
        let saveDialogButton = app.buttons["SaveLayoutSaveButton"]
        if !saveDialogButton.exists {
            let saveBtn = dialogWindow.buttons["Save"]
            XCTAssertTrue(saveBtn.exists, "Save button should exist")
            saveBtn.click()
        } else {
            saveDialogButton.click()
        }
        
        XCTAssertFalse(dialogWindow.exists, "Dialog should close after saving")
    }
    
    private func verifyLayoutInTable(_ name: String) -> Bool {
        let table = app.tables.firstMatch
        guard table.exists else { return false }
        
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", name)
        let cell = table.cells.matching(predicate).firstMatch
        return cell.exists
    }
    
    private func selectLayoutInTable(_ name: String) -> Bool {
        let table = app.tables.firstMatch
        guard table.exists else { return false }
        
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", name)
        let cell = table.cells.matching(predicate).firstMatch
        
        if cell.exists {
            cell.click()
            return true
        }
        return false
    }
    
    func testAppLaunchesWithRequiredElements() throws {
        let window = app.windows["MOVE"]
        XCTAssertTrue(window.exists, "Main window should exist")
        
        var saveButton = app.buttons["SaveCurrentLayoutButton"]
        if !saveButton.exists {
            saveButton = app.buttons["Save Current Layout"]
        }
        XCTAssertTrue(saveButton.exists, "Save Current Layout button should exist")
        
        var applyButton = app.buttons["ApplyLayoutButton"]
        if !applyButton.exists {
            applyButton = app.buttons["Apply Layout"]
        }
        XCTAssertTrue(applyButton.exists, "Apply Layout button should exist")
        
        var deleteButton = app.buttons["DeleteLayoutButton"]
        if !deleteButton.exists {
            deleteButton = app.buttons["Delete Layout"]
        }
        XCTAssertTrue(deleteButton.exists, "Delete Layout button should exist")
        
        XCTAssertTrue(app.tables.firstMatch.exists, "Table view should exist")
    }
    
    func testSaveLayoutCreatesEntry() throws {
        saveLayoutWithName("Test Layout 1")
        
        XCTAssertTrue(verifyLayoutInTable("Test Layout 1"), "Saved layout should appear in table")
    }
    
    func testSaveMultipleLayouts() throws {
        saveLayoutWithName("Layout A")
        saveLayoutWithName("Layout B")
        saveLayoutWithName("Layout C")
        
        XCTAssertTrue(verifyLayoutInTable("Layout A"), "Layout A should be in table")
        XCTAssertTrue(verifyLayoutInTable("Layout B"), "Layout B should be in table")
        XCTAssertTrue(verifyLayoutInTable("Layout C"), "Layout C should be in table")
    }
    
    func testSaveLayoutWithDesktopIcons() throws {
        saveLayoutWithName("Desktop Icons Layout", includeDesktopIcons: true)
        
        XCTAssertTrue(verifyLayoutInTable("Desktop Icons Layout"), "Layout with desktop icons should be saved")
    }
    
    func testCancelSaveDialog() throws {
        var saveButton = app.buttons["SaveCurrentLayoutButton"]
        if !saveButton.exists {
            saveButton = app.buttons["Save Current Layout"]
        }
        XCTAssertTrue(saveButton.exists)
        saveButton.click()
        
        let mainWindow = app.windows["MOVE"]
        let sheet = mainWindow.sheets.firstMatch
        XCTAssertTrue(sheet.exists)
        
        let cancelButton = sheet.buttons["Cancel"]
        if !cancelButton.exists {
            let cancelBtn = app.buttons["SaveLayoutCancelButton"]
            XCTAssertTrue(cancelBtn.exists)
            cancelBtn.click()
        } else {
            cancelButton.click()
        }
        
        XCTAssertFalse(sheet.exists)
    }
    
    func testApplyLayoutButtonEnabledWhenLayoutSelected() throws {
        saveLayoutWithName("Apply Test Layout")
        
        let applyButton = app.buttons["Apply Layout"]
        
        XCTAssertTrue(selectLayoutInTable("Apply Test Layout"), "Should select layout")
        
        XCTAssertTrue(applyButton.exists)
        XCTAssertTrue(applyButton.isEnabled, "Apply button should be enabled when layout selected")
    }
    
    func testApplyLayout() throws {
        saveLayoutWithName("Layout to Apply")
        
        XCTAssertTrue(selectLayoutInTable("Layout to Apply"))
        
        let applyButton = app.buttons["Apply Layout"]
        XCTAssertTrue(applyButton.exists)
        applyButton.click()
        
        XCTAssertTrue(app.exists, "App should remain running after apply")
    }
    
    func testDeleteLayout() throws {
        saveLayoutWithName("Keep This Layout")
        saveLayoutWithName("Delete This Layout")
        
        XCTAssertTrue(verifyLayoutInTable("Keep This Layout"))
        XCTAssertTrue(verifyLayoutInTable("Delete This Layout"))
        
        XCTAssertTrue(selectLayoutInTable("Delete This Layout"))
        
        let deleteButton = app.buttons["Delete Layout"]
        XCTAssertTrue(deleteButton.exists)
        deleteButton.click()
        
        XCTAssertTrue(verifyLayoutInTable("Keep This Layout"), "Kept layout should still exist")
        XCTAssertFalse(verifyLayoutInTable("Delete This Layout"), "Deleted layout should be gone")
    }
    
    func testDeleteAllLayouts() throws {
        saveLayoutWithName("Layout 1")
        saveLayoutWithName("Layout 2")
        
        XCTAssertTrue(selectLayoutInTable("Layout 2"))
        app.buttons["Delete Layout"].click()
        
        XCTAssertTrue(selectLayoutInTable("Layout 1"))
        app.buttons["Delete Layout"].click()
        
        let table = app.tables.firstMatch
        let cellCount = table.cells.count
        XCTAssertEqual(cellCount, 0, "Table should be empty after deleting all layouts")
    }
    
    func testTableSelection() throws {
        saveLayoutWithName("First Layout")
        saveLayoutWithName("Second Layout")
        
        XCTAssertTrue(selectLayoutInTable("First Layout"))
        
        XCTAssertTrue(selectLayoutInTable("Second Layout"))
        
        XCTAssertTrue(verifyLayoutInTable("First Layout"))
        XCTAssertTrue(verifyLayoutInTable("Second Layout"))
    }
    
    func testDesktopIconCheckboxToggle() throws {
        var saveButton = app.buttons["SaveCurrentLayoutButton"]
        if !saveButton.exists {
            saveButton = app.buttons["Save Current Layout"]
        }
        XCTAssertTrue(saveButton.exists)
        saveButton.click()
        
        let mainWindow = app.windows["MOVE"]
        let sheet = mainWindow.sheets.firstMatch
        XCTAssertTrue(sheet.exists)
        
        var checkbox = app.checkBoxes["SaveLayoutCheckbox"]
        if !checkbox.exists {
            checkbox = sheet.checkBoxes["Include desktop icons"]
        }
        XCTAssertTrue(checkbox.exists, "Checkbox should exist")
        
        let initialValue = checkbox.value as? Int ?? 1
        XCTAssertEqual(initialValue, 0, "Checkbox should be unchecked by default")
        
        checkbox.click()
        let checkedValue = checkbox.value as? Int ?? 0
        XCTAssertEqual(checkedValue, 1, "Checkbox should be checked after click")
        
        checkbox.click()
        let uncheckedValue = checkbox.value as? Int ?? 1
        XCTAssertEqual(uncheckedValue, 0, "Checkbox should be unchecked after second click")
        
        let cancelButton = sheet.buttons["Cancel"]
        if !cancelButton.exists {
            app.buttons["SaveLayoutCancelButton"].click()
        } else {
            cancelButton.click()
        }
        XCTAssertFalse(sheet.exists)
    }
    
    func testFullCRUDFlow() throws {
        saveLayoutWithName("CRUD Test Layout", includeDesktopIcons: true)
        XCTAssertTrue(verifyLayoutInTable("CRUD Test Layout"), "Layout should be created")
        
        XCTAssertTrue(selectLayoutInTable("CRUD Test Layout"), "Should be able to select layout")
        
        let applyButton = app.buttons["Apply Layout"]
        XCTAssertTrue(applyButton.isEnabled, "Apply button should be enabled")
        applyButton.click()
        
        XCTAssertTrue(selectLayoutInTable("CRUD Test Layout"), "Should reselect for deletion")
        app.buttons["Delete Layout"].click()
        
        XCTAssertFalse(verifyLayoutInTable("CRUD Test Layout"), "Layout should be deleted")
    }
}