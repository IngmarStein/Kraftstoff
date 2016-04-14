//
//  Units.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 01.05.15.
//
//

import UIKit

// Unit Constants
enum KSDistance: Int32 {
	case invalid = -1
	case kilometer
	case statuteMile

	var isMetric: Bool {
		return self == .kilometer
	}

	var description: String {
		if isMetric {
			return "km"
		} else {
			return "mi"
		}
	}
}

enum KSVolume: Int32 {
	case invalid = -1
	case liter
	case galUS
	case galUK

	var isMetric: Bool {
		return self == .liter
	}

	var description: String {
		if self == .liter {
			return "l"
		} else {
			return "gal"
		}
	}
}

enum KSFuelConsumption: Int32 {
	case invalid = -1
	case litersPer100km
	case kilometersPerLiter
	case milesPerGallonUS
	case milesPerGallonUK
	case gp10KUS
	case gp10KUK

	var isMetric: Bool {
		return self == .litersPer100km || self == .kilometersPerLiter
	}

	var isEfficiency: Bool {
		return self == .kilometersPerLiter || self == .milesPerGallonUS || self == .milesPerGallonUK
	}

	var isGP10K: Bool {
		return self == .gp10KUS || self == .gp10KUS
	}

	var localizedString: String {
		switch self {
		case .litersPer100km: return NSLocalizedString("l/100km", comment:"")
		case .kilometersPerLiter: return NSLocalizedString("km/l", comment:"")
		case .milesPerGallonUS: return NSLocalizedString("mpg", comment:"")
		case .milesPerGallonUK: return NSLocalizedString("mpg.uk", comment:"")
		case .gp10KUS: return NSLocalizedString("gp10k", comment:"")
		case .gp10KUK: return NSLocalizedString("gp10k.uk", comment:"")
		default: return ""
		}
	}

	var description: String {
		switch self {
		case .litersPer100km: return NSLocalizedString("Liters per 100 Kilometers", comment:"")
		case .kilometersPerLiter: return NSLocalizedString("Kilometers per Liter", comment:"")
		case .milesPerGallonUS: return NSLocalizedString("Miles per Gallon (US)", comment:"")
		case .milesPerGallonUK: return NSLocalizedString("Miles per Gallon (UK)", comment:"")
		case .gp10KUS: return NSLocalizedString("Gallons per 10000 Miles (US)", comment:"")
		case .gp10KUK: return NSLocalizedString("Gallons per 10000 Miles (UK)", comment:"")
		default: return ""
		}
	}

	var shortDescription: String {
		switch self {
		case .litersPer100km: return NSLocalizedString("Liters per 100 Kilometers", comment:"")
		case .kilometersPerLiter: return NSLocalizedString("Kilometers per Liter", comment:"")
		case .milesPerGallonUS: return NSLocalizedString("Miles per Gallon (US)", comment:"")
		case .milesPerGallonUK: return NSLocalizedString("Miles per Gallon (UK)", comment:"")
		case .gp10KUS: return NSLocalizedString("gp10k_short_us", comment:"")
		case .gp10KUK: return NSLocalizedString("gp10k_short_uk", comment:"")
		default: return ""
		}
	}

	var accessibilityDescription: String {
		switch self {
		case .litersPer100km: return NSLocalizedString("Liters per 100 Kilometers", comment:"")
		case .kilometersPerLiter: return NSLocalizedString("Kilometers per Liter", comment:"")
		case .milesPerGallonUS, .milesPerGallonUK: return NSLocalizedString("Miles per Gallon", comment:"")
		case .gp10KUS, .gp10KUK: return NSLocalizedString("Gallons per 10000 Miles", comment:"")
		default: return ""
		}
	}

}

final class Units {

	//MARK: - Unit Guessing from Current Locale

	static var volumeUnitFromLocale: KSVolume {
		if let country = NSLocale.autoupdatingCurrent().object(forKey: NSLocaleCountryCode) as? String where country == "US" {
			return .galUS
		} else {
			return .liter
		}
	}

	static var fuelConsumptionUnitFromLocale: KSFuelConsumption {
		if let country = NSLocale.autoupdatingCurrent().object(forKey: NSLocaleCountryCode) as? String where country == "US" {
			return .milesPerGallonUS
		} else {
			return .litersPer100km
		}
	}

	static var distanceUnitFromLocale: KSDistance {
		if let country = NSLocale.autoupdatingCurrent().object(forKey: NSLocaleCountryCode) as? String where country == "US" {
			return .statuteMile
		} else {
			return .kilometer
		}
	}

	//MARK: - Conversion Constants

	static let litersPerUSGallon = NSDecimalNumber(mantissa:(3785411784 as UInt64), exponent: -9, isNegative:false)
	static let litersPerImperialGallon = NSDecimalNumber(mantissa:(454609 as UInt64), exponent: -5, isNegative:false)
	static let kilometersPerStatuteMile = NSDecimalNumber(mantissa:(1609344 as UInt64), exponent: -6, isNegative:false)
	static let kilometersPerLiterToMilesPerUSGallon = NSDecimalNumber(mantissa:(2352145833 as UInt64), exponent: -9, isNegative:false)
	static let kilometersPerLiterToMilesPerImperialGallon = NSDecimalNumber(mantissa:(2737067636 as UInt64), exponent: -9, isNegative:false)
	static let litersPer100KilometersToMilesPer10KUSGallon = NSDecimalNumber(mantissa:(425170068027 as UInt64), exponent: -10, isNegative:false)
	static let litersPer100KilometersToMilesPer10KImperialGallon = NSDecimalNumber(mantissa:(353982300885 as UInt64), exponent: -10, isNegative:false)

