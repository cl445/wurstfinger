//
//  wurstfingerUITestsLaunchTests.swift
//  wurstfingerUITests
//
//  Created by Claas Flint on 24.10.25.
//

import XCTest

final class wurstfingerUITestsLaunchTests: XCTestCase {
    override static var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        try UITestApp.skipUnlessGeneratingScreenshots()
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() {
        let app = UITestApp.make()
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
