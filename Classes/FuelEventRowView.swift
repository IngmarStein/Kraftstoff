//
//  FuelEventRowView.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 29.06.20.
//  Copyright © 2020 Ingmar Stein. All rights reserved.
//

import CoreData
import SwiftUI

struct FuelEventRowView: View {
  var fuelEvent: FuelEvent

  var body: some View {
    NavigationLink(destination: FuelEventView(fuelEvent: fuelEvent)) {
      VStack {
        HStack {
          Formatters.dateFormatter.string(for: fuelEvent.timestamp).map(Text.init)
            .foregroundColor(Color(.label))
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.title)
          Formatters.currencyFormatter.string(from: fuelEvent.cost as NSNumber).map(Text.init)
            .foregroundColor(Color(.label))
            .font(.title2)
        }
        HStack {
          Text(distanceDescription())
            .foregroundColor(Color(.highlightedText))
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.body)
          Text(consumptionDescription())
            .foregroundColor(Color(.highlightedText))
            .font(.body)
            .accessibility(label: Text(consumptionAccessibilityLabel()))
        }
      }
      .padding(EdgeInsets(top: 15, leading: 0, bottom: 15, trailing: 0))
    }
  }

  func distanceDescription() -> String {
    let odometerUnit = fuelEvent.car!.ksOdometerUnit
    let convertedDistance: Decimal
    if odometerUnit == UnitLength.kilometers {
      convertedDistance = fuelEvent.ksDistance
    } else {
      convertedDistance = fuelEvent.ksDistance / Units.kilometersPerStatuteMile
    }

    return "\(Formatters.distanceFormatter.string(from: convertedDistance as NSNumber)!) \(Formatters.shortMeasurementFormatter.string(from: odometerUnit))"
  }

  func consumptionDescription() -> String {
    // Consumption combined with inherited data from earlier events
    let consumptionDescription: String
    let consumptionUnit = fuelEvent.car!.ksFuelConsumptionUnit
    if fuelEvent.filledUp {
      let totalDistance = fuelEvent.ksDistance + fuelEvent.ksInheritedDistance
      let totalFuelVolume = fuelEvent.ksFuelVolume + fuelEvent.ksInheritedFuelVolume

      let avg = Units.consumptionForKilometers(totalDistance, liters: totalFuelVolume, inUnit: consumptionUnit)

      consumptionDescription = Formatters.fuelVolumeFormatter.string(from: avg as NSNumber)!
    } else {
      consumptionDescription = NSLocalizedString("-", comment: "")
    }

    return "\(consumptionDescription) \(Formatters.shortMeasurementFormatter.string(from: consumptionUnit))"
  }

  func consumptionAccessibilityLabel() -> String {
    if !fuelEvent.filledUp {
      return NSLocalizedString("fuel mileage not available", comment: "")
    }

    let consumptionUnit = fuelEvent.car!.ksFuelConsumptionUnit
    let totalDistance = fuelEvent.ksDistance + fuelEvent.ksInheritedDistance
    let totalFuelVolume = fuelEvent.ksFuelVolume + fuelEvent.ksInheritedFuelVolume

    let avg = Units.consumptionForKilometers(totalDistance, liters: totalFuelVolume, inUnit: consumptionUnit)

    let consumptionDescription = Formatters.fuelVolumeFormatter.string(from: avg as NSNumber)!

    return ", \(consumptionDescription) \(Formatters.mediumMeasurementFormatter.string(from: consumptionUnit))"
  }
}

struct FuelEventRowView_Previews: PreviewProvider {
  static var container: NSPersistentContainer {
    return DataManager.previewContainer
  }

  static var previewFuelEvent: FuelEvent = {
    let fuelEvent = FuelEvent(context: container.viewContext)
    fuelEvent.distance = 200
    fuelEvent.filledUp = true
    try! container.viewContext.save()
    return fuelEvent
  }()

  static var previews: some View {
    Group {
      FuelEventRowView(fuelEvent: previewFuelEvent)
        .environment(\.sizeCategory, .medium)
        .previewLayout(.sizeThatFits)
        .previewDisplayName("medium")
      FuelEventRowView(fuelEvent: previewFuelEvent)
        .environment(\.sizeCategory, .extraLarge)
        .previewLayout(.sizeThatFits)
        .previewDisplayName("extraLarge")
    }.environment(\.managedObjectContext, container.viewContext)
  }
}
