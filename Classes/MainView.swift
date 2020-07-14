//
//  TabView.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 13.06.19.
//  Copyright © 2019 Ingmar Stein. All rights reserved.
//

import SwiftUI

struct MainView: View {
  var body: some View {
    TabView {
      FuelCalculatorView(date: Date(), car: nil, lastChangeDate: Date()).tabItem {
        Image("Zapfhahn")
        Text("Fill-Up")
      }
      CarsView().tabItem {
        Image("Cars")
        Text("Cars")
      }.tag(2)
    }
  }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
