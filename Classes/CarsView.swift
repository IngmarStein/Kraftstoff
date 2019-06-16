//
//  CarsView.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 13.06.19.
//  Copyright © 2019 Ingmar Stein. All rights reserved.
//

import SwiftUI

struct CarsView : View {
	/*@ObjectBinding */var cars: [Car]

    var body: some View {
		List(cars.identified(by: \.objectID)) { car in
			CarRowView(car: car)
		}
    }
}

#if DEBUG
struct CarsView_Previews : PreviewProvider {
    static var previews: some View {
		CarsView(cars: [previewCar])
    }
}
#endif
