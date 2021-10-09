//
//  NSManagedObject.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 04.05.15.
//
//

import CoreData
import Foundation

@objc(FuelEvent)
final class FuelEvent: NSManagedObject {
  var ksInheritedCost: Decimal {
    get {
      inheritedCost! as Decimal
    }
    set {
      inheritedCost = newValue as NSDecimalNumber
    }
  }

  var ksDistance: Decimal {
    get {
      distance! as Decimal
    }
    set {
      distance = newValue as NSDecimalNumber
    }
  }

  var ksPrice: Decimal {
    get {
      price! as Decimal
    }
    set {
      price = newValue as NSDecimalNumber
    }
  }

  var ksInheritedDistance: Decimal {
    get {
      inheritedDistance! as Decimal
    }
    set {
      inheritedDistance = newValue as NSDecimalNumber
    }
  }

  var ksInheritedFuelVolume: Decimal {
    get {
      inheritedFuelVolume! as Decimal
    }
    set {
      inheritedFuelVolume = newValue as NSDecimalNumber
    }
  }

  var ksTimestamp: Date {
    get {
      timestamp!
    }
    set {
      timestamp = newValue
    }
  }

  var ksFuelVolume: Decimal {
    get {
      fuelVolume! as Decimal
    }
    set {
      fuelVolume = newValue as NSDecimalNumber
    }
  }

  var cost: Decimal {
    ksFuelVolume * ksPrice
  }

  var ksComment: String {
    get {
      comment!
    }
    set {
      comment = newValue
    }
  }
}
