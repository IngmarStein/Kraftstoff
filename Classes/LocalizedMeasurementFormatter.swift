//
//  LocalizedMeasurementFormatter.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 24.11.16.
//
//

import Foundation

// MeasurementFormatter currently can't localize custom units (rdar://29380963)
class LocalizedMeasurementFormatter: MeasurementFormatter {

	override func string(from unit: Unit) -> String {
		if unit.symbol.hasPrefix("gp10k") || unit.symbol == "km/l" {
			switch unitStyle {
			case .short:
				return NSLocalizedString(unit.symbol + "_short", comment: "")
			case .medium:
				return NSLocalizedString(unit.symbol + "_medium", comment: "")
			case .long:
				return NSLocalizedString(unit.symbol + "_long", comment: "")
			}
		} else {
			return super.string(from: unit)
		}
	}

}
