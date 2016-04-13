//
//  Formatters.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 01.05.15.
//
//

import UIKit

final class Formatters {
	static let sharedLongDateFormatter : NSDateFormatter = {
		let dateFormatter = NSDateFormatter()
		dateFormatter.timeStyle = .shortStyle
		dateFormatter.dateStyle = .longStyle
		return dateFormatter
	}()

	static let sharedDateFormatter : NSDateFormatter = {
		let dateFormatter = NSDateFormatter()
		dateFormatter.timeStyle = .noStyle
		dateFormatter.dateStyle = .mediumStyle
		return dateFormatter
	}()

	static let sharedDateTimeFormatter : NSDateFormatter = {
        let dateTimeFormatter = NSDateFormatter()
		dateTimeFormatter.timeStyle = .shortStyle
		dateTimeFormatter.dateStyle = .mediumStyle
		return dateTimeFormatter
    }()

	static let sharedDistanceFormatter : NSNumberFormatter = {
        let distanceFormatter = NSNumberFormatter()
        distanceFormatter.generatesDecimalNumbers = true
        distanceFormatter.numberStyle = .decimalStyle
        distanceFormatter.minimumFractionDigits = 1
        distanceFormatter.maximumFractionDigits = 1
		return distanceFormatter
    }()

	static let sharedFuelVolumeFormatter : NSNumberFormatter = {
        let fuelVolumeFormatter = NSNumberFormatter()
        fuelVolumeFormatter.generatesDecimalNumbers = true
        fuelVolumeFormatter.numberStyle = .decimalStyle
        fuelVolumeFormatter.minimumFractionDigits = 2
        fuelVolumeFormatter.maximumFractionDigits = 2
		return fuelVolumeFormatter
    }()

	static let sharedPreciseFuelVolumeFormatter : NSNumberFormatter = {
        let preciseFuelVolumeFormatter = NSNumberFormatter()
        preciseFuelVolumeFormatter.generatesDecimalNumbers = true
        preciseFuelVolumeFormatter.numberStyle = .decimalStyle
        preciseFuelVolumeFormatter.minimumFractionDigits = 3
        preciseFuelVolumeFormatter.maximumFractionDigits = 3
		return preciseFuelVolumeFormatter
    }()

	// Standard currency formatter
	static let sharedCurrencyFormatter : NSNumberFormatter = {
        let currencyFormatter = NSNumberFormatter()
        currencyFormatter.generatesDecimalNumbers = true
        currencyFormatter.numberStyle = .currencyStyle
		return currencyFormatter
    }()

	// Currency formatter with empty currency symbol for axis of statistic graphs
	static let sharedAxisCurrencyFormatter : NSNumberFormatter = {
        let axisCurrencyFormatter = NSNumberFormatter()
        axisCurrencyFormatter.generatesDecimalNumbers = true
        axisCurrencyFormatter.numberStyle = .currencyStyle
        axisCurrencyFormatter.currencySymbol = ""
		return axisCurrencyFormatter
    }()

	// Currency formatter with empty currency symbol and one additional fractional digit - used for active textfields
	static let sharedEditPreciseCurrencyFormatter : NSNumberFormatter = {
        var fractionDigits = sharedCurrencyFormatter.maximumFractionDigits

        // Don't introduce fractional digits if the currency has none
		if fractionDigits > 0 {
            fractionDigits += 1
		}

        let editPreciseCurrencyFormatter = NSNumberFormatter()
        editPreciseCurrencyFormatter.generatesDecimalNumbers = true
        editPreciseCurrencyFormatter.numberStyle = .currencyStyle
        editPreciseCurrencyFormatter.minimumFractionDigits = fractionDigits
        editPreciseCurrencyFormatter.maximumFractionDigits = fractionDigits
        editPreciseCurrencyFormatter.currencySymbol = ""

        // Needed e.g. for CHF
        editPreciseCurrencyFormatter.roundingIncrement = 0

        // Needed since NSNumberFormatters can't parse their own € output
        editPreciseCurrencyFormatter.isLenient = true

		return editPreciseCurrencyFormatter
    }()

	// Currency formatter with one additional fractional digit - used for inactive textfields
	static let sharedPreciseCurrencyFormatter : NSNumberFormatter = {
        var fractionDigits = sharedCurrencyFormatter.maximumFractionDigits

        // Don't introduce fractional digits if the currency has none
		if fractionDigits > 0 {
            fractionDigits += 1
		}

        let preciseCurrencyFormatter = NSNumberFormatter()
        preciseCurrencyFormatter.generatesDecimalNumbers = true
        preciseCurrencyFormatter.numberStyle = .currencyStyle
        preciseCurrencyFormatter.minimumFractionDigits = fractionDigits
        preciseCurrencyFormatter.maximumFractionDigits = fractionDigits

        // Needed e.g. for CHF
        preciseCurrencyFormatter.roundingIncrement = 0

        // Needed since NSNumberFormatters can't parse their own € output
        preciseCurrencyFormatter.isLenient = true

		return preciseCurrencyFormatter
    }()

	// Rounding handler for computation of average consumption
	static let sharedConsumptionRoundingHandler : NSDecimalNumberHandler = {
        let fractionDigits = sharedFuelVolumeFormatter.maximumFractionDigits
        return NSDecimalNumberHandler(
			roundingMode: .roundPlain,
			scale: Int16(fractionDigits),
			raiseOnExactness: false,
			raiseOnOverflow: false,
			raiseOnUnderflow: false,
			raiseOnDivideByZero: false)
    }()

	// Rounding handler for precise price computations
	static let sharedPriceRoundingHandler : NSDecimalNumberHandler = {
        let fractionDigits = sharedEditPreciseCurrencyFormatter.maximumFractionDigits
		return NSDecimalNumberHandler(
			roundingMode: .roundUp,
			scale: Int16(fractionDigits),
			raiseOnExactness: false,
			raiseOnOverflow: false,
			raiseOnUnderflow: false,
			raiseOnDivideByZero: false)
    }()

}
