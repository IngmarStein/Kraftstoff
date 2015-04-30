//
//  NSDecimalNumber+Kraftstoff.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 30.04.15.
//
//

import Foundation

extension NSDecimalNumber {

	func min(other: NSDecimalNumber!) -> NSDecimalNumber! {
		if other != nil && compare(other) != .OrderedAscending {
			return other
		} else {
			return self
		}
	}

	func max(other: NSDecimalNumber!) -> NSDecimalNumber! {
		if other != nil && compare(other) != .OrderedDescending {
			return other
		} else {
			return self
		}
	}

}
