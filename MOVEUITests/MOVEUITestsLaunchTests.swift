//
//  MOVEUITestsLaunchTests.swift
//  MOVEUITests
//
//  Created by Aaron Rohrbacher on 10/21/25.
//

import XCTest

final class MOVEUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false  // Run once, not multiple times
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Just verify the app launches without crashing
        XCTAssertTrue(app.exists)
    }
}