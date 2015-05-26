//
//  Units.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 01.05.15.
//
//

import UIKit

// Unit Constants
public enum KSDistance: Int32 {
	case Invalid = -1
	case Kilometer
	case StatuteMile

	var isMetric: Bool {
		return self == .Kilometer
	}

	var description: String {
		if isMetric {
			return "km"
		} else {
			return "mi"
		}
	}
}

public enum KSVolume: Int32 {
	case Invalid = -1
	case Liter
	case GalUS
	case GalUK

	var isMetric: Bool {
		return self == .Liter
	}

	var description: String {
		if self == .Liter {
			return "l"
		} else {
			return "gal"
		}
	}
}

public enum KSFuelConsumption: Int32 {
	case Invalid = -1
	case LitersPer100km
	case KilometersPerLiter
	case MilesPerGallonUS
	case MilesPerGallonUK
	case GP10KUS
	case GP10KUK

	var isMetric: Bool {
		return self == .LitersPer100km || self == .KilometersPerLiter
	}

	var isEfficiency: Bool {
		return self == .KilometersPerLiter || self == .MilesPerGallonUS || self == .MilesPerGallonUK
	}

	var isGP10K: Bool {
		return self == .GP10KUS || self == .GP10KUS
	}

	var localizedString: String {
		switch self {
		case .LitersPer100km: return NSLocalizedString("l/100km", comment:"")
		case .KilometersPerLiter: return NSLocalizedString("km/l", comment:"")
		case .MilesPerGallonUS: return NSLocalizedString("mpg", comment:"")
		case .MilesPerGallonUK: return NSLocalizedString("mpg.uk", comment:"")
		case .GP10KUS: return NSLocalizedString("gp10k", comment:"")
		case .GP10KUK: return NSLocalizedString("gp10k.uk", comment:"")
		default: return ""
		}
	}

	var description: String {
		switch self {
		case .LitersPer100km: return NSLocalizedString("Liters per 100 Kilometers", comment:"")
		case .KilometersPerLiter: return NSLocalizedString("Kilometers per Liter", comment:"")
		case .MilesPerGallonUS: return NSLocalizedString("Miles per Gallon (US)", comment:"")
		case .MilesPerGallonUK: return NSLocalizedString("Miles per Gallon (UK)", comment:"")
		case .GP10KUS: return NSLocalizedString("Gallons per 10000 Miles (US)", comment:"")
		case .GP10KUK: return NSLocalizedString("Gallons per 10000 Miles (UK)", comment:"")
		default: return ""
		}
	}

	var shortDescription: String {
		switch self {
		case .LitersPer100km: return NSLocalizedString("Liters per 100 Kilometers", comment:"")
		case .KilometersPerLiter: return NSLocalizedString("Kilometers per Liter", comment:"")
		case .MilesPerGallonUS: return NSLocalizedString("Miles per Gallon (US)", comment:"")
		case .MilesPerGallonUK: return NSLocalizedString("Miles per Gallon (UK)", comment:"")
		case .GP10KUS: return NSLocalizedString("gp10k_short_us", comment:"")
		case .GP10KUK: return NSLocalizedString("gp10k_short_uk", comment:"")
		default: return ""
		}
	}

	var accessibilityDescription: String {
		switch self {
		case .LitersPer100km: return NSLocalizedString("Liters per 100 Kilometers", comment:"")
		case .KilometersPerLiter: return NSLocalizedString("Kilometers per Liter", comment:"")
		case .MilesPerGallonUS, .MilesPerGallonUK: return NSLocalizedString("Miles per Gallon", comment:"")
		case .GP10KUS, .GP10KUK: return NSLocalizedString("Gallons per 10000 Miles", comment:"")
		default: return ""
		}
	}

}

final class Units {

	//MARK: - Unit Guessing from Current Locale

	static var volumeUnitFromLocale: KSVolume {
		if let country = NSLocale.autoupdatingCurrentLocale().objectForKey(NSLocaleCountryCode) as? String where country == "US" {
			return .GalUS
		} else {
			return .Liter
		}
	}

	static var fuelConsumptionUnitFromLocale: KSFuelConsumption {
		if let country = NSLocale.autoupdatingCurrentLocale().objectForKey(NSLocaleCountryCode) as? String where country == "US" {
			return .MilesPerGallonUS
		} else {
			return .LitersPer100km
		}
	}

	static var distanceUnitFromLocale: KSDistance {
		if let country = NSLocale.autoupdatingCurrentLocale().objectForKey(NSLocaleCountryCode) as? String where country == "US" {
			return .StatuteMile
		} else {
			return .Kilometer
		}
	}

	//MARK: - Conversion Constants

	static let litersPerUSGallon = NSDecimalNumber(mantissa:UInt64(3785411784), exponent: -9, isNegative:false)
	static let litersPerImperialGallon = NSDecimalNumber(mantissa:UInt64(454609), exponent: -5, isNegative:false)
	static let kilometersPerStatuteMile = NSDecimalNumber(mantissa:UInt64(1609344), exponent: -6, isNegative:false)
	static let kilometersPerLiterToMilesPerUSGallon = NSDecimalNumber(mantissa:UInt64(2352145833), exponent: -9, isNegative:false)
	static let kilometersPerLiterToMilesPerImperialGallon = NSDecimalNumber(mantissa:UInt64(2737067636), exponent: -9, isNegative:false)
	static let litersPer100KilometersToMilesPer10KUSGallon = NSDecimalNumber(mantissa:UInt64(425170068027), exponent: -10, isNegative:false)
	static let litersPer100KilometersToMilesPer10KImperialGallon = NSDecimalNumber(mantissa:UInt64(353982300885), exponent: -10, isNegative:false)

