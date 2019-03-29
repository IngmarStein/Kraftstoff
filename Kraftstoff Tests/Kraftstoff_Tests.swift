//
//  Kraftstoff_Tests.swift
//  Kraftstoff Tests
//
//  Created by Ingmar Stein on 07.05.15.
//
//

import XCTest
import UIKit
import RealmSwift
@testable import kraftstoff

class KraftstoffTests: XCTestCase {

	override func setUp() {
		super.setUp()

		Realm.Configuration.defaultConfiguration = Realm.Configuration(inMemoryIdentifier: "KraftstoffTests")
	}

	private func roundtrip(_ language: String) {
		// swiftlint:disable:next force_try
		let realm = try! Realm()

		let car = Car()
		car.order = 0
		car.timestamp = Date()
		car.name = "Lightning McQueen"
		car.numberPlate = "95"
		car.odometerUnit = .kilometers
		car.odometer = 1000
		car.fuelUnit = .liters
		car.fuelConsumptionUnit = .litersPer100Kilometers

		// swiftlint:disable:next force_try
		try! realm.write {
			realm.add(car)

			car.addDemoEvents()
		}

		let fuelEvents = DataManager.fuelEventsForCar(car: car,
			beforeDate: nil,
			dateMatches: true)

		let csvString = CSVExporter.exportFuelEvents(Array(fuelEvents), forCar: car, language: language)

		var numCars   = 0
		var numEvents = 0
		let url = URL(fileURLWithPath: "LightningMcQueen__95.csv", isDirectory: false)

		let importer = CSVImporter()
		let success = importer.`import`(csvString,
			detectedCars: &numCars,
			detectedEvents: &numEvents,
			sourceURL: url)

		XCTAssert(success, "import should finish successfully")
		XCTAssert(numCars == 1, "should import one car")
		XCTAssert(numEvents == fuelEvents.count, "should import all fuel events")
	}

	func testLanguages() {
		for language in ["en", "de", "fr"] {
			roundtrip(language)
		}
	}

    func testCSVExport() {
		// swiftlint:disable:next force_try
		let realm = try! Realm()

		let car = Car()

		car.order = 0
		car.timestamp = Date()
		car.name = "Lightning McQueen"
		car.numberPlate = "95"
		car.odometerUnit = .kilometers
		car.odometer = 1000
		car.fuelUnit = .liters
		car.fuelConsumptionUnit = .litersPer100Kilometers

		try! realm.write {
			realm.add(car)

			car.addDemoEvents()
		}

		let fuelEvents = DataManager.fuelEventsForCar(car: car,
			beforeDate: nil,
			dateMatches: true)

		let csvString = CSVExporter.exportFuelEvents(Array(fuelEvents), forCar: car)

		XCTAssert(csvString.hasPrefix("yyyy-MM-dd;HH:mm;Kilometers;Liters;Full Fill-Up;Price per Liter;Liters Per 100 Kilometers;Comment\n2017-07-16;16:10;\"626.00\";\"28.43\";Yes;\"1.389\";\"4.54\";\"\"\n"), "CSV data should have the expected prefix")
		XCTAssert(csvString.count == 5473, "CSV data should have the expected size")
    }

    func testCSVImport() {
		let importer = CSVImporter()
		var numCars   = 0
		var numEvents = 0
		let url = URL(fileURLWithPath: "LightningMcQueen__95.csv", isDirectory: false)

		let CSVString = "yyyy-MM-dd;HH:mm;Kilometers;Liters;Full Fill-Up;Price per Liter;Liters per 100 Kilometers\n2013-07-16;18:10;\"626.00\";\"28.43\";Yes;\"1.389\";\"4.54\"\n"
		let success = importer.`import`(CSVString,
			detectedCars: &numCars,
			detectedEvents: &numEvents,
			sourceURL: url)

		XCTAssert(success, "import should finish successfully")
		XCTAssert(numCars == 1, "should import one car")
		XCTAssert(numEvents == 1, "should import one fuel event")
    }

}
