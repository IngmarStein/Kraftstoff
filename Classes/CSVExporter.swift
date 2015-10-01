//
//  CSVExporter.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 07.05.15.
//
//

import Foundation

final class CSVExporter {
	static func exportFuelEvents(fuelEvents: [FuelEvent], forCar car: Car, language: String? = nil) -> String {
		let odometerUnit = car.ksOdometerUnit
		let fuelUnit = car.ksFuelUnit
		let consumptionUnit = car.ksFuelConsumptionUnit

		let bundle: NSBundle
		if let language = language, path = NSBundle.mainBundle().pathForResource(language, ofType: "lproj"), localeBundle = NSBundle(path: path) {
			bundle = localeBundle
		} else {
			bundle = NSBundle.mainBundle()
		}

		var dataString = String()
		dataString.reserveCapacity(4096)

		dataString += NSLocalizedString("yyyy-MM-dd", bundle: bundle, comment:"")
		dataString += ";"

		dataString += NSLocalizedString("HH:mm", bundle: bundle, comment:"")
		dataString += ";"

		dataString += Units.odometerUnitDescription(odometerUnit, pluralization:true, bundle: bundle)
		dataString += ";"

		dataString += Units.fuelUnitDescription(fuelUnit, discernGallons:true, pluralization:true, bundle: bundle)
		dataString += ";"

		dataString += NSLocalizedString("Full Fill-Up", bundle: bundle, comment:"")
		dataString += ";"

		dataString += Units.fuelPriceUnitDescription(fuelUnit, bundle: bundle)
		dataString += ";"

		dataString += consumptionUnit.description
		dataString += ";"

		dataString += NSLocalizedString("Comment", bundle: bundle, comment:"")
		dataString += "\n"

		let dateFormatter = NSDateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd';'HH:mm"
		dateFormatter.locale = NSLocale.systemLocale()
		dateFormatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)

		let numberFormatter = NSNumberFormatter()
		numberFormatter.numberStyle = .DecimalStyle
		numberFormatter.locale = NSLocale.currentLocale()
		numberFormatter.usesGroupingSeparator = false
		numberFormatter.alwaysShowsDecimalSeparator = true
		numberFormatter.minimumFractionDigits = 2

		for fuelEvent in fuelEvents {
			let distance = fuelEvent.distance
			let fuelVolume = fuelEvent.fuelVolume
			let price = fuelEvent.price

			dataString += String(format:"%@;\"%@\";\"%@\";%@;\"%@\";\"%@\";\"%@\"\n",
				dateFormatter.stringFromDate(fuelEvent.timestamp),
				numberFormatter.stringFromNumber(Units.distanceForKilometers(distance, withUnit:odometerUnit))!,
				numberFormatter.stringFromNumber(Units.volumeForLiters(fuelVolume, withUnit:fuelUnit))!,
				fuelEvent.filledUp ? NSLocalizedString("Yes", comment:"") : NSLocalizedString("No", comment:""),
				numberFormatter.stringFromNumber(Units.pricePerUnit(price, withUnit:fuelUnit))!,
				fuelEvent.filledUp ? numberFormatter.stringFromNumber(
					Units.consumptionForKilometers(distance + fuelEvent.inheritedDistance,
						liters:fuelVolume + fuelEvent.inheritedFuelVolume,
						inUnit:consumptionUnit))!
					: " ",
				fuelEvent.comment ?? "")
		}

		return dataString
	}
}