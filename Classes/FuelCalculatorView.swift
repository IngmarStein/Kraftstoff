//
//  FuelCalculatorView.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 12.06.19.
//  Copyright © 2019 Ingmar Stein. All rights reserved.
//

import SwiftUI
import Combine
import CoreData

struct FuelCalculatorView: View {
	@Environment(\.managedObjectContext) var managedObjectContext
	@FetchRequest(fetchRequest: DataManager.fetchRequestForCars(), animation: nil) var cars: FetchedResults<Car>
	@State var date: Date
	@State var car: Car?
	@State var lastChangeDate: Date
	@State var distance = Decimal.zero
	@State var price = Decimal.zero
	@State var fuelVolume = Decimal.zero
	@State var filledUp = false
	@State var comment = ""

	let userActivity: NSUserActivity = {
		let activity = NSUserActivity(activityType: "com.github.ingmarstein.kraftstoff.fillup")
		activity.title = NSLocalizedString("Fill-Up", comment: "")
		activity.keywords = [ NSLocalizedString("Fill-Up", comment: "") ]
		activity.isEligibleForSearch = true
		activity.isEligibleForPrediction = true
		return activity
	}()

	// TODO: make conditional on !isEditing && filledUp && distance > 0 && fuelVolume > 0
	/*
	var showConsumption: AnyPublisher<Bool, Never> {
		return Publishers.CombineLatest3($filledUp, $distance, $fuelVolume) { filledUp, distance, fuelVolume in
			return filledUp && distance > 0 && fuelVolume > 0
		}.eraseToAnyPublisher()
	}
	*/

    var body: some View {
		Form {
			// FIXME: the compiler is unable to type-check this expression in reasonable time; try breaking up the expression into distinct sub-expressions
			/*
			Section {
				if cars.count > 1 {
					Picker(selection: .constant(1), label: Text("Car")) {
						ForEach(cars, id: \.identifier) { car in
							Text("test").tag(1)
						}
					}
				}
				DatePicker("Date", selection: $date)
				TextField("Distance", text: .constant(""))
				TextField("Price", text: .constant(""))
				TextField("Amount", text: .constant(""))
				Toggle("Fill-up", isOn: $filledUp)
			}
			*/
			// TODO: make conditional on !isEditing && filledUp && distance > 0 && fuelVolume > 0
			Section {
				Text("cost") + Text("/") + Text("currency") + Text("consumption") + Text("unit")
			}
		}
		.onAppear { self.userActivity.becomeCurrent() }
		.onDisappear { self.userActivity.resignCurrent() }
    }

	func save() {
		DataManager.addToArchive(car: car!,
								 date: date,
								 distance: distance,
								 price: price,
								 fuelVolume: fuelVolume,
								 filledUp: filledUp,
								 comment: comment,
								 forceOdometerUpdate: false)

		DataManager.saveContext()

		// Reset table
		distance = 0
		price = 0
		fuelVolume = 0
		filledUp = true
		comment = ""
	}
}

struct FuelCalculatorView_Previews: PreviewProvider {
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
		FuelCalculatorView(cars: FetchRequest<Car>(fetchRequest: DataManager.fetchRequestForCars()),
						   date: Date(),
						   lastChangeDate: Date())
    }
}
