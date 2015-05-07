//
//  CSVImporter.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 06.05.15.
//
//

import Foundation
import CoreData

typealias CSVRecord = [String:String]

public class CSVImporter {

	private var carIDs = Set<Int>()
	private var carForID = [Int : Car]()
	private var modelForID = [Int : String]()
	private var plateForID = [Int : String]()

	public init() {}

	//MARK: - Core Data Support

	private func addCarWithName(name: String, order: Int, plate: String, odometerUnit: KSDistance, volumeUnit: KSVolume, fuelConsumptionUnit: KSFuelConsumption, inContext managedObjectContext: NSManagedObjectContext) -> Car {
		// Create and configure new car object
		let newCar = NSEntityDescription.insertNewObjectForEntityForName("car", inManagedObjectContext:managedObjectContext) as! Car

		newCar.order = Int32(order)
		newCar.timestamp = NSDate()
		newCar.name = name
		newCar.numberPlate = plate
		newCar.ksOdometerUnit = odometerUnit
		newCar.odometer = NSDecimalNumber.zero()
		newCar.ksFuelUnit = volumeUnit
		newCar.ksFuelConsumptionUnit = fuelConsumptionUnit

		return newCar
	}

	private func addEventForCar(car: Car, date: NSDate, distance: NSDecimalNumber, price: NSDecimalNumber, fuelVolume: NSDecimalNumber, inheritedCost: NSDecimalNumber, inheritedDistance: NSDecimalNumber, inheritedFuelVolume: NSDecimalNumber, filledUp: Bool, inContext managedObjectContext: NSManagedObjectContext) -> FuelEvent {
		let newEvent = NSEntityDescription.insertNewObjectForEntityForName("fuelEvent", inManagedObjectContext:managedObjectContext) as! FuelEvent

		newEvent.car = car
		newEvent.timestamp = date
		newEvent.distance = distance
		newEvent.price = price
		newEvent.fuelVolume = fuelVolume

		if !filledUp {
			newEvent.filledUp = filledUp
		}

		let zero = NSDecimalNumber.zero()

		if inheritedCost != zero {
			newEvent.inheritedCost = inheritedCost
		}

		if inheritedDistance != zero {
			newEvent.inheritedDistance = inheritedDistance
		}

		if inheritedFuelVolume != zero {
			newEvent.inheritedFuelVolume = inheritedFuelVolume
		}

		car.distanceTotalSum = car.distanceTotalSum + distance
		car.fuelVolumeTotalSum = car.fuelVolumeTotalSum + fuelVolume

		return newEvent
	}

	//MARK: - Data Import Helpers

	private func guessModelFromURL(sourceURL: NSURL) -> String? {
		if sourceURL.fileURL {
			let nameComponents = sourceURL.path!.lastPathComponent.stringByDeletingPathExtension.componentsSeparatedByString("__")

			// CSV file exported in new format: model is first part of filename
			if nameComponents.count == 2 {
				let part = nameComponents[0]

				if !part.isEmpty {
					if count(part) > TextEditTableCell.maximumTextFieldLength {
						return part.substringToIndex(advance(part.startIndex, TextEditTableCell.maximumTextFieldLength))
					} else {
						return part
					}
				}
			}
		}

		return nil
	}

	private func guessPlateFromURL(sourceURL: NSURL) -> String? {
		if sourceURL.fileURL {
			let nameComponents = sourceURL.path!.lastPathComponent.stringByDeletingPathExtension.componentsSeparatedByString("__")

			// CSV file in new format: plate is second part of filename
			//     for unknown format: use the whole filename if it is a single component
			if nameComponents.count <= 2 {
				let part = nameComponents.last!

				if !part.isEmpty {
					if count(part) > TextEditTableCell.maximumTextFieldLength {
						return part.substringToIndex(advance(part.startIndex, TextEditTableCell.maximumTextFieldLength))
					} else {
						return part
					}
				}
			}
		}

		return nil
	}