	//MARK: - Conversion to/from Internal Data Format

	static func litersForVolume(volume: NSDecimalNumber, withUnit unit: KSVolume) -> NSDecimalNumber {
		switch unit {
        case .GalUS: return volume * litersPerUSGallon
        case .GalUK: return volume * litersPerImperialGallon
        case .Liter: return volume
		default:     return NSDecimalNumber.zero()
		}
	}

	static func volumeForLiters(liters: NSDecimalNumber, withUnit unit: KSVolume) -> NSDecimalNumber {
		switch unit {
        case .GalUS: return liters / litersPerUSGallon
        case .GalUK: return liters / litersPerImperialGallon
        case .Liter: return liters
		default:     return NSDecimalNumber.zero()
		}
	}

	static func kilometersForDistance(distance: NSDecimalNumber, withUnit unit: KSDistance) -> NSDecimalNumber {
		if unit == .StatuteMile {
			return distance * kilometersPerStatuteMile
		} else {
			return distance
		}
	}

	static func distanceForKilometers(kilometers: NSDecimalNumber, withUnit unit: KSDistance) -> NSDecimalNumber {
		if unit == .StatuteMile {
			return kilometers / kilometersPerStatuteMile
		} else {
			return kilometers
		}
	}

	static func pricePerLiter(price: NSDecimalNumber, withUnit unit: KSVolume) -> NSDecimalNumber {
		switch unit {
        case .GalUS: return price / litersPerUSGallon
        case .GalUK: return price / litersPerImperialGallon
        case .Liter: return price
		default:     return NSDecimalNumber.zero()
		}
	}

	static func pricePerUnit(literPrice: NSDecimalNumber, withUnit unit: KSVolume) -> NSDecimalNumber {
		switch unit {
        case .GalUS: return literPrice * litersPerUSGallon
        case .GalUK: return literPrice * litersPerImperialGallon
        case .Liter: return literPrice
		default:     return NSDecimalNumber.zero()
		}
	}

	//MARK: - Consumption/Efficiency Computation

	static func consumptionForKilometers(kilometers: NSDecimalNumber, liters: NSDecimalNumber, inUnit unit: KSFuelConsumption) -> NSDecimalNumber {
		let handler = Formatters.sharedConsumptionRoundingHandler

		if kilometers <= NSDecimalNumber.zero() {
			return NSDecimalNumber.notANumber()
		}

		if liters <= NSDecimalNumber.zero() {
			return NSDecimalNumber.notANumber()
		}

		if unit.isEfficiency {
			let kmPerLiter = kilometers / liters

			switch unit {

            case .KilometersPerLiter:
                return kmPerLiter.decimalNumberByRoundingAccordingToBehavior(handler)
                
            case .MilesPerGallonUS:
                return kmPerLiter.decimalNumberByMultiplyingBy(kilometersPerLiterToMilesPerUSGallon, withBehavior:handler)
                
            default: // .MilesPerGallonUK:
                return kmPerLiter.decimalNumberByMultiplyingBy(kilometersPerLiterToMilesPerImperialGallon, withBehavior:handler)

			}

		} else {

			let literPer100km = (liters << 2) / kilometers
    
			switch unit {

            case .LitersPer100km:
                return literPer100km.decimalNumberByRoundingAccordingToBehavior(handler)

            case .GP10KUS:
                return literPer100km.decimalNumberByMultiplyingBy(litersPer100KilometersToMilesPer10KUSGallon, withBehavior:handler)

            default: // .GP10KUK:
				return literPer100km.decimalNumberByMultiplyingBy(litersPer100KilometersToMilesPer10KImperialGallon, withBehavior:handler)
			}
		}
	}

	//MARK: - Unit Strings/Descriptions

	static func fuelUnitDescription(unit: KSVolume, discernGallons: Bool, pluralization plural: Bool) -> String {
		if plural {
			switch unit {
			case .Liter: return NSLocalizedString("Liters", comment:"")
            case .GalUS: return discernGallons ? NSLocalizedString("Gallons (US)", comment:"") : NSLocalizedString("Gallons", comment:"")
            case .GalUK: return discernGallons ? NSLocalizedString("Gallons (UK)", comment:"") : NSLocalizedString("Gallons", comment:"")
			default:     return ""
			}
		} else {
			switch unit {
            case .Liter: return NSLocalizedString("Liter", comment:"")
            case .GalUS: return discernGallons ? NSLocalizedString("Gallon (US)", comment:"") : NSLocalizedString("Gallon", comment:"")
            case .GalUK: return discernGallons ? NSLocalizedString("Gallon (UK)", comment:"") : NSLocalizedString("Gallon", comment:"")
			default:     return ""
			}
		}
	}

	static func fuelPriceUnitDescription(unit: KSVolume) -> String {
		if unit.isMetric {
			return NSLocalizedString("Price per Liter", comment:"")
		} else {
			return NSLocalizedString("Price per Gallon", comment:"")
		}
	}

	static func odometerUnitDescription(unit: KSDistance, pluralization plural: Bool) -> String {
		if plural {
			return unit.isMetric ? NSLocalizedString("Kilometers", comment:"") : NSLocalizedString("Miles", comment:"")
		} else {
			return unit.isMetric ? NSLocalizedString("Kilometer", comment:"")  : NSLocalizedString("Mile", comment:"")
		}
	}
}
