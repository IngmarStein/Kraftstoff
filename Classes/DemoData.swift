//
//  DemoData.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 30.04.15.
//
//

import Foundation
import CoreData

private struct DemoDataItem {
	var date: String

	var distance: UInt64       // *10^-1
	var fuelVolume: UInt64     // *10^-2
	var price: UInt64          // *10^-3
}

private let demoData = [
	DemoDataItem(date: "2009-09-25 12:00:GMT+02:00", distance: 1900, fuelVolume: 760, price: 1079),
    DemoDataItem(date: "2009-10-10 12:00:GMT+02:00", distance: 5810, fuelVolume: 2488, price: 1079),
    DemoDataItem(date: "2009-10-22 12:00:GMT+02:00", distance: 5740, fuelVolume: 2494, price: 1119),
    DemoDataItem(date: "2009-11-05 12:00:GMT+01:00", distance: 6010, fuelVolume: 2753, price: 1119),
    DemoDataItem(date: "2009-11-18 12:00:GMT+01:00", distance: 5790, fuelVolume: 2754, price: 1079),
    DemoDataItem(date: "2009-12-05 12:00:GMT+01:00", distance: 6750, fuelVolume: 3000, price: 1099),
    DemoDataItem(date: "2009-12-19 12:00:GMT+01:00", distance: 5460, fuelVolume: 2592, price: 1099),
    DemoDataItem(date: "2010-01-06 12:00:GMT+01:00", distance: 5310, fuelVolume: 2625, price: 1159),
    DemoDataItem(date: "2010-01-20 12:00:GMT+01:00", distance: 5570, fuelVolume: 2740, price: 1119),
    DemoDataItem(date: "2010-02-04 12:00:GMT+01:00", distance: 5300, fuelVolume: 2702, price: 1159),

    DemoDataItem(date: "2010-02-18 12:00:GMT+01:00", distance: 5910, fuelVolume: 2689, price: 1179),
    DemoDataItem(date: "2010-03-02 12:00:GMT+01:00", distance: 5660, fuelVolume: 2560, price: 1159),
    DemoDataItem(date: "2010-03-16 12:00:GMT+01:00", distance: 6220, fuelVolume: 2992, price: 1229),
    DemoDataItem(date: "2010-03-26 12:00:GMT+01:00", distance: 6330, fuelVolume: 2771, price: 1219),
    DemoDataItem(date: "2010-04-11 12:00:GMT+02:00", distance: 5600, fuelVolume: 2502, price: 1189),
    DemoDataItem(date: "2010-04-25 12:00:GMT+02:00", distance: 5530, fuelVolume: 2369, price: 1269),
    DemoDataItem(date: "2010-05-07 12:00:GMT+02:00", distance: 5520, fuelVolume: 2561, price: 1229),
    DemoDataItem(date: "2010-05-21 12:00:GMT+02:00", distance: 6010, fuelVolume: 2495, price: 1219),
    DemoDataItem(date: "2010-06-10 12:00:GMT+02:00", distance: 6330, fuelVolume: 2711, price: 1269),
    DemoDataItem(date: "2010-06-24 12:00:GMT+02:00", distance: 6080, fuelVolume: 2642, price: 1269),

    DemoDataItem(date: "2010-07-08 12:00:GMT+02:00", distance: 6070, fuelVolume: 2731, price: 1229),
    DemoDataItem(date: "2010-07-21 12:00:GMT+02:00", distance: 6130, fuelVolume: 2629, price: 1239),
    DemoDataItem(date: "2010-08-03 12:00:GMT+02:00", distance: 6220, fuelVolume: 2782, price: 1199),
    DemoDataItem(date: "2010-08-14 12:00:GMT+02:00", distance: 6070, fuelVolume: 2735, price: 1199),
    DemoDataItem(date: "2010-08-30 12:00:GMT+02:00", distance: 6210, fuelVolume: 2608, price: 1199),
    DemoDataItem(date: "2010-09-10 12:00:GMT+02:00", distance: 6220, fuelVolume: 2596, price: 1229),
    DemoDataItem(date: "2010-09-25 12:00:GMT+02:00", distance: 6440, fuelVolume: 2783, price: 1179),
    DemoDataItem(date: "2010-10-08 12:00:GMT+02:00", distance: 6790, fuelVolume: 2886, price: 1249),
    DemoDataItem(date: "2010-10-18 12:00:GMT+02:00", distance: 4580, fuelVolume: 2034, price: 1179),
    DemoDataItem(date: "2010-10-27 08:56:GMT+02:00", distance: 5440, fuelVolume: 2570, price: 1219),

    DemoDataItem(date: "2010-11-08 08:49:GMT+01:00", distance: 5410, fuelVolume: 2496, price: 1199),
    DemoDataItem(date: "2010-11-19 08:43:GMT+01:00", distance: 5480, fuelVolume: 2583, price: 1269),
    DemoDataItem(date: "2010-12-02 08:47:GMT+01:00", distance: 5400, fuelVolume: 2731, price: 1199),
    DemoDataItem(date: "2010-12-14 08:46:GMT+01:00", distance: 5000, fuelVolume: 2434, price: 1269),
    DemoDataItem(date: "2010-12-28 18:47:GMT+01:00", distance: 5000, fuelVolume: 2410, price: 1279),
    DemoDataItem(date: "2011-01-10 17:58:GMT+01:00", distance: 5320, fuelVolume: 2672, price: 1319),
    DemoDataItem(date: "2011-01-22 21:35:GMT+01:00", distance: 5470, fuelVolume: 2641, price: 1369),
    DemoDataItem(date: "2011-02-11 08:30:GMT+01:00", distance: 7473, fuelVolume: 3786, price: 1369),
    DemoDataItem(date: "2011-02-23 08:44:GMT+01:00", distance: 5440, fuelVolume: 2614, price: 1399),
    DemoDataItem(date: "2011-03-08 08:44:GMT+01:00", distance: 5220, fuelVolume: 2524, price: 1459),

    DemoDataItem(date: "2011-03-22 08:36:GMT+01:00", distance: 5810, fuelVolume: 2471, price: 1429),
    DemoDataItem(date: "2011-04-06 08:29:GMT+01:00", distance: 5950, fuelVolume: 2682, price: 1459),
    DemoDataItem(date: "2011-04-19 08:43:GMT+01:00", distance: 6360, fuelVolume: 2837, price: 1449),
    DemoDataItem(date: "2011-05-07 20:20:GMT+01:00", distance: 6260, fuelVolume: 2770, price: 1359),
    DemoDataItem(date: "2011-05-21 20:20:GMT+01:00", distance: 6007, fuelVolume: 2559, price: 1379),
    DemoDataItem(date: "2011-06-06 08:25:GMT+01:00", distance: 6190, fuelVolume: 2717, price: 1369),
    DemoDataItem(date: "2011-06-18 17:21:GMT+01:00", distance: 5976, fuelVolume: 2596, price: 1399),
    DemoDataItem(date: "2011-07-06 08:34:GMT+01:00", distance: 6121, fuelVolume: 2748, price: 1399),
    DemoDataItem(date: "2011-07-19 22:04:GMT+01:00", distance: 6375, fuelVolume: 2722, price: 1389),
    DemoDataItem(date: "2011-08-03 17:52:GMT+01:00", distance: 6442, fuelVolume: 2839, price: 1369),

    DemoDataItem(date: "2011-08-17 18:56:GMT+01:00", distance: 6126, fuelVolume: 2838, price: 1349),
    DemoDataItem(date: "2011-08-31 17:53:GMT+01:00", distance: 6063, fuelVolume: 2644, price: 1359),
    DemoDataItem(date: "2011-09-16 08:21:GMT+02:00", distance: 6570, fuelVolume: 2728, price: 1459),
    DemoDataItem(date: "2011-09-30 08:31:GMT+02:00", distance: 5913, fuelVolume: 2586, price: 1419),
    DemoDataItem(date: "2011-10-13 08:08:GMT+02:00", distance: 5871, fuelVolume: 2464, price: 1439),
    DemoDataItem(date: "2011-10-27 08:24:GMT+02:00", distance: 5872, fuelVolume: 2528, price: 1469),
    DemoDataItem(date: "2011-11-12 19:43:GMT+01:00", distance: 5770, fuelVolume: 2651, price: 1439),
    DemoDataItem(date: "2011-11-28 08:48:GMT+01:00", distance: 5811, fuelVolume: 2749, price: 1419),
    DemoDataItem(date: "2011-12-12 08:23:GMT+01:00", distance: 5520, fuelVolume: 2659, price: 1469),
    DemoDataItem(date: "2011-12-17 12:06:GMT+01:00", distance: 5031, fuelVolume: 2473, price: 1359),

    DemoDataItem(date: "2012-01-06 08:38:GMT+01:00", distance: 5584, fuelVolume: 2446, price: 1449),
    DemoDataItem(date: "2012-01-18 08:29:GMT+01:00", distance: 5310, fuelVolume: 2500, price: 1469),
    DemoDataItem(date: "2012-02-02 08:31:GMT+01:00", distance: 5686, fuelVolume: 2700, price: 1439),
    DemoDataItem(date: "2012-02-14 18:34:GMT+01:00", distance: 4669, fuelVolume: 2358, price: 1439),
    DemoDataItem(date: "2012-02-24 08:23:GMT+01:00", distance: 5370, fuelVolume: 2620, price: 1499),
    DemoDataItem(date: "2012-03-09 20:06:GMT+01:00", distance: 5370, fuelVolume: 2517, price: 1479),
    DemoDataItem(date: "2012-03-22 17:59:GMT+01:00", distance: 5790, fuelVolume: 2597, price: 1489),
    DemoDataItem(date: "2012-04-04 18:21:GMT+02:00", distance: 5390, fuelVolume: 2350, price: 1489),
    DemoDataItem(date: "2012-04-17 20:51:GMT+02:00", distance: 5820, fuelVolume: 2469, price: 1479),
    DemoDataItem(date: "2012-05-02 19:25:GMT+02:00", distance: 5810, fuelVolume: 2573, price: 1439),

    DemoDataItem(date: "2012-05-18 18:35:GMT+02:00", distance: 6460, fuelVolume: 2655, price: 1389),
    DemoDataItem(date: "2012-06-03 16:04:GMT+02:00", distance: 6261, fuelVolume: 2441, price: 1379),
    DemoDataItem(date: "2012-06-20 18:27:GMT+02:00", distance: 6370, fuelVolume: 2727, price: 1349),
    DemoDataItem(date: "2012-07-04 17:54:GMT+02:00", distance: 6311, fuelVolume: 2721, price: 1369),
    DemoDataItem(date: "2012-07-23 08:11:GMT+02:00", distance: 6592, fuelVolume: 2591, price: 1489),
    DemoDataItem(date: "2012-08-07 08:39:GMT+02:00", distance: 6186, fuelVolume: 2665, price: 1419),
    DemoDataItem(date: "2012-08-23 08:39:GMT+02:00", distance: 6278, fuelVolume: 2558, price: 1549),
    DemoDataItem(date: "2012-09-05 18:16:GMT+02:00", distance: 6016, fuelVolume: 2586, price: 1499),
    DemoDataItem(date: "2012-09-20 08:31:GMT+02:00", distance: 6308, fuelVolume: 2611, price: 1519),
    DemoDataItem(date: "2012-10-05 08:21:GMT+02:00", distance: 6451, fuelVolume: 3007, price: 1499),

    DemoDataItem(date: "2012-10-18 18:29:GMT+02:00", distance: 6042, fuelVolume: 2696, price: 1449),// -?
    DemoDataItem(date: "2012-11-01 18:42:GMT+01:00", distance: 6060, fuelVolume: 2655, price: 1419),
    DemoDataItem(date: "2012-11-16 16:11:GMT+01:00", distance: 5728, fuelVolume: 2652, price: 1449),
    DemoDataItem(date: "2012-11-30 08:38:GMT+01:00", distance: 5420, fuelVolume: 2536, price: 1489),
    DemoDataItem(date: "2012-12-12 08:39:GMT+01:00", distance: 5540, fuelVolume: 2533, price: 1439),
    DemoDataItem(date: "2013-01-25 08:35:GMT+01:00", distance: 5790, fuelVolume: 2665, price: 1409),
    DemoDataItem(date: "2013-02-23 20:07:GMT+01:00", distance: 5820, fuelVolume: 2701, price: 1409),
    DemoDataItem(date: "2013-03-08 08:23:GMT+01:00", distance: 5880, fuelVolume: 2567, price: 1389),
    DemoDataItem(date: "2013-03-22 17:48:GMT+01:00", distance: 5920, fuelVolume: 2772, price: 1369),
    DemoDataItem(date: "2013-04-09 18:15:GMT+02:00", distance: 5200, fuelVolume: 2381, price: 1379),// ?-

    DemoDataItem(date: "2013-04-24 18:20:GMT+02:00", distance: 6030, fuelVolume: 2809, price: 1329),
    DemoDataItem(date: "2013-05-08 18:09:GMT+02:00", distance: 6080, fuelVolume: 2806, price: 1319),
    DemoDataItem(date: "2013-05-24 08:29:GMT+02:00", distance: 5740, fuelVolume: 2521, price: 1399),// ?
    DemoDataItem(date: "2013-06-09 18:35:GMT+02:00", distance: 5840, fuelVolume: 2675, price: 1329),
    DemoDataItem(date: "2013-06-29 19:31:GMT+02:00", distance: 6260, fuelVolume: 2337, price: 1329),// ?
    DemoDataItem(date: "2013-07-16 18:10:GMT+02:00", distance: 6260, fuelVolume: 2843, price: 1389),
]

