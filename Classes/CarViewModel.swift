//
//  CarViewModel.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 19.06.19.
//  Copyright © 2019 Ingmar Stein. All rights reserved.
//

import Foundation

struct CarViewModel {
	var distanceTotalSum: Decimal
	var fuelConsumptionUnit: UnitFuelEfficiency
	var fuelUnit: UnitVolume
	var fuelVolumeTotalSum: Decimal
	var identifier: String
	var name: String
	var numberPlate: String
	var odometer: Decimal
	var odometerUnit: UnitLength
	var order: Int
	var timestamp: Date
	//var fuelEvents: Set<FuelEventViewModel>

	init(managedObject: Car) {
		distanceTotalSum = managedObject.ksDistanceTotalSum
		fuelUnit = managedObject.ksFuelUnit
		fuelConsumptionUnit = managedObject.ksFuelConsumptionUnit
		fuelVolumeTotalSum = managedObject.ksFuelVolumeTotalSum
		identifier = DataManager.modelIdentifierForManagedObject(managedObject) ?? ""
		name = managedObject.name ?? ""
		numberPlate = managedObject.numberPlate ?? ""
		odometer = managedObject.ksOdometer
		odometerUnit = managedObject.ksOdometerUnit
		order = Int(managedObject.order)
		timestamp = managedObject.ksTimestamp
		//fuelEvents = managedObject.fuelEvents?.map(FuelEventViewModel.init)
	}

	init(distanceTotalSum: Decimal,
		 fuelConsumptionUnit: UnitFuelEfficiency,
		 fuelUnit: UnitVolume,
		 fuelVolumeTotalSum: Decimal,
		 identifier: String,
		 name: String,
		 numberPlate: String,
		 odometer: Decimal,
		 odometerUnit: UnitLength,
		 order: Int,
		 timestamp: Date) {
		self.distanceTotalSum = distanceTotalSum
		self.fuelUnit = fuelUnit
		self.fuelConsumptionUnit = fuelConsumptionUnit
		self.fuelVolumeTotalSum = fuelVolumeTotalSum
		self.identifier = identifier
		self.name = name
		self.numberPlate = numberPlate
		self.odometer = odometer
		self.odometerUnit = odometerUnit
		self.order = order
		self.timestamp = timestamp
		//self.fuelEvents = managedObject.fuelEvents?.map(FuelEventViewModel.init)
	}

}
