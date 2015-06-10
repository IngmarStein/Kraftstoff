//
//  NSManagedObject.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 04.05.15.
//
//

import Foundation
import CoreData

final class FuelEvent: NSManagedObject {

    @NSManaged var inheritedCost: NSDecimalNumber
    @NSManaged var distance: NSDecimalNumber
    @NSManaged var price: NSDecimalNumber
    @NSManaged var inheritedDistance: NSDecimalNumber
    @NSManaged var inheritedFuelVolume: NSDecimalNumber
    @NSManaged var timestamp: NSDate
    @NSManaged var filledUp: Bool
    @NSManaged var fuelVolume: NSDecimalNumber
    @NSManaged var car: Car

	var cost: NSDecimalNumber {
		return fuelVolume * price
	}
}
