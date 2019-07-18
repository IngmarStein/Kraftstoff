//
//  CarRepository.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 23.06.19.
//  Copyright © 2019 Ingmar Stein. All rights reserved.
//

import SwiftUI
import Combine
import CoreData

final class CarRepository: NSObject, BindableObject, NSFetchedResultsControllerDelegate {
	var willChange = PassthroughSubject<CarRepository, Never>()
	var results = [CarViewModel]()
	var controller = NSFetchedResultsController<Car>()

	static let shared = CarRepository()

	override init() {
		super.init()

		controller = DataManager.fetchedResultsControllerForCars(delegate: self)
	}

	func controllerDidChangeContent(_: NSFetchedResultsController<NSFetchRequestResult>) {
		willChange.send(self)

		if let cars = controller.fetchedObjects {
			results = cars.map(CarViewModel.init(managedObject:))
		} else {
			results = []
		}
	}
}
