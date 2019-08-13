//
//  CarsView.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 13.06.19.
//  Copyright © 2019 Ingmar Stein. All rights reserved.
//

import SwiftUI
import CoreData

struct CarsView: View {
	//@Environment(\.managedObjectContext) var managedObjectContext
	@FetchRequest(fetchRequest: DataManager.fetchRequestForCars(), animation: nil) var cars: FetchedResults<Car>

    var body: some View {
		List(cars, id: \.objectID) { car in
			CarRowView(car: car)
		}
    }
}

#if DEBUG
// swiftlint:disable:next type_name
struct CarsView_Previews: PreviewProvider {
	static var container: NSPersistentContainer {
		let container = NSPersistentContainer(name: "Fuel")
		guard let description = container.persistentStoreDescriptions.first else {
			fatalError("Could not retrieve a persistent store description.")
		}
		description.type = NSInMemoryStoreType
		return container
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
		CarsView(cars: FetchRequest<Car>(fetchRequest: DataManager.fetchRequestForCars()))
    }
}
#endif
