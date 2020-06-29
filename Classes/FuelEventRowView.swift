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
    Text(fuelEvent.description)
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
