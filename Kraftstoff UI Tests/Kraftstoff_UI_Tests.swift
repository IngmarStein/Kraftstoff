//
//  Kraftstoff_UI_Tests.swift
//  Kraftstoff UI Tests
//
//  Created by Ingmar Stein on 17.01.16.
//
//

import XCTest

class Kraftstoff_UI_Tests: XCTestCase {
        
    override func setUp() {
        super.setUp()
        
		continueAfterFailure = false

		let app = XCUIApplication()
		setupSnapshot(app)
		app.launchArguments += ["-STARTFRESH"]
		app.launch()

		XCUIDevice.sharedDevice().orientation = .Portrait
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testSnapshots() {

		let app = XCUIApplication()
		let tabBarsQuery = app.tabBars

		// start by adding the demo car

		tabBarsQuery.buttons.elementBoundByIndex(1).tap() // Cars
		app.navigationBars.buttons["add"].tap()

		let tablesQuery = app.tables

		let nameField = tablesQuery.textFields["name"]
		nameField.tap()
		nameField.typeText("apple")

		let plateField = tablesQuery.textFields["plate"]
		plateField.tap()
		plateField.typeText("demo")

		app.navigationBars.buttons["done"].tap()

		snapshot("02_cars")

		tablesQuery.cells.elementBoundByIndex(0).tap()

		snapshot("03_fuelevents")

		XCUIDevice.sharedDevice().orientation = .LandscapeLeft

		let imagesQuery = app.images
		let button = imagesQuery.buttons["5Y"]
		button.tap()

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.6 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
			snapshot("04_chart_cost")
		}

		imagesQuery["graphImage"].coordinateWithNormalizedOffset(CGVector(dx: 0.535, dy: 0.2)).pressForDuration(2.0)

		//app.pageIndicators.elementBoundByIndex(0).tap()
		let scrollView = app.scrollViews.elementBoundByIndex(0)
		let startCoordinate = scrollView.coordinateWithNormalizedOffset(CGVector(dx: 0.8, dy: 0.2))
		let endCoordinate = scrollView.coordinateWithNormalizedOffset(CGVector(dx: 0.2, dy: 0.2))
		startCoordinate.pressForDuration(0.2, thenDragToCoordinate: endCoordinate)

		snapshot("05_chart_fuel")
		
		XCUIDevice.sharedDevice().orientation = .Portrait

		tabBarsQuery.buttons.elementBoundByIndex(0).tap() // Fill-Up

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
			volumeTextField.typeText("7450")
		} else {
			volumeTextField.typeText("2651")
		}

		app.navigationBars.buttons["done"].tap()

		snapshot("01_entry")
    }
    
}
