//
//  CarsView.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 13.06.19.
//  Copyright © 2019 Ingmar Stein. All rights reserved.
//

import SwiftUI

struct CarsView: View {
	/*@ObjectBinding */var cars: [CarViewModel]

    var body: some View {
		List(cars, id: \.identifier) { car in
			CarRowView(car: car)
		}
    }
}

#if DEBUG
// swiftlint:disable:next type_name
struct CarsView_Previews: PreviewProvider {
    static var previews: some View {
		CarsView(cars: [previewCar])
    }
}
#endif
