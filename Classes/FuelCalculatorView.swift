//
//  FuelCalculatorView.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 12.06.19.
//  Copyright © 2019 Ingmar Stein. All rights reserved.
//

import SwiftUI
import Combine

struct FuelCalculatorView : View {
	/*@ObjectBinding */var cars: [CarViewModel]
	@State var date: Date
	@State var car: CarViewModel?
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
			Section {
				if cars.count > 1 {
					Picker(selection: .constant(1), label: Text("Car")) {
						ForEach(cars.identified(by: \.identifier)) { car in
							Text("test").tag(1)
						}
					}
				}
				DatePicker($date) {
					Text("Date")
				}
				TextField("Distance", text: .constant(""))
				TextField("Price", text: .constant(""))
				TextField("Amount", text: .constant(""))
				Toggle(isOn: $filledUp) {
					Text("Fill-up")
				}
			}
			// TODO: make conditional on !isEditing && filledUp && distance > 0 && fuelVolume > 0
			Section {
				Text("cost") + Text("/") + Text("currency") + Text("consumption") + Text("unit")
			}
		}
		.onAppear { self.userActivity.becomeCurrent() }
		.onDisappear { self.userActivity.resignCurrent() }
    }

	func save() {
		let managedCar: Car? = DataManager.managedObjectForModelIdentifier(car!.identifier)
		DataManager.addToArchive(car: managedCar!,
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

#if DEBUG
struct FuelCalculatorView_Previews : PreviewProvider {
    static var previews: some View {
		FuelCalculatorView(cars: [previewCar, previewCar],
						   date: Date(),
						   lastChangeDate: Date())
    }
}
#endif
