//
//  CSVExporter.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 07.05.15.
//
//

import Foundation

final class CSVExporter {

	static func exportFuelEvents(_ fuelEvents: [FuelEvent], forCar car: Car, language: String? = nil) -> String {
		let odometerUnit = car.ksOdometerUnit
		let fuelUnit = car.ksFuelUnit
		let consumptionUnit = car.ksFuelConsumptionUnit

		let bundle: NSBundle
		if let language = language, path = NSBundle.main().pathForResource(language, ofType: "lproj"), localeBundle = NSBundle(path: path) {
			bundle = localeBundle
		} else {
			bundle = NSBundle.main()
		}

		var dataString = String()
		dataString.reserveCapacity(4096)

		dataString += NSLocalizedString("yyyy-MM-dd", bundle: bundle, comment: "")
		dataString += ";"

		dataString += NSLocalizedString("HH:mm", bundle: bundle, comment: "")
		dataString += ";"

		dataString += Units.odometerUnitDescription(odometerUnit, pluralization: true, bundle: bundle)
		dataString += ";"

		dataString += Units.fuelUnitDescription(fuelUnit, discernGallons: true, pluralization: true, bundle: bundle)
		dataString += ";"

		dataString += NSLocalizedString("Full Fill-Up", bundle: bundle, comment: "")
		dataString += ";"

		dataString += Units.fuelPriceUnitDescription(fuelUnit, bundle: bundle)
		dataString += ";"

		dataString += consumptionUnit.description
		dataString += ";"

		dataString += NSLocalizedString("Comment", bundle: bundle, comment: "")
		dataString += "\n"

		let dateFormatter = NSDateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd';'HH:mm"
		dateFormatter.locale = NSLocale.system()
		dateFormatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)

		let numberFormatter = NSNumberFormatter()
		numberFormatter.numberStyle = .decimalStyle
		numberFormatter.locale = NSLocale.current()
		numberFormatter.usesGroupingSeparator = false
		numberFormatter.alwaysShowsDecimalSeparator = true
		numberFormatter.minimumFractionDigits = 2

		for fuelEvent in fuelEvents {
			let timestamp = dateFormatter.string(from: fuelEvent.timestamp)
			let distance = numberFormatter.string(from: Units.distanceForKilometers(fuelEvent.distance, withUnit: odometerUnit))!
			let fuelVolume = numberFormatter.string(from: Units.volumeForLiters(fuelEvent.fuelVolume, withUnit: fuelUnit))!
			let filledUp = fuelEvent.filledUp ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")
			let price = numberFormatter.string(from: Units.pricePerUnit(literPrice: fuelEvent.price, withUnit: fuelUnit))!
			let consumption = fuelEvent.filledUp ? numberFormatter.string(from:
				Units.consumptionForKilometers(fuelEvent.distance + fuelEvent.inheritedDistance,
				                               liters: fuelEvent.fuelVolume + fuelEvent.inheritedFuelVolume,
				                               inUnit: consumptionUnit))!
				: " "
			let comment = fuelEvent.comment ?? ""

			dataString += "\(timestamp);\"\(distance)\";\"\(fuelVolume)\";\(filledUp);\"\(price)\";\"\(consumption)\";\"\(comment)\"\n"
		}

		return dataString
	}

}
