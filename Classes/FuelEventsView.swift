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
			}
		}
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
