import XCTest

final class PreviewUITests: XCTestCase {
    @MainActor
    func testFullDemoJourney() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-vo1d.autoconnect", "NO", "-vo1d.autoFastest", "YES", "-vo1d.reduceAnimations", "NO"]
        app.launch()
        capture("01-launch", app: app)
        let control = app.buttons["connection.control"]
        XCTAssertTrue(control.waitForExistence(timeout: 8))
        XCTAssertTrue(control.isHittable)
        capture("02-home", app: app)
        control.tap()
        XCTAssertTrue(app.staticTexts["connection.status"].waitForExistence(timeout: 2))
        let connected = NSPredicate(format: "value == %@", "CONNECTED")
        expectation(for: connected, evaluatedWith: control)
        waitForExpectations(timeout: 5)
        capture("03-connected", app: app)
        app.swipeUp()
        capture("04-dashboard", app: app)
        app.buttons["tab.locations"].tap()
        let search = app.textFields["servers.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        capture("05-locations", app: app)
        search.tap(); search.typeText("Russia")
        app.buttons["favorite.RU"].tap()
        app.buttons["server.RU"].tap()
        capture("06-switching", app: app)
        app.buttons["tab.home"].tap()
        expectation(for: connected, evaluatedWith: app.buttons["connection.control"])
        waitForExpectations(timeout: 5)
        app.buttons["connection.control"].tap()
        expectation(for: NSPredicate(format: "value == %@", "READY"), evaluatedWith: app.buttons["connection.control"])
        waitForExpectations(timeout: 4)
        app.buttons["quick.ping"].tap()
        app.buttons["quick.fastest"].tap()
        expectation(for: connected, evaluatedWith: app.buttons["connection.control"])
        waitForExpectations(timeout: 5)
        app.buttons["tab.locations"].tap()
        app.buttons["filter.FAVORITES"].tap()
        XCTAssertTrue(app.buttons["server.RU"].exists)
        app.buttons["tab.profile"].tap()
        XCTAssertTrue(app.textFields["profile.nickname"].waitForExistence(timeout: 3))
        capture("07-profile", app: app)
        app.buttons["profile.avatar"].tap()
        app.buttons["avatar.moon.stars.fill"].tap()
        let settings = app.buttons["profile.settings"]
        if !settings.isHittable { app.swipeUp() }
        settings.tap()
        let settingsScreen = app.descendants(matching: .any)["settings.screen"]
        XCTAssertTrue(settingsScreen.waitForExistence(timeout: 5))
        let autoConnect = app.descendants(matching: .any)["settings.autoConnect"]
        XCTAssertTrue(autoConnect.waitForExistence(timeout: 3))
        capture("08-settings", app: app)
        if autoConnect.isHittable { autoConnect.tap() }
        app.swipeUp()
        let reduceMotion = app.descendants(matching: .any)["settings.reduceMotion"]
        if reduceMotion.exists && reduceMotion.isHittable { reduceMotion.tap() }
        let compactServers = app.descendants(matching: .any)["settings.compactServers"]
        if compactServers.exists && compactServers.isHittable { compactServers.tap() }
        capture("09-interface", app: app)
    }
    @MainActor
    private func capture(_ name: String, app: XCUIApplication) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
}
