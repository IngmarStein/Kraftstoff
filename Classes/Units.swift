//
//  Units.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 01.05.15.
//
//

import UIKit

extension UnitLength {

	var persistentId: Int32 {
		switch self {
		case UnitLength.kilometers:
			return 0
		case UnitLength.miles:
			return 1
		default:
			fatalError("Unknown length unit: \(self)")
		}
	}

	class func fromPersistentId(_ id: Int32) -> UnitLength {
		switch id {
		case 0:
			return .kilometers
		case 1:
			return .miles
		default:
			fatalError("Unknown length unit: \(id)")
		}
	}

}

extension UnitVolume {

	var persistentId: Int32 {
		switch self {
		case UnitVolume.liters:
			return 0
		case UnitVolume.gallons:
			return 1
		case UnitVolume.imperialGallons:
			return 2
		default:
			fatalError("Unknown volume unit: \(self)")
		}
	}

	class func fromPersistentId(_ id: Int32) -> UnitVolume {
		switch id {
		case 0:
			return .liters
		case 1:
			return .gallons
		case 2:
			return .imperialGallons
		default:
			fatalError("Unknown volume unit: \(id)")
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
		case .litersPer100km: return NSLocalizedString("l/100km", comment: "")
		case .kilometersPerLiter: return NSLocalizedString("km/l", comment: "")
		case .milesPerGallonUS: return NSLocalizedString("mpg", comment: "")
		case .milesPerGallonUK: return NSLocalizedString("mpg.uk", comment: "")
		case .gp10KUS: return NSLocalizedString("gp10k", comment: "")
		case .gp10KUK: return NSLocalizedString("gp10k.uk", comment: "")
		default: return ""
		}
	}

	var description: String {
		switch self {
		case .litersPer100km: return NSLocalizedString("Liters per 100 Kilometers", comment: "")
		case .kilometersPerLiter: return NSLocalizedString("Kilometers per Liter", comment: "")
		case .milesPerGallonUS: return NSLocalizedString("Miles per Gallon (US)", comment: "")
		case .milesPerGallonUK: return NSLocalizedString("Miles per Gallon (UK)", comment: "")
		case .gp10KUS: return NSLocalizedString("Gallons per 10000 Miles (US)", comment: "")
		case .gp10KUK: return NSLocalizedString("Gallons per 10000 Miles (UK)", comment: "")
		default: return ""
		}
	}

	var shortDescription: String {
		switch self {
		case .litersPer100km: return NSLocalizedString("Liters per 100 Kilometers", comment: "")
		case .kilometersPerLiter: return NSLocalizedString("Kilometers per Liter", comment: "")
		case .milesPerGallonUS: return NSLocalizedString("Miles per Gallon (US)", comment: "")
		case .milesPerGallonUK: return NSLocalizedString("Miles per Gallon (UK)", comment: "")
		case .gp10KUS: return NSLocalizedString("gp10k_short_us", comment: "")
		case .gp10KUK: return NSLocalizedString("gp10k_short_uk", comment: "")
		default: return ""
		}
	}

	var accessibilityDescription: String {
		switch self {
		case .litersPer100km: return NSLocalizedString("Liters per 100 Kilometers", comment: "")
		case .kilometersPerLiter: return NSLocalizedString("Kilometers per Liter", comment: "")
		case .milesPerGallonUS, .milesPerGallonUK: return NSLocalizedString("Miles per Gallon", comment: "")
		case .gp10KUS, .gp10KUK: return NSLocalizedString("Gallons per 10000 Miles", comment: "")
		default: return ""
		}
	}

}

final class Units {

	// MARK: - Unit Guessing from Current Locale

	static var volumeUnitFromLocale: UnitVolume {
		if let country = Locale.autoupdatingCurrent.object(forKey: Locale.Key.countryCode) as? String where country == "US" {
			return .gallons
		} else {
			return .liters
		}
	}

	static var fuelConsumptionUnitFromLocale: KSFuelConsumption {
		if let country = Locale.autoupdatingCurrent.object(forKey: Locale.Key.countryCode) as? String where country == "US" {
			return .milesPerGallonUS
		} else {
			return .litersPer100km
		}
	}

	static var distanceUnitFromLocale: UnitLength {
		if let country = Locale.autoupdatingCurrent.object(forKey: Locale.Key.countryCode) as? String where country == "US" {
			return .miles
		} else {
			return .kilometers
		}
	}

	// MARK: - Conversion Constants

	static let litersPerUSGallon = NSDecimalNumber(mantissa: (3785411784 as UInt64), exponent: -9, isNegative: false)
	static let litersPerImperialGallon = NSDecimalNumber(mantissa: (454609 as UInt64), exponent: -5, isNegative: false)
	static let kilometersPerStatuteMile = NSDecimalNumber(mantissa: (1609344 as UInt64), exponent: -6, isNegative: false)
	static let kilometersPerLiterToMilesPerUSGallon = NSDecimalNumber(mantissa: (2352145833 as UInt64), exponent: -9, isNegative: false)
	static let kilometersPerLiterToMilesPerImperialGallon = NSDecimalNumber(mantissa: (2737067636 as UInt64), exponent: -9, isNegative: false)
	static let litersPer100KilometersToMilesPer10KUSGallon = NSDecimalNumber(mantissa: (425170068027 as UInt64), exponent: -10, isNegative: false)
	static let litersPer100KilometersToMilesPer10KImperialGallon = NSDecimalNumber(mantissa: (353982300885 as UInt64), exponent: -10, isNegative: false)

	// MARK: - Conversion to/from Internal Data Format

