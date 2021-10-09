//
//  Date+Kraftstoff.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 30.04.15.
//
//

import Foundation

// Calendar component-mask for date+time but without seconds
private let noSecondsComponentMask: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute]

extension Date {
  static func dateWithOffsetInMonths(_ numberOfMonths: Int, fromDate date: Date) -> Date {
    let gregorianCalendar = Calendar(identifier: Calendar.Identifier.gregorian)

    let noSecComponents = gregorianCalendar.dateComponents(noSecondsComponentMask, from: date)
    var deltaComponents = DateComponents()

    deltaComponents.month = numberOfMonths

    return gregorianCalendar.date(byAdding: deltaComponents,
                                  to: gregorianCalendar.date(from: noSecComponents)!)!
  }

  static func dateWithoutSeconds(_ date: Date) -> Date {
    let gregorianCalendar = Calendar(identifier: Calendar.Identifier.gregorian)
    let noSecComponents = gregorianCalendar.dateComponents(noSecondsComponentMask, from: date)

    return gregorianCalendar.date(from: noSecComponents)!
  }

  static func timeIntervalSinceBeginningOfDay(_ date: Date) -> TimeInterval {
    let gregorianCalendar = Calendar(identifier: Calendar.Identifier.gregorian)
    let startOfDay = gregorianCalendar.startOfDay(for: date)

    return date.timeIntervalSince(startOfDay)
  }

  static func numberOfCalendarDaysFrom(_ startDate: Date, to endDate: Date) -> Int {
    let gregorianCalendar = Calendar(identifier: Calendar.Identifier.gregorian)

    return gregorianCalendar.dateComponents([.day], from: startDate, to: endDate).day!
  }
}