	//MARK: - Conversion to/from Internal Data Format

	static func litersForVolume(_ volume: NSDecimalNumber, withUnit unit: KSVolume) -> NSDecimalNumber {
		switch unit {
        case .galUS: return volume * litersPerUSGallon
        case .galUK: return volume * litersPerImperialGallon
        case .liter: return volume
		default:     return NSDecimalNumber.zero()
		}
	}

	static func volumeForLiters(_ liters: NSDecimalNumber, withUnit unit: KSVolume) -> NSDecimalNumber {
		switch unit {
        case .galUS: return liters / litersPerUSGallon
        case .galUK: return liters / litersPerImperialGallon
        case .liter: return liters
		default:     return NSDecimalNumber.zero()
		}
	}

	static func kilometersForDistance(_ distance: NSDecimalNumber, withUnit unit: KSDistance) -> NSDecimalNumber {
		if unit == .statuteMile {
			return distance * kilometersPerStatuteMile
		} else {
			return distance
		}
	}

	static func distanceForKilometers(_ kilometers: NSDecimalNumber, withUnit unit: KSDistance) -> NSDecimalNumber {
		if unit == .statuteMile {
			return kilometers / kilometersPerStatuteMile
		} else {
			return kilometers
		}
	}

	static func pricePerLiter(price: NSDecimalNumber, withUnit unit: KSVolume) -> NSDecimalNumber {
		switch unit {
        case .galUS: return price / litersPerUSGallon
        case .galUK: return price / litersPerImperialGallon
        case .liter: return price
		default:     return NSDecimalNumber.zero()
		}
	}

	static func pricePerUnit(literPrice: NSDecimalNumber, withUnit unit: KSVolume) -> NSDecimalNumber {
		switch unit {
        case .galUS: return literPrice * litersPerUSGallon
        case .galUK: return literPrice * litersPerImperialGallon
        case .liter: return literPrice
		default:     return NSDecimalNumber.zero()
		}
	}

	//MARK: - Consumption/Efficiency Computation

	static func consumptionForKilometers(_ kilometers: NSDecimalNumber, liters: NSDecimalNumber, inUnit unit: KSFuelConsumption) -> NSDecimalNumber {
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

            case .kilometersPerLiter:
                return kmPerLiter.rounding(accordingToBehavior: handler)

            case .milesPerGallonUS:
                return kmPerLiter.multiplying(by: kilometersPerLiterToMilesPerUSGallon, withBehavior:handler)
                
            default: // .milesPerGallonUK:
                return kmPerLiter.multiplying(by: kilometersPerLiterToMilesPerImperialGallon, withBehavior:handler)

			}

		} else {

			let literPer100km = (liters << 2) / kilometers
    
			switch unit {

            case .litersPer100km:
				return literPer100km.rounding(accordingToBehavior: handler)

            case .gp10KUS:
                return literPer100km.multiplying(by: litersPer100KilometersToMilesPer10KUSGallon, withBehavior:handler)

            default: // .gp10KUK:
				return literPer100km.multiplying(by: litersPer100KilometersToMilesPer10KImperialGallon, withBehavior:handler)
			}
		}
	}

	//MARK: - Unit Strings/Descriptions

	static func fuelUnitDescription(_ unit: KSVolume, discernGallons: Bool, pluralization plural: Bool, bundle: NSBundle = NSBundle.main()) -> String {
		if plural {
			switch unit {
			case .liter: return NSLocalizedString("Liters", bundle: bundle, comment:"")
            case .galUS: return discernGallons ? NSLocalizedString("Gallons (US)", bundle: bundle, comment:"") : NSLocalizedString("Gallons", comment:"")
            case .galUK: return discernGallons ? NSLocalizedString("Gallons (UK)", bundle: bundle, comment:"") : NSLocalizedString("Gallons", comment:"")
			default:     return ""
			}
		} else {
			switch unit {
            case .liter: return NSLocalizedString("Liter", bundle: bundle, comment:"")
            case .galUS: return discernGallons ? NSLocalizedString("Gallon (US)", bundle: bundle, comment:"") : NSLocalizedString("Gallon", comment:"")
            case .galUK: return discernGallons ? NSLocalizedString("Gallon (UK)", bundle: bundle, comment:"") : NSLocalizedString("Gallon", comment:"")
			default:     return ""
			}
		}
	}

	static func fuelPriceUnitDescription(_ unit: KSVolume, bundle: NSBundle = NSBundle.main()) -> String {
		if unit.isMetric {
			return NSLocalizedString("Price per Liter", bundle: bundle, comment:"")
		} else {
			return NSLocalizedString("Price per Gallon", bundle: bundle, comment:"")
		}
	}

	static func odometerUnitDescription(_ unit: KSDistance, pluralization plural: Bool, bundle: NSBundle = NSBundle.main()) -> String {
		if plural {
			return unit.isMetric ? NSLocalizedString("Kilometers", bundle: bundle, comment:"") : NSLocalizedString("Miles", comment:"")
		} else {
			return unit.isMetric ? NSLocalizedString("Kilometer", bundle: bundle, comment:"")  : NSLocalizedString("Mile", comment:"")
		}
	}
}
