//
//  Formatters.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 01.05.15.
//
//

import UIKit

final class Formatters {
	static let sharedLongDateFormatter: DateFormatter = {
		let dateFormatter = DateFormatter()
		dateFormatter.timeStyle = .shortStyle
		dateFormatter.dateStyle = .longStyle
		return dateFormatter
	}()

	static let sharedDateFormatter: DateFormatter = {
		let dateFormatter = DateFormatter()
		dateFormatter.timeStyle = .noStyle
		dateFormatter.dateStyle = .mediumStyle
		return dateFormatter
	}()

	static let sharedDateTimeFormatter: DateFormatter = {
        let dateTimeFormatter = DateFormatter()
		dateTimeFormatter.timeStyle = .shortStyle
		dateTimeFormatter.dateStyle = .mediumStyle
		return dateTimeFormatter
    }()

	static let sharedDistanceFormatter: NumberFormatter = {
        let distanceFormatter = NumberFormatter()
        distanceFormatter.generatesDecimalNumbers = true
        distanceFormatter.numberStyle = .decimal
        distanceFormatter.minimumFractionDigits = 1
        distanceFormatter.maximumFractionDigits = 1
		return distanceFormatter
    }()

	static let sharedFuelVolumeFormatter: NumberFormatter = {
        let fuelVolumeFormatter = NumberFormatter()
        fuelVolumeFormatter.generatesDecimalNumbers = true
        fuelVolumeFormatter.numberStyle = .decimal
        fuelVolumeFormatter.minimumFractionDigits = 2
        fuelVolumeFormatter.maximumFractionDigits = 2
		return fuelVolumeFormatter
    }()

	static let sharedPreciseFuelVolumeFormatter: NumberFormatter = {
        let preciseFuelVolumeFormatter = NumberFormatter()
        preciseFuelVolumeFormatter.generatesDecimalNumbers = true
        preciseFuelVolumeFormatter.numberStyle = .decimal
        preciseFuelVolumeFormatter.minimumFractionDigits = 3
        preciseFuelVolumeFormatter.maximumFractionDigits = 3
		return preciseFuelVolumeFormatter
    }()

	// Standard currency formatter
	static let sharedCurrencyFormatter: NumberFormatter = {
        let currencyFormatter = NumberFormatter()
        currencyFormatter.generatesDecimalNumbers = true
        currencyFormatter.numberStyle = .currency
		return currencyFormatter
    }()

	// Currency formatter with empty currency symbol for axis of statistic graphs
	static let sharedAxisCurrencyFormatter: NumberFormatter = {
        let axisCurrencyFormatter = NumberFormatter()
        axisCurrencyFormatter.generatesDecimalNumbers = true
        axisCurrencyFormatter.numberStyle = .currency
        axisCurrencyFormatter.currencySymbol = ""
		return axisCurrencyFormatter
    }()

	// Currency formatter with empty currency symbol and one additional fractional digit - used for active textfields
	static let sharedEditPreciseCurrencyFormatter: NumberFormatter = {
        var fractionDigits = sharedCurrencyFormatter.maximumFractionDigits

        // Don't introduce fractional digits if the currency has none
		if fractionDigits > 0 {
            fractionDigits += 1
		}

        let editPreciseCurrencyFormatter = NumberFormatter()
        editPreciseCurrencyFormatter.generatesDecimalNumbers = true
        editPreciseCurrencyFormatter.numberStyle = .currency
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
	static let sharedPreciseCurrencyFormatter: NumberFormatter = {
        var fractionDigits = sharedCurrencyFormatter.maximumFractionDigits

        // Don't introduce fractional digits if the currency has none
		if fractionDigits > 0 {
            fractionDigits += 1
		}

        let preciseCurrencyFormatter = NumberFormatter()
        preciseCurrencyFormatter.generatesDecimalNumbers = true
        preciseCurrencyFormatter.numberStyle = .currency
        preciseCurrencyFormatter.minimumFractionDigits = fractionDigits
        preciseCurrencyFormatter.maximumFractionDigits = fractionDigits

        // Needed e.g. for CHF
        preciseCurrencyFormatter.roundingIncrement = 0

        // Needed since NSNumberFormatters can't parse their own € output
        preciseCurrencyFormatter.isLenient = true

		return preciseCurrencyFormatter
    }()

	// Rounding handler for computation of average consumption
	static let sharedConsumptionRoundingHandler: NSDecimalNumberHandler = {
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
	static let sharedPriceRoundingHandler: NSDecimalNumberHandler = {
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
