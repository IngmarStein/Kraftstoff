//
//  TabView.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 13.06.19.
//  Copyright © 2019 Ingmar Stein. All rights reserved.
//

import SwiftUI

struct MainView: View {
  @Binding var selectedTab: Int

  var body: some View {
    TabView(selection: $selectedTab) {
      FuelCalculatorView(date: Date(), car: nil, lastChangeDate: Date()).tabItem {
        Image("Zapfhahn")
        Text("Fill-Up")
      }.tag(0)
      CarsView().tabItem {
        Image("Cars")
        Text("Cars")
      }.tag(1)
    }
  }
}

struct MainView_Previews: PreviewProvider {
  static var previews: some View {
    MainView(selectedTab: .constant(0))
  }
}
