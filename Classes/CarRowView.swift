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
	/*@ObjectBinding */var car: CarViewModel

	var body: some View {
		VStack {
			HStack {
				Text(car.name)
				Text("TODO")
			}
			HStack {
				Text(car.numberPlate)
				Text(Formatters.shortMeasurementFormatter.string(from: car.fuelConsumptionUnit))
			}
		}
    }
}

#if DEBUG
let previewCar = CarViewModel(distanceTotalSum: 100,
							  fuelConsumptionUnit: .litersPer100Kilometers,
							  fuelUnit: .liters,
						      fuelVolumeTotalSum: 100,
						      identifier: "previewCar",
							  name: "Toyota IQ+",
							  numberPlate: "SLS IO 101",
							  odometer: 42,
							  odometerUnit: .kilometers,
							  order: 0,
							  timestamp: Date())

// swiftlint:disable:next type_name
struct CarRowView_Previews: PreviewProvider {
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
