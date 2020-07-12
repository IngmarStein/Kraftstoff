//
//  CarConfigurationView.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 12.07.20.
//  Copyright © 2020 Ingmar Stein. All rights reserved.
//

import SwiftUI

struct CarConfigurationView: View {
  @State private var selectedOdometerType = 0

  var body: some View {
    Form {
      Section {
        TextField("Name", text: .constant(""))
        TextField("License Plate", text: .constant(""))
        Picker(selection: .constant(1), label: Text("Odometer Type")) {
          let odometerUnitPickerLabels = [Formatters.longMeasurementFormatter.string(from: UnitLength.kilometers).capitalized,
                          Formatters.longMeasurementFormatter.string(from: UnitLength.miles).capitalized]
          ForEach(0 ..< odometerUnitPickerLabels.count) {
            Text(odometerUnitPickerLabels[$0])
          }
        }
        TextField("Odometer Reading", text: .constant(""))
        Picker(selection: .constant(1), label: Text("Fuel Unit")) {
          let fuelUnitPickerLabels = [Formatters.longMeasurementFormatter.string(from: UnitVolume.liters).capitalized,
                                      Formatters.longMeasurementFormatter.string(from: UnitVolume.gallons).capitalized,
                                      Formatters.longMeasurementFormatter.string(from: UnitVolume.imperialGallons).capitalized]
          ForEach(0 ..< fuelUnitPickerLabels.count) {
            Text(fuelUnitPickerLabels[$0])
          }
        }
        TextField("Consumption", text: .constant(""))
      }
    }
  }
}

struct CarConfigurationView_Previews: PreviewProvider {
  static var previews: some View {
    CarConfigurationView()
  }
}
