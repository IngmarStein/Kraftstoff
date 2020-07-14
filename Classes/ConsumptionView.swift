//
//  ConsumptionView.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 14.07.20.
//  Copyright © 2020 Ingmar Stein. All rights reserved.
//

import SwiftUI

struct ConsumptionView: View {
  private var costText: Text {
    Text("cost").foregroundColor(.text) + Text("currency").foregroundColor(.highlightedText)
  }

  private var consumptionText: Text {
    Text("consumption").foregroundColor(.highlightedText) + Text("unit").foregroundColor(.text)
  }

  // This is broken into smaller expressions to avoid
  // "The compiler is unable to type-check this expression in reasonable time;
  // try breaking up the expression into distinct sub-expressions"
  var body: some View {
    costText + Text("/").foregroundColor(.text) + consumptionText
  }
}

struct ConsumptionView_Previews: PreviewProvider {
    static var previews: some View {
        ConsumptionView()
    }
}
