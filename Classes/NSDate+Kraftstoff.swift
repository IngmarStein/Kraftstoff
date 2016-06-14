//
//  Date+Kraftstoff.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 30.04.15.
//
//

import Foundation

// Calendar component-mask for date+time but without seconds
private let noSecondsComponentMask: Calendar.Unit = [.year, .month, .day, .hour, .minute]

// Calendar component-mask for hour+minutes
private let timeOfDayComponentMask: Calendar.Unit = [.hour, .minute]


extension Date {

	static func dateWithOffsetInMonths(_ numberOfMonths: Int, fromDate date: Date) -> Date {
		let gregorianCalendar = Calendar(calendarIdentifier: Calendar.Identifier.gregorian)!

		let noSecComponents = gregorianCalendar.components(noSecondsComponentMask, from: date)
		var deltaComponents = DateComponents()

		deltaComponents.month = numberOfMonths

		return gregorianCalendar.date(byAdding: deltaComponents,
		                              to: gregorianCalendar.date(from: noSecComponents)!,
		                              options: [])!
	}

	static func dateWithoutSeconds(_ date: Date) -> Date {
		let gregorianCalendar = Calendar(calendarIdentifier: Calendar.Identifier.gregorian)!
		let noSecComponents = gregorianCalendar.components(noSecondsComponentMask, from: date)

		return gregorianCalendar.date(from: noSecComponents)!
	}


	static func timeIntervalSinceBeginningOfDay(_ date: Date) -> TimeInterval {
		let gregorianCalendar = Calendar(calendarIdentifier: Calendar.Identifier.gregorian)!
		let timeOfDayComponents = gregorianCalendar.components(timeOfDayComponentMask, from: date)

		return TimeInterval(timeOfDayComponents.hour! * 3600 + timeOfDayComponents.minute! * 60)
	}

	static func numberOfCalendarDaysFrom(_ startDate: Date, to endDate: Date) -> Int {
		let gregorianCalendar = Calendar(calendarIdentifier: Calendar.Identifier.gregorian)!
		let referenceDate = Date(timeIntervalSinceReferenceDate: 0.0)

		let daysToStart = gregorianCalendar.components(.day, from: referenceDate, to: startDate, options: []).day
		let daysToEnd   = gregorianCalendar.components(.day, from: referenceDate, to: endDate, options: []).day

		return daysToEnd! - daysToStart! + 1
	}

}