	private func importCarIDs(records: [CSVRecord]) -> Bool {
		let first = records.first!

		if first.count < 3 {
			return false
		}

		if first["ID"] == nil {
			return false
		}

		let modelKey = keyForModel(first)

		if modelKey == nil {
			return false
		}

		if first["NAME"] == nil {
			return false
		}

		let previousCarIDCount = carIDs.count

		for record in records {
			if let ID = scanNumberWithString(record["ID"])?.integerValue where !carIDs.contains(ID) {
				if let model = record[modelKey!], plate = record["NAME"] {
					carIDs.insert(ID)
					modelForID[ID] = model
					plateForID[ID] = plate
				}
			}
		}

		return carIDs.count > previousCarIDCount
	}

	private func truncateLongString(str: String) -> String {
		if count(str) > TextEditTableCell.maximumTextFieldLength {
			return str.substringToIndex(advance(str.startIndex, TextEditTableCell.maximumTextFieldLength))
		} else {
			return str
		}
	}

	private func createCarObjectsInContext(managedObjectContext: NSManagedObjectContext) -> Int {
		// Fetch already existing cars for later update of order attribute
		let carRequest = AppDelegate.fetchRequestForCarsInManagedObjectContext(managedObjectContext)
		let fetchedCarObjects = AppDelegate.objectsForFetchRequest(carRequest, inManagedObjectContext:managedObjectContext) as! [Car]

		// Create car objects
		carForID.removeAll()

		for carID in carIDs {
			let model = truncateLongString(modelForID[carID] ?? NSLocalizedString("Imported Car", comment:""))
			let plate = truncateLongString(plateForID[carID] ?? "")

			let newCar = addCarWithName(model,
									 order:carForID.count,
									 plate:plate,
							  odometerUnit:Units.distanceUnitFromLocale,
								volumeUnit:Units.volumeUnitFromLocale,
					   fuelConsumptionUnit:Units.fuelConsumptionUnitFromLocale,
								 inContext:managedObjectContext)

			carForID[carID] = newCar
		}

		// Now update order attribute of old car objects
		for oldCar in fetchedCarObjects {
			oldCar.order = oldCar.order + carForID.count
		}

		return carForID.count
	}

	private func guessDistanceForParsedDistance(distance: NSDecimalNumber, andFuelVolume liters: NSDecimalNumber) -> NSDecimalNumber {
		let convDistance = distance << 3

		if NSDecimalNumber.zero().compare(liters) != .OrderedAscending {
			return distance
		}

		// consumption with parsed distance
		let rawConsumption = Units.consumptionForKilometers(distance, liters:liters, inUnit:.LitersPer100km)

		if rawConsumption == NSDecimalNumber.notANumber() {
			return distance
		}

		// consumption with increased distance
		let convConsumption = Units.consumptionForKilometers(convDistance, liters:liters, inUnit:.LitersPer100km)

		if convConsumption == NSDecimalNumber.notANumber() {
			return distance
		}

		// consistency checks
		let loBound = NSDecimalNumber(integer: 2)
		let hiBound = NSDecimalNumber(integer: 20)
    
		// conversion only when unconverted >= lowerBound
		if rawConsumption.compare(hiBound) == .OrderedAscending {
			return distance
		}

		// conversion only when lowerBound <= convConversion <= highBound
		if convConsumption.compare(loBound) == .OrderedAscending || convConsumption.compare(hiBound) == .OrderedDescending {
			return distance
		}

		// converted distance is more logical
		return convDistance
	}

