//
//  Kraftstoff_UI_Tests.swift
//  Kraftstoff UI Tests
//
//  Created by Ingmar Stein on 17.01.16.
//
//

import XCTest

class KraftstoffUITests: XCTestCase {

	private func snapshot(_ name: String) {
		let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
		attachment.lifetime = .keepAlways
		attachment.name = name
		add(attachment)

		// for fastlane
		Snapshot.snapshot(name, timeWaitingForIdle: 20)
	}

  override func setUp() {
    super.setUp()

    continueAfterFailure = false

		let app = XCUIApplication()
		setupSnapshot(app)
		app.launchArguments += ["-STARTFRESH", "-KEEPLENS", "-UNITTEST"]
		app.launch()

		#if !targetEnvironment(macCatalyst)
    XCUIDevice.shared.orientation = .portrait
		#endif
  }

  func testSnapshots() {
		let deviceLanguage = Locale.current.languageCode!
		let app = XCUIApplication()
		let tabBarsQuery = app.tabBars

		// start by adding the demo car

		tabBarsQuery.buttons.element(boundBy: 1).tap() // Cars
		app.navigationBars.buttons["add"].tap()
		app.sheets.buttons.element(boundBy: 0).tap() // New Car

		let tablesQuery = app.tables

		let nameField = tablesQuery.textFields["name"]
		nameField.tap()
		nameField.typeText("apple")

		let plateField = tablesQuery.textFields["plate"]
		plateField.tap()
		plateField.typeText("demo")

		app.navigationBars.buttons["done"].tap()

		snapshot("02_cars")

		tablesQuery.cells.element(boundBy: 0).tap()

		snapshot("03_fuelevents")

		app.buttons["Chart"].tap()

		#if !targetEnvironment(macCatalyst)
		XCUIDevice.shared.orientation = .landscapeLeft
		#endif

		let imagesQuery = app.images
		let button = imagesQuery.buttons["5Y"]
		button.tap()

		imagesQuery["graphImage"].coordinate(withNormalizedOffset: CGVector(dx: 0.536, dy: 0.5)).press(forDuration: 0.6)
		snapshot("04_chart_cost")

		// FIXME: find solution for Catalyst
		#if !targetEnvironment(macCatalyst)
		// app.pageIndicators.element(boundBy: 0).tap()
		app.scrollViews.element(boundBy: 0).swipeLeft()
		#endif

		snapshot("05_chart_fuel")

		app.buttons["close"].tap()

		#if !targetEnvironment(macCatalyst)
		XCUIDevice.shared.orientation = .portrait
		#endif

		tabBarsQuery.buttons.element(boundBy: 0).tap() // Fill-Up

		let distanceTextField = tablesQuery.textFields["distance"]
		distanceTextField.tap()
		if deviceLanguage == "en" {
			distanceTextField.typeText("3973")
		} else {
			distanceTextField.typeText("6260")
		}

		let priceTextField = tablesQuery.textFields["price"]
		priceTextField.tap()
		if deviceLanguage == "en" {
			priceTextField.typeText("5259")
		} else {
			priceTextField.typeText("1359")
		}

		let volumeTextField = tablesQuery.textFields["fuelVolume"]
		volumeTextField.tap()
		if deviceLanguage == "en" {
			volumeTextField.typeText("7450\n")
		} else {
			volumeTextField.typeText("2651\n")
		}

		app.navigationBars.buttons["done"].tap()

		snapshot("01_entry")
  }

}
