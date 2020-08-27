//
//  Car.swift
//
//
//  Created by Ingmar Stein on 04.05.15.
//
//

import Foundation
import CoreData

@objc(Car)
final class Car: NSManagedObject {

  var ksTimestamp: Date {
    get {
      return timestamp!
    }
    set {
      timestamp = newValue
    }
  }

  var ksDistanceTotalSum: Decimal {
    get {
      return distanceTotalSum! as Decimal
    }
    set {
      distanceTotalSum = newValue as NSDecimalNumber
    }
  }

  var ksFuelVolumeTotalSum: Decimal {
    get {
      return fuelVolumeTotalSum! as Decimal
    }
    set {
      fuelVolumeTotalSum = newValue as NSDecimalNumber
    }
  }

  var ksOdometer: Decimal {
    get {
      return odometer! as Decimal
    }
    set {
      odometer = newValue as NSDecimalNumber
    }
  }

  var ksName: String {
    return name!
  }

  var ksNumberPlate: String {
    return numberPlate!
  }

  var ksFuelEvents: Set<FuelEvent> {
    get {
      return fuelEvents as! Set<FuelEvent>
    }
    set {
      fuelEvents = newValue as NSSet
    }
  }

  var ksFuelUnit: UnitVolume {
    get {
      return .fromPersistentId(fuelUnit)
    }
    set {
      fuelUnit = newValue.persistentId
    }
  }

  var ksFuelConsumptionUnit: UnitFuelEfficiency {
    get {
      return .fromPersistentId(fuelConsumptionUnit)
    }
    set {
      fuelConsumptionUnit = newValue.persistentId
    }
  }

  var ksOdometerUnit: UnitLength {
    get {
      return .fromPersistentId(odometerUnit)
    }
    set {
      odometerUnit = newValue.persistentId
    }
  }

  var allFuelEvents: [FuelEvent] {
    return DataManager.objectsForFetchRequest(DataManager.fetchRequestForEvents(car: self,
                                          afterDate: nil,
                                          dateMatches: false),
                          inManagedObjectContext: self.managedObjectContext!)
  }

  func fuelEvents(forDate date: Date,
                  dateComparator dateCompare: (Date, Date) -> Bool) -> [FuelEvent] {
    guard let events = fuelEvents as? Set<FuelEvent> else { return [] }
    return events.filter { ev in dateCompare(date, ev.ksTimestamp) }.sorted { ev1, ev2 in ev1.ksTimestamp > ev2.ksTimestamp  }
  }

  // Return all fuel events after a specific date.
  // Use a separate fetch request to avoid faulting in all objects.
  func fuelEvents(afterDate date: Date, dateMatches: Bool) -> [FuelEvent] {
    return DataManager.objectsForFetchRequest(DataManager.fetchRequestForEvents(car: self,
                                          afterDate: date,
                                          dateMatches: dateMatches),
      inManagedObjectContext: self.managedObjectContext!)
  }

  // Return all fuel events before a specific date.
  // Use a separate fetch request to avoid faulting in all objects.
  func fuelEvents(beforeDate date: Date, dateMatches: Bool) -> [FuelEvent] {
    return DataManager.objectsForFetchRequest(DataManager.fetchRequestForEvents(car: self,
                                          beforeDate: date,
                                          dateMatches: dateMatches),
                          inManagedObjectContext: self.managedObjectContext!)
  }

}
