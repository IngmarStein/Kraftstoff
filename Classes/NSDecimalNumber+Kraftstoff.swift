//
//  NSDecimalNumber+Kraftstoff.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 30.04.15.
//
//

import Foundation

// MARK: - Comparable

extension NSDecimalNumber: Comparable {}

public func == (lhs: NSDecimalNumber, rhs: NSDecimalNumber) -> Bool {
	return lhs.compare(rhs) == .orderedSame
}

public func < (lhs: NSDecimalNumber, rhs: NSDecimalNumber) -> Bool {
	return lhs.compare(rhs) == .orderedAscending
}

// MARK: - Arithmetic Operators

public prefix func - (value: NSDecimalNumber) -> NSDecimalNumber {
	return NSDecimalNumber.zero().subtracting(value)
}

public func + (lhs: NSDecimalNumber, rhs: NSDecimalNumber) -> NSDecimalNumber {
	return lhs.adding(rhs)
}

public func - (lhs: NSDecimalNumber, rhs: NSDecimalNumber) -> NSDecimalNumber {
	return lhs.subtracting(rhs)
}

public func * (lhs: NSDecimalNumber, rhs: NSDecimalNumber) -> NSDecimalNumber {
	return lhs.multiplying(by: rhs)
}

public func / (lhs: NSDecimalNumber, rhs: NSDecimalNumber) -> NSDecimalNumber {
	return lhs.dividing(by: rhs)
}

public func ^ (lhs: NSDecimalNumber, rhs: Int) -> NSDecimalNumber {
	return lhs.raising(toPower: rhs)
}

public func << (lhs: NSDecimalNumber, rhs: Int) -> NSDecimalNumber {
	return lhs.multiplying(byPowerOf10: Int16(rhs))
}

public func >> (lhs: NSDecimalNumber, rhs: Int) -> NSDecimalNumber {
	return lhs.multiplying(byPowerOf10: Int16(-rhs))
}