	private func importRecords(records: [CSVRecord], formatIsTankPro isTankProImport: Bool, inout detectedEvents numEvents: Int, inContext managedObjectContext: NSManagedObjectContext) -> Bool {
		// Analyse record headers
		let first = records.first!

		var distanceUnit = KSDistance.Invalid
		var odometerUnit = KSDistance.Invalid
		var volumeUnit   = KSVolume.Invalid

		let IDKey           = keyForCarID(first)
		let dateKey         = keyForDate(first)
		let timeKey         = keyForTime(first)
		let distanceKey     = keyForDistance(first, unit:&distanceUnit)
		let odometerKey     = keyForOdometer(first, unit:&odometerUnit)
		let volumeKey       = keyForVolume(first, unit:&volumeUnit)
		let volumeAmountKey = keyForVolume(first)
		let volumeUnitKey   = keyForVolumeUnit(first)
		let priceKey        = keyForPrice(first)
		let fillupKey       = keyForFillup(first)

		// Common consistency check for CSV headers
		if dateKey == nil
				|| (odometerKey == nil && distanceKey == nil)
				|| (volumeKey == nil && (volumeAmountKey == nil || volumeUnitKey == nil))
				|| priceKey == nil {
			return false
		}

		// Additional consistency check for CSV headers on import from TankPro
		if isTankProImport {
			if IDKey == nil || distanceKey != nil || odometerKey == nil || volumeKey != nil || volumeUnitKey == nil || fillupKey == nil {
				return false
			}
		}

		// Sort records according time and odometer
		let sortedRecords = records.sorted { (record1, record2) -> Bool in
			if let date1 = self.scanDate(record1[dateKey!]!, withOptionalTime:record1[timeKey!]), date2 = self.scanDate(record2[dateKey!]!, withOptionalTime:record2[timeKey!]) {
				if date1.compare(date2) == .OrderedAscending {
					return true
				}
			}

			if let odometerKey = odometerKey, odometer1 = self.scanNumberWithString(record1[odometerKey]), odometer2 = self.scanNumberWithString(record2[odometerKey]) {
				if odometer1 < odometer2 {
					return true
				}
			}

			return false
		}

		// For all cars...
		for carID in carIDs {
			let car = carForID[carID]!

			var lastDate          = NSDate.distantPast() as! NSDate
			var lastDelta         = NSTimeInterval(0.0)
			var detectedEvents    = false
			var initialFillUpSeen = false

			let zero                = NSDecimalNumber.zero()
			var odometer            = zero
			var inheritedCost       = zero
			var inheritedDistance   = zero
			var inheritedFuelVolume = zero

			// For all records...
			for record in sortedRecords {
				// Match car IDs when importing from Tank Pro
				if isTankProImport {
					if carID != scanNumberWithString(record[IDKey!]) {
						continue
					}
				}

				var date  = scanDate(record[dateKey!]!, withOptionalTime:record[timeKey!])!
				let delta = date.timeIntervalSinceDate(lastDate)

				if delta <= 0.0 || lastDelta > 0.0 {
					lastDelta = (delta > 0.0) ? 0.0 : ceil(fabs (delta) + 60.0)
					date      = date.dateByAddingTimeInterval(lastDelta)
				}

				if date.timeIntervalSinceDate(lastDate) <= 0.0 {
					continue
				}

				var distance: NSDecimalNumber?

				if let distanceKey = distanceKey {
					distance = scanNumberWithString(record[distanceKey])

					if distance != nil {
						distance = Units.kilometersForDistance(distance!, withUnit:distanceUnit)
					}
				} else if let newOdometer = scanNumberWithString(record[odometerKey!]) {
					let km = Units.kilometersForDistance(newOdometer, withUnit:odometerUnit)
					distance = km - odometer
					odometer = km
				}

				var volume: NSDecimalNumber?

				if volumeUnit != .Invalid {
					volume = scanNumberWithString(record[volumeKey!])
					if volume != nil {
						volume = Units.litersForVolume(volume!, withUnit:volumeUnit)
					}
				} else {
					volume = scanNumberWithString(record[volumeAmountKey!])
					if volume != nil {
						volume = Units.litersForVolume(volume!, withUnit:scanVolumeUnitWithString(record[volumeUnitKey!]))
					}
				}

				var price = scanNumberWithString(record[priceKey!])

				if isTankProImport {
					// TankPro stores total costs not the price per unit...
					if volume == nil || volume == NSDecimalNumber.zero() {
						price = NSDecimalNumber.zero()
					} else {
						price = price!.decimalNumberByDividingBy(volume!, withBehavior:Formatters.sharedPriceRoundingHandler)
					}
				} else if price != nil {
					if volumeUnit != .Invalid {
						price = Units.pricePerLiter(price!, withUnit:volumeUnit)
					} else {
						price = Units.pricePerLiter(price!, withUnit:scanVolumeUnitWithString(record[volumeUnitKey!]))
					}
				}

				let filledUp = scanBooleanWithString(record[fillupKey!])

				// For TankPro ignore events until after the first full fill-up
				if isTankProImport && !initialFillUpSeen {
					initialFillUpSeen = filledUp
					continue
				}

				// Consistency check and import
				if let distance = distance, volume = volume where distance > zero && volume > zero {
					let convertedDistance = guessDistanceForParsedDistance(distance, andFuelVolume:volume)

					// Add event for car
					addEventForCar(car,
									date:date,
								distance:convertedDistance,
								   price:price!,
							  fuelVolume:volume,
						   inheritedCost:inheritedCost,
					   inheritedDistance:inheritedDistance,
					 inheritedFuelVolume:inheritedFuelVolume,
								filledUp:filledUp,
							   inContext:managedObjectContext)

					if filledUp {
						inheritedCost       = zero
						inheritedDistance   = zero
						inheritedFuelVolume = zero
					} else {
						inheritedCost       = inheritedCost       + (volume * price!)
						inheritedDistance   = inheritedDistance   + convertedDistance
						inheritedFuelVolume = inheritedFuelVolume + volume
					}

					numEvents      = numEvents + 1
					detectedEvents = true
					lastDate       = date
				}
			}

			// Fixup car odometer
			if detectedEvents {
				car.odometer = max(odometer, car.distanceTotalSum)
			}
		}

		return true
	}

