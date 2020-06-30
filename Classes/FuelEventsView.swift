//
//  FuelEventsView.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 29.06.20.
//  Copyright © 2020 Ingmar Stein. All rights reserved.
//

import CoreData
import SwiftUI

struct FuelEventsView: View {
	@Environment(\.managedObjectContext) var managedObjectContext

	var selectedCarId: String?
	let selectedCar: Car

	@FetchRequest
	var fuelEvents: FetchedResults<FuelEvent>

  init(car: Car) {
    selectedCar = car
		let fetchRequest = DataManager.fetchRequestForEvents(car: car, afterDate: nil, dateMatches: true)
		_fuelEvents = FetchRequest(fetchRequest: fetchRequest, animation: nil)
	}

	var body: some View {
		List {
			ForEach(fuelEvents, id: \.objectID) {
				FuelEventRowView(fuelEvent: $0)
      }.onDelete(perform: deleteFuelEvents)
		}
    .navigationBarTitle(Text(selectedCar.ksName), displayMode: .inline)
    .navigationBarItems(trailing:
      HStack {
        Button(action: { showStatistics() }) {
          Image(systemName: "chart.bar")
        }
        Button(action: { showStatistics() }) {
          Image(systemName: "square.and.arrow.up")
        }
      }
    )
  }

  func deleteFuelEvents(at offsets: IndexSet) {
    offsets.forEach { index in
      DataManager.removeEvent(self.fuelEvents[index], forceOdometerUpdate: false)
    }
    DataManager.saveContext()
  }

  private var exportFilename: String {
    let rawFilename = "\(selectedCar.ksName)__\(selectedCar.ksNumberPlate).csv"
    let illegalCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>")

    return rawFilename.components(separatedBy: illegalCharacters).joined(separator: "")
  }

  private var exportURL: URL {
    return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(exportFilename)
  }

  func exportTextData() -> Data {
    let csvString = CSVExporter.exportFuelEvents(fuelEvents, forCar: selectedCar)
    return csvString.data(using: String.Encoding.utf8, allowLossyConversion: true)!
  }

  private func exportTextDescription() -> String {
    let outputFormatter = DateFormatter()

    outputFormatter.dateStyle = .medium
    outputFormatter.timeStyle = .none

    let eventCount = fuelEvents.count
    let last = fuelEvents.last
    let first = fuelEvents.first

    let period: String
    switch eventCount {
    case 0: period = NSLocalizedString("", comment: "")
    case 1: period = String(format: NSLocalizedString("on %@", comment: ""), outputFormatter.string(from: last!.ksTimestamp))
    default: period = String(format: NSLocalizedString("in the period from %@ to %@", comment: ""), outputFormatter.string(from: last!.ksTimestamp), outputFormatter.string(from: first!.ksTimestamp))
    }

    let count = String(format: NSLocalizedString(((eventCount == 1) ? "%d item" : "%d items"), comment: ""), eventCount)

    return String(format: NSLocalizedString("Here are your exported fuel data sets for %@ (%@) %@ (%@):\n", comment: ""),
            selectedCar.ksName,
            selectedCar.ksNumberPlate,
            period,
            count)
  }

  func showStatistics() {
  }
}

struct FuelEventsView_Previews: PreviewProvider {
  static var container: NSPersistentContainer {
    return DataManager.previewContainer
  }

  static var previewCar: Car = {
    let car = Car(context: container.viewContext)
    car.distanceTotalSum = 100
    car.ksFuelConsumptionUnit = .litersPer100Kilometers
    car.ksFuelUnit = .liters
    car.ksFuelVolumeTotalSum = 100
    car.name = "Toyota IQ+"
    car.numberPlate = "SLS IO 101"
    car.odometer = 42
    car.ksOdometerUnit = .kilometers
    car.order = 0
    car.timestamp = Date()
    try! container.viewContext.save()
    return car
  }()

  static var previews: some View {
    FuelEventsView(car: previewCar)
  }
}
