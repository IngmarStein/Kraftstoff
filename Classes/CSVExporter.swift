//
//  CSVExporter.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 07.05.15.
//
//

import Foundation

final class CSVExporter {
  static func exportFuelEvents<S: Sequence>(_ fuelEvents: S, forCar car: Car, language: String? = nil) -> String where S.Element == FuelEvent {
    let odometerUnit = car.ksOdometerUnit
    let fuelUnit = car.ksFuelUnit
    let consumptionUnit = car.ksFuelConsumptionUnit
    let measurementFormatter = MeasurementFormatter()
    measurementFormatter.unitStyle = .long

    let bundle: Bundle
    if let language = language, let path = Bundle.main.path(forResource: language, ofType: "lproj"), let localeBundle = Bundle(path: path) {
      bundle = localeBundle
    } else {
      bundle = Bundle.main
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

    dataString += measurementFormatter.string(from: consumptionUnit).capitalized
    dataString += ";"

    dataString += NSLocalizedString("Comment", bundle: bundle, comment: "")
    dataString += "\n"

    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd';'HH:mm"
    dateFormatter.locale = nil
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

    let numberFormatter = NumberFormatter()
    numberFormatter.numberStyle = .decimal
    numberFormatter.locale = Locale.current
    numberFormatter.usesGroupingSeparator = false
    numberFormatter.alwaysShowsDecimalSeparator = true
    numberFormatter.minimumFractionDigits = 2

    for fuelEvent in fuelEvents {
      let timestamp = dateFormatter.string(from: fuelEvent.ksTimestamp)
      let distance = numberFormatter.string(from: Units.distanceForKilometers(fuelEvent.ksDistance, withUnit: odometerUnit) as NSNumber)!
      let fuelVolume = numberFormatter.string(from: Units.volumeForLiters(fuelEvent.ksFuelVolume, withUnit: fuelUnit) as NSNumber)!
      let filledUp = fuelEvent.filledUp ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")
      let price = numberFormatter.string(from: Units.pricePerUnit(fuelEvent.ksPrice, withUnit: fuelUnit) as NSNumber)!
      let consumption = fuelEvent.filledUp ? numberFormatter.string(from:
        Units.consumptionForKilometers(fuelEvent.ksDistance + fuelEvent.ksInheritedDistance,
                                       liters: fuelEvent.ksFuelVolume + fuelEvent.ksInheritedFuelVolume,
                                       inUnit: consumptionUnit) as NSNumber)!
        : " "
      let comment = fuelEvent.comment ?? ""

      dataString += "\(timestamp);\"\(distance)\";\"\(fuelVolume)\";\(filledUp);\"\(price)\";\"\(consumption)\";\"\(comment)\"\n"
    }

    return dataString
  }
}
