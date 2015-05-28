//
//  NSDate+Kraftstoff.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 30.04.15.
//
//

import Foundation

// Calendar component-mask for date+time but without seconds
private let noSecondsComponentMask : NSCalendarUnit = (.CalendarUnitYear | .CalendarUnitMonth | .CalendarUnitDay | .CalendarUnitHour | .CalendarUnitMinute)

// Calendar component-mask for hour+minutes
private let timeOfDayComponentMask : NSCalendarUnit = (.CalendarUnitHour | .CalendarUnitMinute)


extension NSDate {

	static func dateWithOffsetInMonths(numberOfMonths: Int, fromDate date: NSDate) -> NSDate {
		let gregorianCalendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
    
		let noSecComponents = gregorianCalendar.components(noSecondsComponentMask, fromDate: date)
		let deltaComponents = NSDateComponents()

		deltaComponents.month = numberOfMonths

		return gregorianCalendar.dateByAddingComponents(deltaComponents,
														toDate:gregorianCalendar.dateFromComponents(noSecComponents)!,
														options:.allZeros)!
	}

	static func dateWithoutSeconds(date: NSDate) -> NSDate {
		let gregorianCalendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
		let noSecComponents = gregorianCalendar.components(noSecondsComponentMask, fromDate: date)

		return gregorianCalendar.dateFromComponents(noSecComponents)!
	}


	static func timeIntervalSinceBeginningOfDay(date: NSDate) -> NSTimeInterval {
		let gregorianCalendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
		let timeOfDayComponents = gregorianCalendar.components(timeOfDayComponentMask, fromDate: date)
    
		return NSTimeInterval(timeOfDayComponents.hour * 3600 + timeOfDayComponents.minute * 60)
	}

	static func numberOfCalendarDaysFrom(startDate: NSDate, to endDate: NSDate) -> Int {
		let gregorianCalendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
		let referenceDate = NSDate(timeIntervalSinceReferenceDate: 0.0)

		let daysToStart = gregorianCalendar.components(.CalendarUnitDay, fromDate:referenceDate, toDate:startDate, options:.allZeros).day
		let daysToEnd   = gregorianCalendar.components(.CalendarUnitDay, fromDate:referenceDate, toDate:endDate, options:.allZeros).day
    
		return daysToEnd - daysToStart + 1
	}

}

extension NSDate: Comparable {}

public func ==(lhs: NSDate, rhs: NSDate) -> Bool {
	return lhs.compare(rhs) == .OrderedSame
}

public func <(lhs: NSDate, rhs: NSDate) -> Bool {
	return lhs.compare(rhs) == .OrderedAscending
}
