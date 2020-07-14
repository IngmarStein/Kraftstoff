//
//  Kraftstoff_Tests.swift
//  Kraftstoff Tests
//
//  Created by Ingmar Stein on 07.05.15.
//
//

import XCTest
import CoreData
@testable import Kraftstoff

class KraftstoffTests: XCTestCase {

  private func roundtrip(_ language: String) {
    let managedObjectContext = DataManager.managedObjectContext
    let car = Car(context: managedObjectContext)

    car.order = 0
    car.timestamp = Date()
    car.name = "Lightning McQueen"
    car.numberPlate = "95"
    car.ksOdometerUnit = .kilometers
    car.odometer = 1000
    car.ksFuelUnit = .liters
    car.ksFuelConsumptionUnit = .litersPer100Kilometers

    car.addDemoEvents(inContext: managedObjectContext)

    let fuelEvents = car.allFuelEvents
    let csvString = CSVExporter.exportFuelEvents(fuelEvents, forCar: car, language: language)

    var numCars   = 0
    var numEvents = 0
    let url = URL(fileURLWithPath: "LightningMcQueen__95.csv", isDirectory: false)

    let importer = CSVImporter()
    let success = importer.`import`(csvString,
      detectedCars: &numCars,
      detectedEvents: &numEvents,
      sourceURL: url,
      inContext: managedObjectContext)

    XCTAssert(success, "import should finish successfully")
    XCTAssert(numCars == 1, "should import one car")
    XCTAssert(numEvents == fuelEvents.count, "should import all fuel events")
  }

  func testLanguages() {
    for language in ["en", "de", "fr", "ja"] {
      roundtrip(language)
    }
  }

    func testCSVExport() {
    let managedObjectContext = DataManager.managedObjectContext
    let car = Car(context: managedObjectContext)

    car.order = 0
    car.timestamp = Date()
    car.name = "Lightning McQueen"
    car.numberPlate = "95"
    car.ksOdometerUnit = .kilometers
    car.odometer = 1000
    car.ksFuelUnit = .liters
    car.ksFuelConsumptionUnit = .litersPer100Kilometers

    car.addDemoEvents(inContext: managedObjectContext)

    let fuelEvents = car.allFuelEvents
    let csvString = CSVExporter.exportFuelEvents(fuelEvents, forCar: car)

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
      sourceURL: url,
      inContext: DataManager.managedObjectContext)

    XCTAssert(success, "import should finish successfully")
    XCTAssert(numCars == 1, "should import one car")
    XCTAssert(numEvents == 1, "should import one fuel event")
    }

}
