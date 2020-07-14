//
//  NSManagedObject.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 04.05.15.
//
//

import Foundation
import CoreData

@objc(FuelEvent)
final class FuelEvent: NSManagedObject {

  var ksInheritedCost: Decimal {
    get {
      return inheritedCost! as Decimal
    }
    set {
      inheritedCost = newValue as NSDecimalNumber
    }
   }

  var ksDistance: Decimal {
    get {
      return distance! as Decimal
    }
    set {
      distance = newValue as NSDecimalNumber
    }
   }

  var ksPrice: Decimal {
    get {
      return price! as Decimal
    }
    set {
      price = newValue as NSDecimalNumber
    }
   }

  var ksInheritedDistance: Decimal {
    get {
      return inheritedDistance! as Decimal
    }
    set {
      inheritedDistance = newValue as NSDecimalNumber
    }
   }

  var ksInheritedFuelVolume: Decimal {
    get {
      return inheritedFuelVolume! as Decimal
    }
    set {
      inheritedFuelVolume = newValue as NSDecimalNumber
    }
   }

  var ksTimestamp: Date {
    get {
      return timestamp!
    }
    set {
      timestamp = newValue
    }
   }

  var ksFuelVolume: Decimal {
    get {
      return fuelVolume! as Decimal
    }
    set {
      fuelVolume = newValue as NSDecimalNumber
    }
   }

  var cost: Decimal {
    return ksFuelVolume * ksPrice
  }

}
