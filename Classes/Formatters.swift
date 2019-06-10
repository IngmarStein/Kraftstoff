//
//  Formatters.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 01.05.15.
//
//

import UIKit

final class Formatters {

	static let shortMeasurementFormatter: MeasurementFormatter = {
		let measurementFormatter = MeasurementFormatter()
		measurementFormatter.unitStyle = .short
		return measurementFormatter
	}()

	static let mediumMeasurementFormatter: MeasurementFormatter = {
		let measurementFormatter = MeasurementFormatter()
		measurementFormatter.unitStyle = .medium
		return measurementFormatter
	}()

	static let longMeasurementFormatter: MeasurementFormatter = {
		let measurementFormatter = MeasurementFormatter()
		measurementFormatter.unitStyle = .long
		return measurementFormatter
	}()

	static let longDateFormatter: DateFormatter = {
		let dateFormatter = DateFormatter()
		dateFormatter.timeStyle = .short
		dateFormatter.dateStyle = .long
		return dateFormatter
	}()

	static let dateFormatter: DateFormatter = {
		let dateFormatter = DateFormatter()
		dateFormatter.timeStyle = .none
		dateFormatter.dateStyle = .medium
		return dateFormatter
	}()

	static let dateTimeFormatter: DateFormatter = {
		let dateTimeFormatter = DateFormatter()
		dateTimeFormatter.timeStyle = .short
		dateTimeFormatter.dateStyle = .medium
		return dateTimeFormatter
    }()

	static let distanceFormatter: NumberFormatter = {
		let distanceFormatter = NumberFormatter()
		distanceFormatter.generatesDecimalNumbers = true
		distanceFormatter.numberStyle = .decimal
		distanceFormatter.minimumFractionDigits = 1
		distanceFormatter.maximumFractionDigits = 1
		return distanceFormatter
    }()

	static let fuelVolumeFormatter: NumberFormatter = {
        let fuelVolumeFormatter = NumberFormatter()
        fuelVolumeFormatter.generatesDecimalNumbers = true
        fuelVolumeFormatter.numberStyle = .decimal
        fuelVolumeFormatter.minimumFractionDigits = 2
        fuelVolumeFormatter.maximumFractionDigits = 2
		return fuelVolumeFormatter
    }()

	static let preciseFuelVolumeFormatter: NumberFormatter = {
        let preciseFuelVolumeFormatter = NumberFormatter()
        preciseFuelVolumeFormatter.generatesDecimalNumbers = true
        preciseFuelVolumeFormatter.numberStyle = .decimal
        preciseFuelVolumeFormatter.minimumFractionDigits = 3
        preciseFuelVolumeFormatter.maximumFractionDigits = 3
		return preciseFuelVolumeFormatter
    }()

	// Standard currency formatter
	static let currencyFormatter: NumberFormatter = {
        let currencyFormatter = NumberFormatter()
        currencyFormatter.generatesDecimalNumbers = true
        currencyFormatter.numberStyle = .currency
		return currencyFormatter
    }()

	// Currency formatter with empty currency symbol for axis of statistic graphs
	static let axisCurrencyFormatter: NumberFormatter = {
        let axisCurrencyFormatter = NumberFormatter()
        axisCurrencyFormatter.generatesDecimalNumbers = true
        axisCurrencyFormatter.numberStyle = .currency
        axisCurrencyFormatter.currencySymbol = ""
		return axisCurrencyFormatter
    }()

	// Currency formatter with empty currency symbol and one additional fractional digit - used for active textfields
	static let editPreciseCurrencyFormatter: NumberFormatter = {
        var fractionDigits = currencyFormatter.maximumFractionDigits

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
	static let preciseCurrencyFormatter: NumberFormatter = {
        var fractionDigits = currencyFormatter.maximumFractionDigits

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
	static let consumptionRoundingHandler = NSDecimalNumberHandler(
		roundingMode: .plain,
		scale: Int16(fuelVolumeFormatter.maximumFractionDigits),
		raiseOnExactness: false,
		raiseOnOverflow: false,
		raiseOnUnderflow: false,
		raiseOnDivideByZero: false)

	// Rounding handler for precise price computations
	static let priceRoundingHandler = NSDecimalNumberHandler(
		roundingMode: .up,
		scale: Int16(editPreciseCurrencyFormatter.maximumFractionDigits),
		raiseOnExactness: false,
		raiseOnOverflow: false,
		raiseOnUnderflow: false,
		raiseOnDivideByZero: false)

}
