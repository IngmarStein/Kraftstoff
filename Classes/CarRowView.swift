//
//  CarRowView.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 13.06.19.
//  Copyright © 2019 Ingmar Stein. All rights reserved.
//

import SwiftUI
import CoreData

struct CarRowView: View {
	/*@ObjectBinding */var car: Car

	var body: some View {
		VStack {
			HStack {
				Text(car.ksName)
				Text("TODO")
			}
			HStack {
				Text(car.ksNumberPlate)
				Text(Formatters.shortMeasurementFormatter.string(from: car.ksFuelConsumptionUnit))
			}
		}
    }
}

#if DEBUG
struct CarRowView_Previews: PreviewProvider {
	static var container: NSPersistentContainer {
		let objectModel = NSManagedObjectModel(contentsOf: Bundle.main.url(forResource: "Fuel", withExtension: "momd")!)!
		let container = NSPersistentContainer(name: "Fuel", managedObjectModel: objectModel)
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
		Group {
			CarRowView(car: previewCar)
				.environment(\.sizeCategory, .medium)
				.previewLayout(.sizeThatFits)
				.previewDisplayName("medium")
			CarRowView(car: previewCar)
				.environment(\.sizeCategory, .extraLarge)
				.previewLayout(.sizeThatFits)
				.previewDisplayName("extraLarge")
		}.environment(\.managedObjectContext, container.viewContext)
    }
}
#endif
