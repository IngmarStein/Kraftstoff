//
//  NSDecimalNumber+Kraftstoff.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 30.04.15.
//
//

import UIKit

private let minusOne = NSDecimalNumber(mantissa: 1, exponent: 0, isNegative: true)

// MARK: - Comparable

extension NSDecimalNumber: Comparable {

	public static func == (lhs: NSDecimalNumber, rhs: NSDecimalNumber) -> Bool {
		return lhs.compare(rhs) == .orderedSame
	}

	public static func < (lhs: NSDecimalNumber, rhs: NSDecimalNumber) -> Bool {
		return lhs.compare(rhs) == .orderedAscending
	}

	// MARK: - Arithmetic Operators

	public static prefix func - (value: NSDecimalNumber) -> NSDecimalNumber {
		return minusOne.multiplying(by: value)
	}

	public static func + (lhs: NSDecimalNumber, rhs: NSDecimalNumber) -> NSDecimalNumber {
		return lhs.adding(rhs)
	}

	public static func - (lhs: NSDecimalNumber, rhs: NSDecimalNumber) -> NSDecimalNumber {
		return lhs.subtracting(rhs)
	}

	public static func * (lhs: NSDecimalNumber, rhs: NSDecimalNumber) -> NSDecimalNumber {
		return lhs.multiplying(by: rhs)
	}

	public static func / (lhs: NSDecimalNumber, rhs: NSDecimalNumber) -> NSDecimalNumber {
		return lhs.dividing(by: rhs)
	}

	public static func ^ (lhs: NSDecimalNumber, rhs: Int) -> NSDecimalNumber {
		return lhs.raising(toPower: rhs)
	}

	public static func << (lhs: NSDecimalNumber, rhs: Int) -> NSDecimalNumber {
		return lhs.multiplying(byPowerOf10: Int16(rhs))
	}

	public static func >> (lhs: NSDecimalNumber, rhs: Int) -> NSDecimalNumber {
		return lhs.multiplying(byPowerOf10: Int16(-rhs))
	}

}

extension NSNumber {
	public convenience init(value: CGFloat) {
		self.init(value: Float(value))
	}
}
