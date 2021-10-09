//
//  CarRowView.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 13.06.19.
//  Copyright © 2019 Ingmar Stein. All rights reserved.
//

import CoreData
import SwiftUI

struct CarRowView: View {
  var car: Car

  @Environment(\.editMode) var editMode

  var body: some View {
    // let destination: View = (self.editMode == .inactive ? FuelEventsView(car: car) : CarConfigurationView())
    NavigationLink(destination: FuelEventsView(car: car)) {
      VStack {
        HStack {
          Text(car.ksName)
            .foregroundColor(Color.label)
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.title)
          Text(averageConsumption)
            .foregroundColor(Color.label)
            .font(.title)
            .accessibility(label: Text(averageConsumptionAccessibilityLabel))
        }
        HStack {
          Text(car.ksNumberPlate)
            .foregroundColor(Color.highlightedText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.body)
          Text(Formatters.shortMeasurementFormatter.string(from: car.ksFuelConsumptionUnit))
            .foregroundColor(Color.highlightedText)
            .font(.body)
        }
      }
      .padding(EdgeInsets(top: 15, leading: 0, bottom: 15, trailing: 0))
    }
  }

  var averageConsumption: String {
    let distance = car.ksDistanceTotalSum
    let fuelVolume = car.ksFuelVolumeTotalSum

    if distance > 0, fuelVolume > 0 {
      return Formatters.fuelVolumeFormatter.string(from: Units.consumptionForKilometers(distance, liters: fuelVolume, inUnit: car.ksFuelConsumptionUnit) as NSNumber)!
    } else {
      return "-"
    }
  }

  var averageConsumptionAccessibilityLabel: String {
    let avgConsumption = averageConsumption
    if avgConsumption == "-" {
      return "fuel mileage not available"
    }
    return avgConsumption
  }
}

struct CarRowView_Previews: PreviewProvider {
  static var container: NSPersistentContainer {
    DataManager.previewContainer
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
    Group {
      CarRowView(car: previewCar)
        .environment(\.sizeCategory, .medium)
        .previewLayout(.sizeThatFits)
        .previewDisplayName("medium")
      CarRowView(car: previewCar)
        .environment(\.sizeCategory, .extraLarge)
        .previewLayout(.sizeThatFits)
        .previewDisplayName("extraLarge")
    }.environment(\.managedObjectContext, container.viewContext)
  }
}
