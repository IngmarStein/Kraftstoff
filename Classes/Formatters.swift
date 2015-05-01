//
//  Formatters.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 01.05.15.
//
//

import UIKit

@objc final class Formatters {
	@objc static let sharedLongDateFormatter : NSDateFormatter = {
		let dateFormatter = NSDateFormatter()
		dateFormatter.timeStyle = .ShortStyle
		dateFormatter.dateStyle = .LongStyle
		return dateFormatter
	}()

	@objc static let sharedDateFormatter : NSDateFormatter = {
		let dateFormatter = NSDateFormatter()
		dateFormatter.timeStyle = .NoStyle
		dateFormatter.dateStyle = .MediumStyle
		return dateFormatter
	}()

	@objc static let sharedDateTimeFormatter : NSDateFormatter = {
        let dateTimeFormatter = NSDateFormatter()
		dateTimeFormatter.timeStyle = .ShortStyle
		dateTimeFormatter.dateStyle = .MediumStyle
		return dateTimeFormatter
    }()

	@objc static let sharedDistanceFormatter : NSNumberFormatter = {
        let distanceFormatter = NSNumberFormatter()
        distanceFormatter.generatesDecimalNumbers = true
        distanceFormatter.numberStyle = .DecimalStyle
        distanceFormatter.minimumFractionDigits = 1
        distanceFormatter.maximumFractionDigits = 1
		return distanceFormatter
    }()

	@objc static let sharedFuelVolumeFormatter : NSNumberFormatter = {
        let fuelVolumeFormatter = NSNumberFormatter()
        fuelVolumeFormatter.generatesDecimalNumbers = true
        fuelVolumeFormatter.numberStyle = .DecimalStyle
        fuelVolumeFormatter.minimumFractionDigits = 2
        fuelVolumeFormatter.maximumFractionDigits = 2
		return fuelVolumeFormatter
    }()

	@objc static let sharedPreciseFuelVolumeFormatter : NSNumberFormatter = {
        let preciseFuelVolumeFormatter = NSNumberFormatter()
        preciseFuelVolumeFormatter.generatesDecimalNumbers = true
        preciseFuelVolumeFormatter.numberStyle = .DecimalStyle
        preciseFuelVolumeFormatter.minimumFractionDigits = 3
        preciseFuelVolumeFormatter.maximumFractionDigits = 3
		return preciseFuelVolumeFormatter
    }()

	// Standard currency formatter
	@objc static let sharedCurrencyFormatter : NSNumberFormatter = {
        let currencyFormatter = NSNumberFormatter()
        currencyFormatter.generatesDecimalNumbers = true
        currencyFormatter.numberStyle = .CurrencyStyle
		return currencyFormatter
    }()

	// Currency formatter with empty currency symbol for axis of statistic graphs
	@objc static let sharedAxisCurrencyFormatter : NSNumberFormatter = {
        let axisCurrencyFormatter = NSNumberFormatter()
        axisCurrencyFormatter.generatesDecimalNumbers = true
        axisCurrencyFormatter.numberStyle = .CurrencyStyle
        axisCurrencyFormatter.currencySymbol = ""
		return axisCurrencyFormatter
    }()

	// Currency formatter with empty currency symbol and one additional fractional digit - used for active textfields
	@objc static let sharedEditPreciseCurrencyFormatter : NSNumberFormatter = {
        var fractionDigits = sharedCurrencyFormatter.maximumFractionDigits

        // Don't introduce fractional digits if the currency has none
		if fractionDigits > 0 {
            fractionDigits += 1
		}

        let editPreciseCurrencyFormatter = NSNumberFormatter()
        editPreciseCurrencyFormatter.generatesDecimalNumbers = true
        editPreciseCurrencyFormatter.numberStyle = .CurrencyStyle
        editPreciseCurrencyFormatter.minimumFractionDigits = fractionDigits
        editPreciseCurrencyFormatter.maximumFractionDigits = fractionDigits
        editPreciseCurrencyFormatter.currencySymbol = ""

        // Needed e.g. for CHF
        editPreciseCurrencyFormatter.roundingIncrement = 0

        // Needed since NSNumberFormatters can't parse their own € output
        editPreciseCurrencyFormatter.lenient = true

		return editPreciseCurrencyFormatter
    }()

	// Currency formatter with one additional fractional digit - used for inactive textfields
	@objc static let sharedPreciseCurrencyFormatter : NSNumberFormatter = {
        var fractionDigits = sharedCurrencyFormatter.maximumFractionDigits

        // Don't introduce fractional digits if the currency has none
		if fractionDigits > 0 {
            fractionDigits += 1
		}

        let preciseCurrencyFormatter = NSNumberFormatter()
        preciseCurrencyFormatter.generatesDecimalNumbers = true
        preciseCurrencyFormatter.numberStyle = .CurrencyStyle
        preciseCurrencyFormatter.minimumFractionDigits = fractionDigits
        preciseCurrencyFormatter.maximumFractionDigits = fractionDigits

        // Needed e.g. for CHF
        preciseCurrencyFormatter.roundingIncrement = 0

        // Needed since NSNumberFormatters can't parse their own € output
        preciseCurrencyFormatter.lenient = true

		return preciseCurrencyFormatter
    }()

	// Rounding handler for computation of average consumption
	@objc static let sharedConsumptionRoundingHandler : NSDecimalNumberHandler = {
        let fractionDigits = sharedFuelVolumeFormatter.maximumFractionDigits
        return NSDecimalNumberHandler(
			roundingMode: .RoundPlain,
			scale: Int16(fractionDigits),
			raiseOnExactness: false,
			raiseOnOverflow: false,
			raiseOnUnderflow: false,
			raiseOnDivideByZero: false)
    }()

	// Rounding handler for precise price computations
	@objc static let sharedPriceRoundingHandler : NSDecimalNumberHandler = {
        let fractionDigits = sharedEditPreciseCurrencyFormatter.maximumFractionDigits
		return NSDecimalNumberHandler(
			roundingMode: .RoundUp,
			scale: Int16(fractionDigits),
			raiseOnExactness: false,
			raiseOnOverflow: false,
			raiseOnUnderflow: false,
			raiseOnDivideByZero: false)
    }()

}