final class DemoData {

	static func addDemoEvents(car: Car, inContext context: NSManagedObjectContext) {
		let df = NSDateFormatter()

		df.locale = NSLocale.system()
		df.dateFormat = "yyyy'-'MM'-'dd' 'HH':'mm':'Z"

		autoreleasepool {
			for item in demoData {
				let newEvent = NSEntityDescription.insertNewObject(forEntityName: "fuelEvent", into: context) as NSManagedObject

				let distance = NSDecimalNumber(mantissa: item.distance, exponent: -1, isNegative: false)
				let fuelVolume = NSDecimalNumber(mantissa: item.fuelVolume, exponent: -2, isNegative: false)
				let price = NSDecimalNumber(mantissa: item.price, exponent: -3, isNegative: false)

				newEvent.setValue(df.date(from: item.date), forKey: "timestamp")
				newEvent.setValue(car, forKey: "car")
				newEvent.setValue(distance, forKey: "distance")
				newEvent.setValue(price, forKey: "price")
				newEvent.setValue(fuelVolume, forKey: "fuelVolume")

				car.distanceTotalSum = car.distanceTotalSum + distance
				car.fuelVolumeTotalSum = car.fuelVolumeTotalSum + fuelVolume
			}

			car.odometer = car.distanceTotalSum
		}
	}

}
