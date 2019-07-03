//
//  TabView.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 13.06.19.
//  Copyright © 2019 Ingmar Stein. All rights reserved.
//

import SwiftUI

struct TabView : View {
    var body: some View {
		NavigationView {
			TabbedView {
				FuelCalculatorView(cars: [], date: Date(), car: nil, lastChangeDate: Date())
					.tabItem {
						Image("Zapfhahn")
						Text("Fill-Up")
					}.tag(1)
				//CarsView([]).tabItemLabel(Image("Cars")).tag(2)
			}
		}
    }
}

#if DEBUG
struct TabView_Previews : PreviewProvider {
    static var previews: some View {
        TabView()
    }
}
#endif