	//MARK: - Data Import

	public func importFromCSVString(CSVString: String, inout detectedCars numCars: Int, inout detectedEvents numEvents: Int, sourceURL: NSURL, inContext managedObjectContext: NSManagedObjectContext) -> Bool {
		let parser = CSVParser(inputCSVString:CSVString)

		// Check for TankPro import:search for tables containing car definitions
		var importFromTankPro = true

		while true {
			let CSVTable = parser.parseTable()

			if CSVTable == nil {
				break
			}

			if CSVTable!.count == 0 {
				continue
			}

			importCarIDs(CSVTable!)
		}

		// Not a TankPro import:create a dummy car definition
		if carIDs.isEmpty {
			let dummyID = 0

			carIDs.insert(dummyID)
			modelForID[dummyID] = guessModelFromURL(sourceURL)
			plateForID[dummyID] = guessPlateFromURL(sourceURL)

			importFromTankPro = false
		}

		// Create objects for detected cars
		numCars = createCarObjectsInContext(managedObjectContext)

		if numCars == 0 {
			return false
		}

		// Search for tables containing data records
		parser.revertToBeginning()

		numEvents = 0

		while true {
			if let CSVTable = parser.parseTable() {
				if CSVTable.isEmpty {
					continue
				}

				importRecords(CSVTable, formatIsTankPro:importFromTankPro, detectedEvents:&numEvents, inContext:managedObjectContext)
			} else {
				break
			}
		}

		return numEvents > 0
	}

	//MARK: - Scanning Support

	private let currentNumberFormatter: NSNumberFormatter = {
		let nfCurrent = NSNumberFormatter()

		nfCurrent.generatesDecimalNumbers = true
		nfCurrent.usesGroupingSeparator = true
		nfCurrent.numberStyle = .DecimalStyle
		nfCurrent.lenient = true
		nfCurrent.locale = NSLocale.currentLocale()

		return nfCurrent
	}()

	private let systemNumberFormatter: NSNumberFormatter = {
		let nfSystem = NSNumberFormatter()

		nfSystem.generatesDecimalNumbers = true
		nfSystem.usesGroupingSeparator = true
		nfSystem.numberStyle = .DecimalStyle
		nfSystem.lenient = true
		nfSystem.locale = NSLocale.systemLocale()

		return nfSystem
	}()

