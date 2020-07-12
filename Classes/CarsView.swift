//
//  CarsView.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 13.06.19.
//  Copyright © 2019 Ingmar Stein. All rights reserved.
//

import CoreData
import CoreSpotlight
import SwiftUI

struct CarsView: View {
	@Environment(\.managedObjectContext) var managedObjectContext

	@FetchRequest(fetchRequest: DataManager.fetchRequestForCars(), animation: nil)
	var cars: FetchedResults<Car>

  var body: some View {
		NavigationView {
      ZStack {
        Image("Pumps")
          .frame(maxHeight: .infinity, alignment: .bottom)
          .padding(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0)
        )
        List {
          ForEach(cars, id: \.objectID) {
            CarRowView(car: $0)
          }
          .onDelete(perform: deleteCars)
        }
        .listStyle(PlainListStyle())
        .navigationBarTitle(Text("Cars"), displayMode: .inline)
        .navigationBarItems(leading: NavigationLink("Edit", destination: CarConfigurationView()),
          trailing: Button(action: { addCar() }) {
            Image(systemName: "plus")
          }
        )
      }
		}
	}

	func addCar() {
	}

	func deleteCars(at offsets: IndexSet) {
		offsets.forEach { index in
			let deletedCar = self.cars[index]
			let deletedCarOrder = deletedCar.order

			// Invalidate preference for deleted car
			let preferredCarID = UserDefaults.standard.string(forKey: "preferredCarID")
			let deletedCarID = DataManager.modelIdentifierForManagedObject(deletedCar)

			if deletedCarID == preferredCarID {
				UserDefaults.standard.set("", forKey: "preferredCarID")
			}

			if let itemID = deletedCarID {
				CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [itemID], completionHandler: nil)
			}

			// Delete the managed object for the given index path
			self.managedObjectContext.delete(deletedCar)
			DataManager.saveContext(self.managedObjectContext)

			// Update order of existing objects
			for car in cars where car.order > deletedCarOrder {
				car.order -= 1
			}

			DataManager.saveContext(self.managedObjectContext)
		}
	}

	func editCar() {
	}

}

struct CarsView_Previews: PreviewProvider {
	static var container: NSPersistentContainer {
    return DataManager.previewContainer
	}

	static var previewCar: Car = {
		let car = Car(context: container.viewContext)
		car.distanceTotalSum = 100
		car.ksFuelConsumptionUnit = .litersPer100Kilometers
		car.ksFuelUnit = .liters
		car.ksFuelVolumeTotalSum = 100
		car.name = "Toyota IQ+"
		car.numberPlate = "SLS IO 101"
		car.odometer = 42
		car.ksOdometerUnit = .kilometers
		car.order = 0
		car.timestamp = Date()
		try! container.viewContext.save()
		return car
	}()

	static var previews: some View {
		CarsView(cars: FetchRequest<Car>(fetchRequest: DataManager.fetchRequestForCars()))
	}
}
