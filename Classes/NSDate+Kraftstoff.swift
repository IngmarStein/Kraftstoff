//
//  NSDate+Kraftstoff.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 30.04.15.
//
//

import Foundation

// Calendar component-mask for date+time but without seconds
private let noSecondsComponentMask: NSCalendarUnit = [.year, .month, .day, .hour, .minute]

// Calendar component-mask for hour+minutes
private let timeOfDayComponentMask: NSCalendarUnit = [.hour, .minute]


extension NSDate {

	static func dateWithOffsetInMonths(numberOfMonths: Int, fromDate date: NSDate) -> NSDate {
		let gregorianCalendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!

		let noSecComponents = gregorianCalendar.components(noSecondsComponentMask, from: date)
		let deltaComponents = NSDateComponents()

		deltaComponents.month = numberOfMonths

		return gregorianCalendar.date(byAdding: deltaComponents,
		                              to: gregorianCalendar.date(from: noSecComponents)!,
		                              options: [])!
	}

	static func dateWithoutSeconds(date: NSDate) -> NSDate {
		let gregorianCalendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
		let noSecComponents = gregorianCalendar.components(noSecondsComponentMask, from: date)

		return gregorianCalendar.date(from: noSecComponents)!
	}


	static func timeIntervalSinceBeginningOfDay(date: NSDate) -> NSTimeInterval {
		let gregorianCalendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
		let timeOfDayComponents = gregorianCalendar.components(timeOfDayComponentMask, from: date)

		return NSTimeInterval(timeOfDayComponents.hour * 3600 + timeOfDayComponents.minute * 60)
	}

	static func numberOfCalendarDaysFrom(startDate: NSDate, to endDate: NSDate) -> Int {
		let gregorianCalendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
		let referenceDate = NSDate(timeIntervalSinceReferenceDate: 0.0)

		let daysToStart = gregorianCalendar.components(.day, from: referenceDate, to: startDate, options: []).day
		let daysToEnd   = gregorianCalendar.components(.day, from: referenceDate, to: endDate, options: []).day

		return daysToEnd - daysToStart + 1
	}

}

extension NSDate: Comparable {}

public func == (lhs: NSDate, rhs: NSDate) -> Bool {
	return lhs.compare(rhs) == .orderedSame
}

public func < (lhs: NSDate, rhs: NSDate) -> Bool {
	return lhs.compare(rhs) == .orderedAscending
}
