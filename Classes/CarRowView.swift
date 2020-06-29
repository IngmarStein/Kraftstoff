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
	var car: Car

	var body: some View {
    NavigationLink(destination: FuelEventsView(car: car)) {
		VStack {
			HStack {
				Text(car.ksName)
					.foregroundColor(Color(.label))
					.frame(maxWidth: .infinity, alignment: .leading)
					.font(.title)
				Text("TODO")
					.foregroundColor(Color(.label))
					.frame(maxWidth: .infinity, alignment: .trailing)
					.font(.title)
			}
			HStack {
				Text(car.ksNumberPlate)
					.foregroundColor(Color(.highlightedText))
					.frame(maxWidth: .infinity, alignment: .leading)
					.font(.body)
				Text(Formatters.shortMeasurementFormatter.string(from: car.ksFuelConsumptionUnit))
					.foregroundColor(Color(.highlightedText))
					.frame(maxWidth: .infinity, alignment: .trailing)
					.font(.body)
			}
		}
    }
  }
}

struct CarRowView_Previews: PreviewProvider {
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