	static func litersForVolume(_ volume: NSDecimalNumber, withUnit unit: UnitVolume) -> NSDecimalNumber {
		switch unit {
        case UnitVolume.gallons: return volume * litersPerUSGallon
        case UnitVolume.imperialGallons: return volume * litersPerImperialGallon
        case UnitVolume.liters: return volume
		default: return .zero
		}
	}

	static func volumeForLiters(_ liters: NSDecimalNumber, withUnit unit: UnitVolume) -> NSDecimalNumber {
		switch unit {
        case UnitVolume.gallons: return liters / litersPerUSGallon
        case UnitVolume.imperialGallons: return liters / litersPerImperialGallon
        case UnitVolume.liters: return liters
		default: return .zero
		}
	}

	static func kilometersForDistance(_ distance: NSDecimalNumber, withUnit unit: UnitLength) -> NSDecimalNumber {
		if unit == UnitLength.miles {
			return distance * kilometersPerStatuteMile
		} else {
			return distance
		}
	}

	static func distanceForKilometers(_ kilometers: NSDecimalNumber, withUnit unit: UnitLength) -> NSDecimalNumber {
		if unit == UnitLength.miles {
			return kilometers / kilometersPerStatuteMile
		} else {
			return kilometers
		}
	}

	static func pricePerLiter(_ price: NSDecimalNumber, withUnit unit: UnitVolume) -> NSDecimalNumber {
		switch unit {
        case UnitVolume.gallons: return price / litersPerUSGallon
        case UnitVolume.imperialGallons: return price / litersPerImperialGallon
        case UnitVolume.liters: return price
		default: return .zero
		}
	}

	static func pricePerUnit(_ literPrice: NSDecimalNumber, withUnit unit: UnitVolume) -> NSDecimalNumber {
		switch unit {
        case UnitVolume.gallons: return literPrice * litersPerUSGallon
        case UnitVolume.imperialGallons: return literPrice * litersPerImperialGallon
        case UnitVolume.liters: return literPrice
		default: return .zero
		}
	}

	// MARK: - Consumption/Efficiency Computation

	static func consumptionForKilometers(_ kilometers: NSDecimalNumber, liters: NSDecimalNumber, inUnit unit: KSFuelConsumption) -> NSDecimalNumber {
		let handler = Formatters.sharedConsumptionRoundingHandler

		if kilometers <= .zero {
			return .notA
		}

		if liters <= .zero {
			return .notA
		}

		if unit.isEfficiency {
			let kmPerLiter = kilometers / liters

			switch unit {

            case .kilometersPerLiter:
                return kmPerLiter.rounding(accordingToBehavior: handler)

            case .milesPerGallonUS:
                return kmPerLiter.multiplying(by: kilometersPerLiterToMilesPerUSGallon, withBehavior: handler)

            default: // .milesPerGallonUK:
                return kmPerLiter.multiplying(by: kilometersPerLiterToMilesPerImperialGallon, withBehavior: handler)

			}

		} else {

			let literPer100km = (liters << 2) / kilometers

			switch unit {

            case .litersPer100km:
				return literPer100km.rounding(accordingToBehavior: handler)

            case .gp10KUS:
                return literPer100km.multiplying(by: litersPer100KilometersToMilesPer10KUSGallon, withBehavior: handler)

            default: // .gp10KUK:
				return literPer100km.multiplying(by: litersPer100KilometersToMilesPer10KImperialGallon, withBehavior: handler)
			}
		}
	}

	// MARK: - Unit Strings/Descriptions

	static func fuelUnitDescription(_ unit: UnitVolume, discernGallons: Bool, pluralization plural: Bool, bundle: Bundle = Bundle.main) -> String {
		if plural {
			switch unit {
			case UnitVolume.liters: return NSLocalizedString("Liters", bundle: bundle, comment: "")
            case UnitVolume.gallons: return discernGallons ? NSLocalizedString("Gallons (US)", bundle: bundle, comment: "") : NSLocalizedString("Gallons", comment: "")
            case UnitVolume.imperialGallons: return discernGallons ? NSLocalizedString("Gallons (UK)", bundle: bundle, comment: "") : NSLocalizedString("Gallons", comment: "")
			default: return ""
			}
		} else {
			switch unit {
            case UnitVolume.liters: return NSLocalizedString("Liter", bundle: bundle, comment: "")
            case UnitVolume.gallons: return discernGallons ? NSLocalizedString("Gallon (US)", bundle: bundle, comment: "") : NSLocalizedString("Gallon", comment: "")
            case UnitVolume.imperialGallons: return discernGallons ? NSLocalizedString("Gallon (UK)", bundle: bundle, comment: "") : NSLocalizedString("Gallon", comment: "")
			default: return ""
			}
		}
	}

	static func fuelPriceUnitDescription(_ unit: UnitVolume, bundle: Bundle = Bundle.main) -> String {
		if unit == UnitVolume.liters {
			return NSLocalizedString("Price per Liter", bundle: bundle, comment: "")
		} else {
			return NSLocalizedString("Price per Gallon", bundle: bundle, comment: "")
		}
	}

	static func odometerUnitDescription(_ unit: UnitLength, pluralization plural: Bool, bundle: Bundle = Bundle.main) -> String {
		if plural {
			return unit == UnitLength.kilometers ? NSLocalizedString("Kilometers", bundle: bundle, comment: "") : NSLocalizedString("Miles", comment: "")
		} else {
			return unit == UnitLength.kilometers ? NSLocalizedString("Kilometer", bundle: bundle, comment: "") : NSLocalizedString("Mile", comment: "")
		}
	}

}
