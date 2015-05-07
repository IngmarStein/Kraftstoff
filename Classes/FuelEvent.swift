//
//  NSManagedObject.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 04.05.15.
//
//

import Foundation
import CoreData

public class FuelEvent: NSManagedObject {

    @NSManaged public var inheritedCost: NSDecimalNumber
    @NSManaged public var distance: NSDecimalNumber
    @NSManaged public var price: NSDecimalNumber
    @NSManaged public var inheritedDistance: NSDecimalNumber
    @NSManaged public var inheritedFuelVolume: NSDecimalNumber
    @NSManaged public var timestamp: NSDate
    @NSManaged public var filledUp: Bool
    @NSManaged public var fuelVolume: NSDecimalNumber
    @NSManaged public var car: Car

	public var cost: NSDecimalNumber {
		return fuelVolume * price
	}
}
