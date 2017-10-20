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
		case .kilometers:
			return 0
		case .miles:
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
		case .liters:
			return 0
		case .gallons:
			return 1
		case .imperialGallons:
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

final class UnitConverterReciprocal: UnitConverter, NSSecureCoding {

	var coefficient: Double

	init(coefficient c: Double) {
		coefficient = c

		super.init()
	}

	init?(coder aDecoder: NSCoder) {
		coefficient = aDecoder.decodeDouble(forKey: "coefficient")

		super.init()
	}

	static var supportsSecureCoding: Bool { return true }

	func encode(with aCoder: NSCoder) {
		aCoder.encode(coefficient, forKey: "coefficient")
	}

	override func baseUnitValue(fromValue value: Double) -> Double {
		return coefficient / value
	}

	override func value(fromBaseUnitValue baseUnitValue: Double) -> Double {
		return coefficient / baseUnitValue
	}

}

// Base unit = l / 100 km
extension UnitFuelEfficiency {

	@nonobjc static let kilometersPerLiter = UnitFuelEfficiency(symbol: "km/l", converter: UnitConverterReciprocal(coefficient: 100.0))
	@nonobjc static let gallonsPer10000Miles = UnitFuelEfficiency(symbol: "gp10k_us", converter: UnitConverterLinear(coefficient: 42.5170068027))
	@nonobjc static let imperialGallonsPer10000Miles = UnitFuelEfficiency(symbol: "gp10k_uk", converter: UnitConverterLinear(coefficient: 35.3982300885))

	var persistentId: Int32 {
		switch self {
		case .litersPer100Kilometers:
			return 0
		case .milesPerGallon:
			return 1
		case .milesPerImperialGallon:
			return 2
		case .gallonsPer10000Miles:
			return 3
		case .imperialGallonsPer10000Miles:
			return 4
		default:
			fatalError("Unknown fuel efficiency unit: \(self)")
		}
	}

	class func fromPersistentId(_ id: Int32) -> UnitFuelEfficiency {
		switch id {
		case 0:
			return .litersPer100Kilometers
		case 1:
			return .milesPerGallon
		case 2:
			return .milesPerImperialGallon
		case 3:
			return .gallonsPer10000Miles
		case 4:
			return .imperialGallonsPer10000Miles
		default:
			fatalError("Unknown fuel efficiency unit: \(id)")
		}
	}

	var isGP10K: Bool {
		return self == .gallonsPer10000Miles || self == .imperialGallonsPer10000Miles
	}

	var isEfficiency: Bool {
		return self == .kilometersPerLiter || self == .milesPerGallon || self == .milesPerImperialGallon
	}

}

final class Units {

	// MARK: - Unit guessing from current locale

	static var volumeUnitFromLocale: UnitVolume {
		if Locale.autoupdatingCurrent.regionCode == "US" {
			return .gallons
		} else {
			return .liters
		}
	}

	static var fuelConsumptionUnitFromLocale: UnitFuelEfficiency {
		if Locale.autoupdatingCurrent.regionCode == "US" {
			return .milesPerGallon
		} else {
			return .litersPer100Kilometers
		}
	}

	static var distanceUnitFromLocale: UnitLength {
		if Locale.autoupdatingCurrent.regionCode == "US" {
			return .miles
		} else {
			return .kilometers
		}
	}

	// MARK: - Conversion Constants

	static let litersPerUSGallon = NSDecimalNumber(mantissa: (3785411784 as UInt64), exponent: -9, isNegative: false) as Decimal
	static let litersPerImperialGallon = NSDecimalNumber(mantissa: (454609 as UInt64), exponent: -5, isNegative: false) as Decimal
	static let kilometersPerStatuteMile = NSDecimalNumber(mantissa: (1609344 as UInt64), exponent: -6, isNegative: false) as Decimal
	static let kilometersPerLiterToMilesPerUSGallon = NSDecimalNumber(mantissa: (2352145833 as UInt64), exponent: -9, isNegative: false)
	static let kilometersPerLiterToMilesPerImperialGallon = NSDecimalNumber(mantissa: (2737067636 as UInt64), exponent: -9, isNegative: false)
	static let litersPer100KilometersToMilesPer10KUSGallon = NSDecimalNumber(mantissa: (425170068027 as UInt64), exponent: -10, isNegative: false)
	static let litersPer100KilometersToMilesPer10KImperialGallon = NSDecimalNumber(mantissa: (353982300885 as UInt64), exponent: -10, isNegative: false)

	// MARK: - Conversion to/from Internal Data Format

	static func litersForVolume(_ volume: Decimal, withUnit unit: UnitVolume) -> Decimal {
		switch unit {
		case .gallons: return volume * litersPerUSGallon
		case .imperialGallons: return volume * litersPerImperialGallon
		case .liters: return volume
		default: return 0
		}
	}

