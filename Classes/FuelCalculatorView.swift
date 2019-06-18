//
//  FuelCalculatorView.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 12.06.19.
//  Copyright © 2019 Ingmar Stein. All rights reserved.
//

import SwiftUI

struct FuelCalculatorView : View {
	/*@ObjectBinding */var cars: [Car]
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

    var body: some View {
		Form {
			Section {
				//if cars.count > 1 {
					Picker(selection: .constant(1), label: Text("Car")) {
						ForEach(cars.identified(by: \.objectID)) { car in
							Text("car").tag(1)
						}
					}
				//}
				DatePicker($date) {
					Text("Date")
				}
				HStack {
					Text("Distance")
					Spacer()
					TextField(.constant("Placeholder"))
				}
				HStack {
					Text("Price")
					Spacer()
					TextField(.constant("Placeholder"))
				}
				HStack {
					Text("Amount")
					Spacer()
					TextField(.constant("Placeholder"))
				}
				Toggle(isOn: $filledUp) {
					Text("Fill-up")
				}
			}
			// TODO: make conditional on !isEditing && filledUp && distance > 0 && fuelVolume > 0
			Section {
				Text("Consumption")
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

#if DEBUG
struct FuelCalculatorView_Previews : PreviewProvider {
    static var previews: some View {
		FuelCalculatorView(cars: [previewCar, previewCar],
						   date: Date(),
						   lastChangeDate: Date())
    }
}
#endif