	private func scanNumberWithString(string: String!) -> NSDecimalNumber? {
		if string == nil {
			return nil
		}

		// Scan via NSScanner (fast, strict)
		let scanner = NSScanner(string:string)

		scanner.locale = NSLocale.currentLocale()
		scanner.scanLocation = 0

		var d = NSDecimal()
		if scanner.scanDecimal(&d) && scanner.atEnd {
			return NSDecimalNumber(decimal:d)
		}

		scanner.locale = NSLocale.systemLocale()
		scanner.scanLocation = 0

		if scanner.scanDecimal(&d) && scanner.atEnd {
			return NSDecimalNumber(decimal:d)
		}

		// Scan with localized numberformatter (sloppy, catches grouping separators)
		if let dn = currentNumberFormatter.numberFromString(string) as? NSDecimalNumber {
			return dn
		}
		if let dn = systemNumberFormatter.numberFromString(string) as? NSDecimalNumber {
			return dn
		}

		return nil
	}

	private func scanDate(dateString: String, withOptionalTime timeString: String?) -> NSDate? {
		if let date = scanDateWithString(dateString) {
			if let time = timeString.flatMap({ self.scanTimeWithString($0) }) {
				return date.dateByAddingTimeInterval(NSDate.timeIntervalSinceBeginningOfDay(time))
			} else {
				return date.dateByAddingTimeInterval(43200)
			}
		} else {
			return nil
		}
	}

	private let systemDateFormatter: NSDateFormatter = {
		let df = NSDateFormatter()
		df.locale = NSLocale.systemLocale()
		df.dateFormat = "yyyy-MM-dd"
		df.lenient = false
		return df
	}()

	private let currentDateFormatter: NSDateFormatter = {
		let df = NSDateFormatter()
		df.locale = NSLocale.currentLocale()
		df.dateStyle = .ShortStyle
		df.timeStyle = .NoStyle
		df.lenient = true
		return df
	}()

	private let systemTimeFormatter: NSDateFormatter = {
		let df = NSDateFormatter()
		df.timeZone = NSTimeZone(forSecondsFromGMT: 0)
		df.locale = NSLocale.systemLocale()
		df.dateFormat = "HH:mm"
		df.lenient = false
		return df
	}()

	private let currentTimeFormatter: NSDateFormatter = {
		let df = NSDateFormatter()
		df.timeZone = NSTimeZone(forSecondsFromGMT: 0)
		df.locale = NSLocale.currentLocale()
		df.timeStyle = .ShortStyle
		df.dateStyle = .NoStyle
		df.lenient = true
		return df
	}()

	private func scanDateWithString(string: String!) -> NSDate? {
		if string == nil {
			return nil
		}

		// Strictly scan own format in system locale
		if let d = systemDateFormatter.dateFromString(string) {
			return d
		}

		// Alternatively scan date in short local style
		if let d = currentDateFormatter.dateFromString(string) {
			return d
		}

		return nil
	}


	private func scanTimeWithString(string: String!) -> NSDate? {
		if string == nil {
			return nil
		}

		// Strictly scan own format in system locale
		if let d = systemTimeFormatter.dateFromString(string) {
			return d
		}

		// Alternatively scan date in short local style
		if let d = currentTimeFormatter.dateFromString(string) {
			return d
		}

		return nil
	}

	private func scanBooleanWithString(string: String!) -> Bool {
		if string == nil {
			return true
		}

		if let n = scanNumberWithString(string) {
			return n != 0
		} else {
			let uppercaseString = string.uppercaseString
			return uppercaseString != "NO" && uppercaseString != "NEIN"
		}
	}

