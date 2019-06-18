//
//  CarRowView.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 13.06.19.
//  Copyright © 2019 Ingmar Stein. All rights reserved.
//

import SwiftUI
import CoreData

struct CarRowView : View {
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
let previewCar: Car = {
	let car = Car(context: DataManager.managedObjectContext)
	car.name = "SLS IO 101"
	car.numberPlate = "Toyota IQ+"
	car.ksFuelConsumptionUnit = .litersPer100Kilometers
	car.ksDistanceTotalSum = 100
	car.ksFuelVolumeTotalSum = 4.7
	return car
}()

struct CarRowView_Previews : PreviewProvider {
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
		}
    }
}
#endif
