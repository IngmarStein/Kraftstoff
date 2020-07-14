//
//  FuelEventView.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 14.07.20.
//  Copyright © 2020 Ingmar Stein. All rights reserved.
//

import SwiftUI

struct FuelEventView: View {
  var fuelEvent: FuelEvent

  @Environment(\.editMode) var editMode

  var body: some View {
    let car = fuelEvent.car!
    Form {
      Section {
        //if self.editMode == .inactive {
          //DatePicker("Date", selection: fuelEvent.timestamp)
        HStack {
          Text("Distance")
          Spacer()
          Text(Formatters.distanceFormatter.string(from: fuelEvent.ksDistance as NSNumber)! + " " + Formatters.shortMeasurementFormatter.string(from: car.ksOdometerUnit))
        }
        HStack {
          Text(Units.fuelPriceUnitDescription(car.ksFuelUnit))
          Spacer()
          Text(Formatters.preciseCurrencyFormatter.string(from: fuelEvent.ksPrice as NSNumber)!)
        }
        HStack {
          let formatter = car.ksFuelUnit == UnitVolume.liters ? Formatters.fuelVolumeFormatter : Formatters.preciseFuelVolumeFormatter
          Text(Units.fuelUnitDescription(car.ksFuelUnit, discernGallons: false, pluralization: true))
          Spacer()
          Text(formatter.string(from: fuelEvent.ksFuelVolume as NSNumber)!)
        }
        HStack {
          Text("Full Fill-up")
          Spacer()
          Text(fuelEvent.filledUp ? "Yes" : "No")
        }
        HStack {
          Text("Comment")
          Spacer()
          Text(fuelEvent.comment!)
        }
        //} else {
        //  //DatePicker("Date", selection: fuelEvent.timestamp)
        //  TextField("Distance", text: .constant(""))
        //  TextField("Price", text: .constant(""))
        //  TextField("Amount", text: .constant(""))
        //  Toggle("Fill-up", isOn: .constant(true))
        //  TextField("Comment", text: .constant(""))
        //}
      }
      // TODO: make conditional on !isEditing && filledUp && distance > 0 && fuelVolume > 0
      Section {
        ConsumptionView()
      }.font(.title3)
    }
  }
}
/*
struct FuelEventView_Previews: PreviewProvider {
    static var previews: some View {
        FuelEventView()
    }
}
*/
