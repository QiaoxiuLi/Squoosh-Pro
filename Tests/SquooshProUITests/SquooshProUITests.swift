import XCTest

final class SquooshProUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--use-generated-fixtures"]
        app.launch()
    }

    func testEmptyWorkspaceAndNavigationHaveStableIdentifiers() {
        XCTAssertTrue(app.buttons["empty.chooseImages"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["empty.chooseFolder"].exists)
        XCTAssertTrue(app.buttons["toolbar.addImages"].exists)
        XCTAssertTrue(app.outlines.staticTexts["压缩"].exists || app.staticTexts["压缩"].exists)
    }

    func testAdvancedSettingsCanExpand() {
        XCTAssertTrue(app.disclosureTriangles["settings.advanced"].waitForExistence(timeout: 3))
        app.disclosureTriangles["settings.advanced"].click()
        XCTAssertTrue(app.staticTexts["色彩空间"].exists)
    }
}