	private func scanVolumeUnitWithString(string: String!) -> KSVolume {
		if string == nil {
			return .Liter
		}

		let header = CSVParser.simplifyCSVHeaderName(string)

		// Catch Tank Pro exports
		if header == "L" {
			return .Liter
		}

		if header == "G" {
			// TankPro seems to export both gallons simply as "G" => search locale for feasible guess
			if Units.volumeUnitFromLocale == .GalUS {
				return .GalUS
			} else {
				return .GalUK
			}
		}

		// Catch some other forms of gallons
		if header.rangeOfString("GAL") != nil {
			if header.rangeOfString("US") != nil {
				return .GalUS
			}

			if header.rangeOfString("UK") != nil {
				return .GalUK
			}

			if Units.volumeUnitFromLocale == .GalUS {
				return .GalUS
			} else {
				return .GalUK
			}
		}

		// Liters as default
		return .Liter
	}

	//MARK: - Interpretation of CSV Header Names

	private func keyForDate(record: CSVRecord) -> String? {
		for key in [ "JJJJMMTT", "YYYYMMDD", "DATE", "DATUM" ] {
			if let value = record[key] {
				return key
			}
		}

		return nil
	}

	private func keyForTime(record: CSVRecord) -> String? {
		for key in [ "HHMM", "TIME", "ZEIT" ] {
			if let value = record[key] {
				return key
			}
		}

		return nil
	}

	private func keyForDistance(record: CSVRecord, inout unit: KSDistance) -> String? {
		for key in [ "KILOMETERS", "KILOMETER", "STRECKE" ] {
			if let value = record[key] {
				unit = .Kilometer
				return key
			}
		}

		for key in [ "MILES", "MEILEN" ] {
			if let value = record[key] {
				unit = .StatuteMile
				return key
			}
		}

		return nil
	}

	private func keyForOdometer(record: CSVRecord, inout unit: KSDistance) -> String? {
		for key in [ "ODOMETER(KM)", "KILOMETERSTAND(KM)" ] {
			if let value = record[key] {
				unit = .Kilometer
				return key
			}
        }

		for key in [ "ODOMETER(MI)", "KILOMETERSTAND(MI)" ] {
			if let value = record[key] {
				unit = .StatuteMile
				return key
			}
        }

		return nil
	}

	private func keyForVolume(record: CSVRecord, inout unit: KSVolume) -> String? {
		for key in [ "LITERS", "LITER", "TANKMENGE" ] {
			if let value = record[key] {
				unit = .Liter
				return key
			}
        }

		for key in [ "GALLONS(US)", "GALLONEN(US)" ] {
			if let value = record[key] {
				unit = .GalUS
				return key
			}
		}

		for key in [ "GALLONS(UK)", "GALLONEN(UK)" ] {
			if let value = record[key] {
				unit = .GalUK
				return key
			}
        }

		return nil
	}

	private func keyForVolume(record: CSVRecord) -> String? {
		for key in [ "GETANKT", "AMOUNTFILLED" ] {
			if let value = record[key] {
				return key
			}
		}

		return nil
	}

	private func keyForVolumeUnit(record: CSVRecord) -> String? {
		// 'MAFLEINHEIT' happens when Windows encoding is misinterpreted as MacRoman...
		for key in [ "MASSEINHEIT", "UNIT", "MAFLEINHEIT" ] {
			if let value = record[key] {
				return key
			}
		}

		return nil
	}

	private func keyForPrice(record: CSVRecord) -> String? {
		for key in [ "PRICEPERLITER", "PRICEPERGALLON", "PRICE", "PREISPROLITER", "PREISPROGALLONE", "PREIS", "KOSTEN/LITER" ] {
			if let value = record[key] {
				return key
			}
		}

		return nil
	}

	private func keyForFillup(record: CSVRecord) -> String? {
		for key in [ "FULLFILLUP", "VOLLGETANKT" ] {
			if let value = record[key] {
				return key
			}
		}

		return nil
	}

	private func keyForModel(record: CSVRecord) -> String? {
		for key in [ "MODEL", "MODELL" ] {
			if let value = record[key] {
				return key
			}
		}

		return nil
	}

	private func keyForCarID(record: CSVRecord) -> String? {
		for key in [ "CARID", "FAHRZEUGID" ] {
			if let value = record[key] {
				return key
			}
		}

		return nil
	}
}
