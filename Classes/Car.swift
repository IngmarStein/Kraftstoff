//
//  Car.swift
//
//
//  Created by Ingmar Stein on 04.05.15.
//
//

import CoreData
import Foundation

@objc(Car)
final class Car: NSManagedObject {
  var ksTimestamp: Date {
    get {
      timestamp!
    }
    set {
      timestamp = newValue
    }
  }

  var ksDistanceTotalSum: Decimal {
    get {
      distanceTotalSum! as Decimal
    }
    set {
      distanceTotalSum = newValue as NSDecimalNumber
    }
  }

  var ksFuelVolumeTotalSum: Decimal {
    get {
      fuelVolumeTotalSum! as Decimal
    }
    set {
      fuelVolumeTotalSum = newValue as NSDecimalNumber
    }
  }

  var ksOdometer: Decimal {
    get {
      odometer! as Decimal
    }
    set {
      odometer = newValue as NSDecimalNumber
    }
  }

  var ksName: String {
    name!
  }

  var ksNumberPlate: String {
    numberPlate!
  }

  var ksFuelEvents: Set<FuelEvent> {
    get {
      fuelEvents as! Set<FuelEvent>
    }
    set {
      fuelEvents = newValue as NSSet
    }
  }

  var ksFuelUnit: UnitVolume {
    get {
      .fromPersistentId(fuelUnit)
    }
    set {
      fuelUnit = newValue.persistentId
    }
  }

  var ksFuelConsumptionUnit: UnitFuelEfficiency {
    get {
      .fromPersistentId(fuelConsumptionUnit)
    }
    set {
      fuelConsumptionUnit = newValue.persistentId
    }
  }

  var ksOdometerUnit: UnitLength {
    get {
      .fromPersistentId(odometerUnit)
    }
    set {
      odometerUnit = newValue.persistentId
    }
  }

  var allFuelEvents: [FuelEvent] {
    DataManager.objectsForFetchRequest(DataManager.fetchRequestForEvents(car: self,
                                                                         afterDate: nil,
                                                                         dateMatches: false),
                                       inManagedObjectContext: managedObjectContext!)
  }

  func fuelEvents(forDate date: Date,
                  dateComparator dateCompare: (Date, Date) -> Bool) -> [FuelEvent]
  {
    guard let events = fuelEvents as? Set<FuelEvent> else { return [] }
    return events.filter { ev in dateCompare(date, ev.ksTimestamp) }.sorted { ev1, ev2 in ev1.ksTimestamp > ev2.ksTimestamp }
  }

  // Return all fuel events after a specific date.
  // Use a separate fetch request to avoid faulting in all objects.
  func fuelEvents(afterDate date: Date, dateMatches: Bool) -> [FuelEvent] {
    DataManager.objectsForFetchRequest(DataManager.fetchRequestForEvents(car: self,
                                                                         afterDate: date,
                                                                         dateMatches: dateMatches),
                                       inManagedObjectContext: managedObjectContext!)
  }

  // Return all fuel events before a specific date.
  // Use a separate fetch request to avoid faulting in all objects.
  func fuelEvents(beforeDate date: Date, dateMatches: Bool) -> [FuelEvent] {
    DataManager.objectsForFetchRequest(DataManager.fetchRequestForEvents(car: self,
                                                                         beforeDate: date,
                                                                         dateMatches: dateMatches),
                                       inManagedObjectContext: managedObjectContext!)
  }
}