	static func volumeForLiters(_ liters: Decimal, withUnit unit: UnitVolume) -> Decimal {
		switch unit {
		case .gallons: return liters / litersPerUSGallon
		case .imperialGallons: return liters / litersPerImperialGallon
		case .liters: return liters
		default: return 0
		}
	}

	static func kilometersForDistance(_ distance: Decimal, withUnit unit: UnitLength) -> Decimal {
		if unit == .miles {
			return distance * kilometersPerStatuteMile
		} else {
			return distance
		}
	}

	static func distanceForKilometers(_ kilometers: Decimal, withUnit unit: UnitLength) -> Decimal {
		if unit == .miles {
			return kilometers / kilometersPerStatuteMile
		} else {
			return kilometers
		}
	}

	static func pricePerLiter(_ price: Decimal, withUnit unit: UnitVolume) -> Decimal {
		switch unit {
		case .gallons: return price / litersPerUSGallon
		case .imperialGallons: return price / litersPerImperialGallon
		case .liters: return price
		default: return 0
		}
	}

	static func pricePerUnit(_ literPrice: Decimal, withUnit unit: UnitVolume) -> Decimal {
		switch unit {
		case .gallons: return literPrice * litersPerUSGallon
		case .imperialGallons: return literPrice * litersPerImperialGallon
		case .liters: return literPrice
		default: return 0
		}
	}

	// MARK: - Consumption/Efficiency Computation

	static func consumptionForKilometers(_ kilometers: Decimal, liters: Decimal, inUnit unit: UnitFuelEfficiency) -> Decimal {
		let handler = Formatters.consumptionRoundingHandler

		if kilometers.isSignMinus || kilometers.isZero {
			return .nan
		}

		if liters.isSignMinus || liters.isZero {
			return .nan
		}

		if unit.isEfficiency {
			let kmPerLiter = (kilometers / liters) as NSDecimalNumber

			switch unit {
			case .kilometersPerLiter:
				return kmPerLiter.rounding(accordingToBehavior: handler) as Decimal
			case .milesPerGallon:
				return kmPerLiter.multiplying(by: kilometersPerLiterToMilesPerUSGallon, withBehavior: handler) as Decimal
			default: // .milesPerImperialGallonUK:
				return kmPerLiter.multiplying(by: kilometersPerLiterToMilesPerImperialGallon, withBehavior: handler) as Decimal
			}

		} else {

			let literPer100km = ((liters << 2) / kilometers) as NSDecimalNumber

			switch unit {
			case .litersPer100Kilometers:
				return literPer100km.rounding(accordingToBehavior: handler) as Decimal
			case .gallonsPer10000Miles:
				return literPer100km.multiplying(by: litersPer100KilometersToMilesPer10KUSGallon, withBehavior: handler) as Decimal
			default: // .imperialGallonsPer10000Miles:
				return literPer100km.multiplying(by: litersPer100KilometersToMilesPer10KImperialGallon, withBehavior: handler) as Decimal
			}
		}
	}

	// MARK: - Unit Strings/Descriptions

	static func fuelUnitDescription(_ unit: UnitVolume, discernGallons: Bool, pluralization plural: Bool, bundle: Bundle = Bundle.main) -> String {
		if plural {
			switch unit {
			case .liters: return NSLocalizedString("Liters", bundle: bundle, comment: "")
			case .gallons: return discernGallons ? NSLocalizedString("Gallons (US)", bundle: bundle, comment: "") : NSLocalizedString("Gallons", comment: "")
			case .imperialGallons: return discernGallons ? NSLocalizedString("Gallons (UK)", bundle: bundle, comment: "") : NSLocalizedString("Gallons", comment: "")
			default: return ""
			}
		} else {
			switch unit {
			case .liters: return NSLocalizedString("Liter", bundle: bundle, comment: "")
			case .gallons: return discernGallons ? NSLocalizedString("Gallon (US)", bundle: bundle, comment: "") : NSLocalizedString("Gallon", comment: "")
			case .imperialGallons: return discernGallons ? NSLocalizedString("Gallon (UK)", bundle: bundle, comment: "") : NSLocalizedString("Gallon", comment: "")
			default: return ""
			}
		}
	}

	static func fuelPriceUnitDescription(_ unit: UnitVolume, bundle: Bundle = Bundle.main) -> String {
		if unit == .liters {
			return NSLocalizedString("Price per Liter", bundle: bundle, comment: "")
		} else {
			return NSLocalizedString("Price per Gallon", bundle: bundle, comment: "")
		}
	}

	static func odometerUnitDescription(_ unit: UnitLength, pluralization plural: Bool, bundle: Bundle = Bundle.main) -> String {
		if plural {
			return unit == .kilometers ? NSLocalizedString("Kilometers", bundle: bundle, comment: "") : NSLocalizedString("Miles", comment: "")
		} else {
			return unit == .kilometers ? NSLocalizedString("Kilometer", bundle: bundle, comment: "") : NSLocalizedString("Mile", comment: "")
		}
	}

}
