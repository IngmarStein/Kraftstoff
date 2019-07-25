//
//  FuelEventViewModel.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 19.06.19.
//  Copyright © 2019 Ingmar Stein. All rights reserved.
//

import Foundation

struct FuelEventViewModel {

	var comment: String?
	var distance: Decimal
	var filledUp: Bool
	var fuelVolume: Decimal
	var inheritedCost: Decimal
	var inheritedDistance: Decimal
	var inheritedFuelVolume: Decimal
	var price: Decimal
	var timestamp: Date
	//var carIdentifier: String

	init(managedObject: FuelEvent) {
		comment = managedObject.comment
		distance = managedObject.ksDistance
		filledUp = managedObject.filledUp
		fuelVolume = managedObject.ksFuelVolume
		inheritedCost = managedObject.ksInheritedCost
		inheritedDistance = managedObject.ksDistance
		inheritedFuelVolume = managedObject.ksFuelVolume
		price = managedObject.ksPrice
		timestamp = managedObject.ksTimestamp
		//carIdentifier = DataManager.modelIdentifierForManagedObject(managedObject.car)
	}

}
