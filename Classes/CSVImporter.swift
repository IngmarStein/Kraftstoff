//
//  CSVImporter.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 06.05.15.
//
//

import Foundation
import CoreData

typealias CSVRecord = [String: String]

final class CSVImporter {

	private var carIDs = Set<Int>()
	private var carForID = [Int: Car]()
	private var modelForID = [Int: String]()
	private var plateForID = [Int: String]()

	init() {}

	// MARK: - Core Data Support

	private func addCar(_ name: String, order: Int, plate: String, odometerUnit: UnitLength, volumeUnit: UnitVolume, fuelConsumptionUnit: UnitFuelEfficiency, inContext managedObjectContext: NSManagedObjectContext) -> Car {
		// Create and configure new car object
		let newCar = Car(context: managedObjectContext)

		newCar.order = Int32(order)
		newCar.timestamp = Date()
		newCar.name = name
		newCar.numberPlate = plate
		newCar.ksOdometerUnit = odometerUnit
		newCar.odometer = .zero
		newCar.ksFuelUnit = volumeUnit
		newCar.ksFuelConsumptionUnit = fuelConsumptionUnit

		return newCar
	}

	@discardableResult private func addEvent(_ car: Car, date: Date, distance: NSDecimalNumber, price: NSDecimalNumber, fuelVolume: NSDecimalNumber, inheritedCost: NSDecimalNumber, inheritedDistance: NSDecimalNumber, inheritedFuelVolume: NSDecimalNumber, filledUp: Bool, comment: String?, inContext managedObjectContext: NSManagedObjectContext) -> FuelEvent {
		let newEvent = FuelEvent(context: managedObjectContext)

		newEvent.car = car
		newEvent.timestamp = date
		newEvent.distance = distance
		newEvent.price = price
		newEvent.fuelVolume = fuelVolume
		newEvent.comment = comment

		if !filledUp {
			newEvent.filledUp = filledUp
		}

		let zero = NSDecimalNumber.zero

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

	// MARK: - Data Import Helpers

	private func guessModelFromURL(_ sourceURL: URL) -> String? {
		if sourceURL.isFileURL {
			// CSV file exported in new format: model is first part of filename
			let nameComponents = sourceURL.deletingPathExtension().lastPathComponent.components(separatedBy: "__")
			if nameComponents.count == 2 {
				let part = nameComponents[0]

				if !part.isEmpty {
					if part.characters.count > TextEditTableCell.DefaultMaximumTextFieldLength {
						return part.substring(to: part.index(part.startIndex, offsetBy: TextEditTableCell.DefaultMaximumTextFieldLength))
					} else {
						return part
					}
				}
			}
		}

		return nil
	}

	private func guessPlateFromURL(_ sourceURL: URL) -> String? {
		if sourceURL.isFileURL {
			let nameComponents = sourceURL.deletingPathExtension().lastPathComponent.components(separatedBy: "__")
			if nameComponents.count <= 2 {
				// CSV file in new format: plate is second part of filename
				//     for unknown format: use the whole filename if it is a single component
				let part = nameComponents.last!

				if !part.isEmpty {
					if part.characters.count > TextEditTableCell.DefaultMaximumTextFieldLength {
						return part.substring(to: part.index(part.startIndex, offsetBy: TextEditTableCell.DefaultMaximumTextFieldLength))
					} else {
						return part
					}
				}
			}
		}

		return nil
	}

	@discardableResult private func importCarIDs(_ records: [CSVRecord]) -> Bool {
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
			if let ID = scanNumberWithString(record["ID"])?.int32Value, !carIDs.contains(Int(ID)) {
				if let model = record[modelKey!], let plate = record["NAME"] {
					let intID = Int(ID)
					carIDs.insert(intID)
					modelForID[intID] = model
					plateForID[intID] = plate
				}
			}
		}

		return carIDs.count > previousCarIDCount
	}

	private func truncateLongString(_ str: String) -> String {
		if str.characters.count > TextEditTableCell.DefaultMaximumTextFieldLength {
			return str.substring(to: str.index(str.startIndex, offsetBy: TextEditTableCell.DefaultMaximumTextFieldLength))
		} else {
			return str
		}
	}

	private func createCarObjectsInContext(_ managedObjectContext: NSManagedObjectContext) -> Int {
		// Fetch already existing cars for later update of order attribute
		let carRequest = CoreDataManager.fetchRequestForCars()
		let fetchedCarObjects = CoreDataManager.objectsForFetchRequest(carRequest, inManagedObjectContext: managedObjectContext)

		// Create car objects
		carForID.removeAll()

		for carID in carIDs {
			let model = truncateLongString(modelForID[carID] ?? NSLocalizedString("Imported Car", comment: ""))
			let plate = truncateLongString(plateForID[carID] ?? "")

			let newCar = addCar(model,
							   order: carForID.count,
							   plate: plate,
						odometerUnit: Units.distanceUnitFromLocale,
						  volumeUnit: Units.volumeUnitFromLocale,
				 fuelConsumptionUnit: Units.fuelConsumptionUnitFromLocale,
						   inContext: managedObjectContext)

			carForID[carID] = newCar
		}

		// Now update order attribute of old car objects
		for oldCar in fetchedCarObjects {
			oldCar.order = oldCar.order + carForID.count
		}

		return carForID.count
	}

	private func guessDistanceForParsedDistance(_ distance: NSDecimalNumber, andFuelVolume liters: NSDecimalNumber) -> NSDecimalNumber {
		let convDistance = distance << 3

		if liters <= .zero {
			return distance
		}

		// consumption with parsed distance
		let rawConsumption = Units.consumptionForKilometers(distance, liters: liters, inUnit: .litersPer100Kilometers)

		if rawConsumption == .notANumber {
			return distance
		}

		// consumption with increased distance
		let convConsumption = Units.consumptionForKilometers(convDistance, liters: liters, inUnit: .litersPer100Kilometers)

		if convConsumption == .notANumber {
			return distance
		}

		// consistency checks
		let loBound = NSDecimalNumber(value: 2)
		let hiBound = NSDecimalNumber(value: 20)

		// conversion only when unconverted >= lowerBound
		if rawConsumption < hiBound {
			return distance
		}

		// conversion only when lowerBound <= convConversion <= highBound
		if convConsumption < loBound || convConsumption > hiBound {
			return distance
		}

		// converted distance is more logical
		return convDistance
	}

	@discardableResult private func importRecords(_ records: [CSVRecord], formatIsTankPro isTankProImport: Bool, detectedEvents numEvents: inout Int, inContext managedObjectContext: NSManagedObjectContext) -> Bool {
		// Analyse record headers
		let first = records.first!

		var distanceUnit: UnitLength?
		var odometerUnit: UnitLength?
		var volumeUnit: UnitVolume?

		let IDKey           = keyForCarID(first)
		let dateKey         = keyForDate(first)
		let timeKey         = keyForTime(first)
		let distanceKey     = keyForDistance(first, unit: &distanceUnit)
		let odometerKey     = keyForOdometer(first, unit: &odometerUnit)
		let volumeKey       = keyForVolume(first, unit: &volumeUnit)
		let volumeAmountKey = keyForVolume(first)
		let volumeUnitKey   = keyForVolumeUnit(first)
		let priceKey        = keyForPrice(first)
		let fillupKey       = keyForFillup(first)
		let commentKey      = keyForComment(first)

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
			if let date1 = self.scanDate(record1[dateKey!]!, withOptionalTime: record1[timeKey!]), let date2 = self.scanDate(record2[dateKey!]!, withOptionalTime: record2[timeKey!]) {
				if date1 < date2 {
					return true
				}
			}

			if let odometerKey = odometerKey, let odometer1 = self.scanNumberWithString(record1[odometerKey]), let odometer2 = self.scanNumberWithString(record2[odometerKey]) {
				if odometer1 < odometer2 {
					return true
				}
			}

			return false
		}

		// For all cars...
		for carID in carIDs {
			let car = carForID[carID]!

			var lastDate          = Date.distantPast
			var lastDelta         = TimeInterval(0.0)
			var detectedEvents    = false
			var initialFillUpSeen = false

			let zero                = NSDecimalNumber.zero
			var odometer            = zero
			var inheritedCost       = zero
			var inheritedDistance   = zero
			var inheritedFuelVolume = zero

			// For all records...
			for record in sortedRecords {
				// Match car IDs when importing from Tank Pro
				if isTankProImport {
					if NSDecimalNumber(value: carID) != scanNumberWithString(record[IDKey!]) {
						continue
					}
				}

				var date  = scanDate(record[dateKey!]!, withOptionalTime: record[timeKey!])!
				let delta = date.timeIntervalSince(lastDate)

				if delta <= 0.0 || lastDelta > 0.0 {
					lastDelta = (delta > 0.0) ? 0.0 : ceil(fabs (delta) + 60.0)
					date      = date.addingTimeInterval(lastDelta)
				}

				if date.timeIntervalSince(lastDate) <= 0.0 {
					continue
				}

				var distance: NSDecimalNumber?

				if let distanceKey = distanceKey {
					distance = scanNumberWithString(record[distanceKey])

					if distance != nil {
						distance = Units.kilometersForDistance(distance!, withUnit: distanceUnit!)
					}
				} else if let newOdometer = scanNumberWithString(record[odometerKey!]) {
					let km = Units.kilometersForDistance(newOdometer, withUnit: odometerUnit!)
					distance = km - odometer
					odometer = km
				}

				var volume: NSDecimalNumber?

				if volumeUnit != nil {
					volume = scanNumberWithString(record[volumeKey!])
					if volume != nil {
						volume = Units.litersForVolume(volume!, withUnit: volumeUnit!)
					}
				} else {
					volume = scanNumberWithString(record[volumeAmountKey!])
					if volume != nil {
						volume = Units.litersForVolume(volume!, withUnit: scanVolumeUnitWithString(record[volumeUnitKey!]))
					}
				}

				var price = scanNumberWithString(record[priceKey!])

				if isTankProImport {
					// TankPro stores total costs not the price per unit...
					if volume == nil || volume == .zero {
						price = .zero
					} else {
						price = price!.dividing(by: volume!, withBehavior: Formatters.priceRoundingHandler)
					}
				} else if price != nil {
					if volumeUnit != nil {
						price = Units.pricePerLiter(price!, withUnit: volumeUnit!)
					} else {
						price = Units.pricePerLiter(price!, withUnit: scanVolumeUnitWithString(record[volumeUnitKey!]))
					}
				}

				let filledUp = scanBooleanWithString(record[fillupKey!])

				var comment: String?
				if let commentKey = commentKey {
					comment = record[commentKey]
				}

				// For TankPro ignore events until after the first full fill-up
				if isTankProImport && !initialFillUpSeen {
					initialFillUpSeen = filledUp
					continue
				}

				// Consistency check and import
				if let distance = distance, let volume = volume, distance > zero && volume > zero {
					let convertedDistance = guessDistanceForParsedDistance(distance, andFuelVolume: volume)

					// Add event for car
					addEvent(car,
									date: date,
								distance: convertedDistance,
								   price: price!,
							  fuelVolume: volume,
						   inheritedCost: inheritedCost,
					   inheritedDistance: inheritedDistance,
					 inheritedFuelVolume: inheritedFuelVolume,
								filledUp: filledUp,
								 comment: comment,
							   inContext: managedObjectContext)

					if filledUp {
						inheritedCost       = zero
						inheritedDistance   = zero
						inheritedFuelVolume = zero
					} else {
						inheritedCost       = inheritedCost       + (volume * price!)
						inheritedDistance   = inheritedDistance   + convertedDistance
						inheritedFuelVolume = inheritedFuelVolume + volume
					}

					numEvents     += 1
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

	// MARK: - Data Import

	func `import`(_ csv: String, detectedCars numCars: inout Int, detectedEvents numEvents: inout Int, sourceURL: URL, inContext managedObjectContext: NSManagedObjectContext) -> Bool {
		let parser = CSVParser(inputCSVString: csv)

		// Check for TankPro import: search for tables containing car definitions
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

		// Not a TankPro import: create a dummy car definition
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

				importRecords(CSVTable, formatIsTankPro: importFromTankPro, detectedEvents: &numEvents, inContext: managedObjectContext)
			} else {
				break
			}
		}

		return numEvents > 0
	}

	// MARK: - Scanning Support

	private let currentNumberFormatter: NumberFormatter = {
		let nfCurrent = NumberFormatter()

		nfCurrent.generatesDecimalNumbers = true
		nfCurrent.usesGroupingSeparator = true
		nfCurrent.numberStyle = .decimal
		nfCurrent.isLenient = true
		nfCurrent.locale = Locale.current

		return nfCurrent
	}()

	private let systemNumberFormatter: NumberFormatter = {
		let nfSystem = NumberFormatter()

		nfSystem.generatesDecimalNumbers = true
		nfSystem.usesGroupingSeparator = true
		nfSystem.numberStyle = .decimal
		nfSystem.isLenient = true
		nfSystem.locale = nil

		return nfSystem
	}()

	private func scanNumberWithString(_ string: String!) -> NSDecimalNumber? {
		if string == nil {
			return nil
		}

		// Scan via NSScanner (fast, strict)
		let scanner = Scanner(string: string)

		scanner.locale = Locale.current
		scanner.scanLocation = 0

		var d = Decimal()
		if scanner.scanDecimal(&d) && scanner.isAtEnd {
			return NSDecimalNumber(decimal: d)
		}

		scanner.locale = nil
		scanner.scanLocation = 0

		if scanner.scanDecimal(&d) && scanner.isAtEnd {
			return NSDecimalNumber(decimal: d)
		}

		// Scan with localized number formatter (sloppy, catches grouping separators)
		if let dn = currentNumberFormatter.number(from: string) as? NSDecimalNumber {
			return dn
		}
		if let dn = systemNumberFormatter.number(from: string) as? NSDecimalNumber {
			return dn
		}

		return nil
	}

	private func scanDate(_ dateString: String, withOptionalTime timeString: String?) -> Date? {
		if let date = scanDateWithString(dateString) {
			if let time = timeString.flatMap({ self.scanTimeWithString($0) }) {
				return date.addingTimeInterval(Date.timeIntervalSinceBeginningOfDay(time))
			} else {
				return date.addingTimeInterval(43200)
			}
		} else {
			return nil
		}
	}

	private let systemDateFormatter: DateFormatter = {
		let df = DateFormatter()
		df.locale = nil
		df.dateFormat = "yyyy-MM-dd"
		df.isLenient = false
		return df
	}()

	private let currentDateFormatter: DateFormatter = {
		let df = DateFormatter()
		df.locale = Locale.current
		df.dateStyle = .short
		df.timeStyle = .none
		df.isLenient = true
		return df
	}()

	private let systemTimeFormatter: DateFormatter = {
		let df = DateFormatter()
		df.timeZone = TimeZone(secondsFromGMT: 0)
		df.locale = nil
		df.dateFormat = "HH:mm"
		df.isLenient = false
		return df
	}()

	private let currentTimeFormatter: DateFormatter = {
		let df = DateFormatter()
		df.timeZone = TimeZone(secondsFromGMT: 0)
		df.locale = Locale.current
		df.timeStyle = .short
		df.dateStyle = .none
		df.isLenient = true
		return df
	}()

	private func scanDateWithString(_ string: String?) -> Date? {
		guard let string = string else { return nil }

		// Strictly scan own format in system locale
		if let d = systemDateFormatter.date(from: string) {
			return d
		}

		// Alternatively scan date in short local style
		if let d = currentDateFormatter.date(from: string) {
			return d
		}

		return nil
	}

	private func scanTimeWithString(_ string: String?) -> Date? {
		guard let string = string else { return nil }

		// Strictly scan own format in system locale
		if let d = systemTimeFormatter.date(from: string) {
			return d
		}

		// Alternatively scan date in short local style
		if let d = currentTimeFormatter.date(from: string) {
			return d
		}

		return nil
	}

	private func scanBooleanWithString(_ string: String?) -> Bool {
		guard let string = string else { return true }

		if let n = scanNumberWithString(string) {
			return n != 0
		} else {
			let uppercaseString = string.uppercased()
			return uppercaseString != "NO" && uppercaseString != "NEIN"
		}
	}

	private func scanVolumeUnitWithString(_ string: String?) -> UnitVolume {
		guard let string = string else { return .liters }

		let header = CSVParser.simplifyCSVHeaderName(string)

		// Catch Tank Pro exports
		if header == "L" {
			return .liters
		}

		if header == "G" {
			// TankPro seems to export both gallons simply as "G" => search locale for feasible guess
			if Units.volumeUnitFromLocale == UnitVolume.gallons {
				return .gallons
			} else {
				return .imperialGallons
			}
		}

		// Catch some other forms of gallons
		if header.range(of: "GAL") != nil {
			if header.range(of: "US") != nil {
				return .gallons
			}

			if header.range(of: "UK") != nil {
				return .imperialGallons
			}

			if Units.volumeUnitFromLocale == UnitVolume.gallons {
				return .gallons
			} else {
				return .imperialGallons
			}
		}

		// Liters as default
		return .liters
	}

	// MARK: - Interpretation of CSV Header Names

	private func keyForDate(_ record: CSVRecord) -> String? {
		for key in [ "JJJJMMTT", "YYYYMMDD", "DATE", "DATUM", "AAAAMMJJ" ] {
			if record[key] != nil {
				return key
			}
		}

		return nil
	}

	private func keyForTime(_ record: CSVRecord) -> String? {
		for key in [ "HHMM", "TIME", "ZEIT" ] {
			if record[key] != nil {
				return key
			}
		}

		return nil
	}

	private func keyForDistance(_ record: CSVRecord, unit: inout UnitLength?) -> String? {
		for key in [ "KILOMETERS", "KILOMETER", "STRECKE", "KILOMÈTRES" ] {
			if record[key] != nil {
				unit = .kilometers
				return key
			}
		}

		for key in [ "MILES", "MEILEN" ] {
			if record[key] != nil {
				unit = .miles
				return key
			}
		}

		return nil
	}

	private func keyForOdometer(_ record: CSVRecord, unit: inout UnitLength?) -> String? {
		for key in [ "ODOMETER(KM)", "KILOMETERSTAND(KM)" ] {
			if record[key] != nil {
				unit = .kilometers
				return key
			}
        }

		for key in [ "ODOMETER(MI)", "KILOMETERSTAND(MI)" ] {
			if record[key] != nil {
				unit = .miles
				return key
			}
        }

		return nil
	}

	private func keyForVolume(_ record: CSVRecord, unit: inout UnitVolume?) -> String? {
		for key in [ "LITERS", "LITER", "TANKMENGE", "LITRES" ] {
			if record[key] != nil {
				unit = .liters
				return key
			}
        }

		for key in [ "GALLONS(US)", "GALLONEN(US)" ] {
			if record[key] != nil {
				unit = .gallons
				return key
			}
		}

		for key in [ "GALLONS(UK)", "GALLONEN(UK)" ] {
			if record[key] != nil {
				unit = .imperialGallons
				return key
			}
        }

		return nil
	}

	private func keyForVolume(_ record: CSVRecord) -> String? {
		for key in [ "GETANKT", "AMOUNTFILLED" ] {
			if record[key] != nil {
				return key
			}
		}

		return nil
	}

	private func keyForVolumeUnit(_ record: CSVRecord) -> String? {
		// 'MAFLEINHEIT' happens when Windows encoding is misinterpreted as MacRoman...
		for key in [ "MASSEINHEIT", "UNIT", "MAFLEINHEIT" ] {
			if record[key] != nil {
				return key
			}
		}

		return nil
	}

	private func keyForPrice(_ record: CSVRecord) -> String? {
		for key in [ "PRICEPERLITER", "PRICEPERGALLON", "PRICE", "PREISPROLITER", "PREISPROGALLONE", "PREIS", "KOSTEN/LITER", "PRIXPARLITRE", "PRIXPARGALLON" ] {
			if record[key] != nil {
				return key
			}
		}

		return nil
	}

	private func keyForFillup(_ record: CSVRecord) -> String? {
		for key in [ "FULLFILLUP", "VOLLGETANKT", "RÉSERVOIRPLEIN" ] {
			if record[key] != nil {
				return key
			}
		}

		return nil
	}

	private func keyForModel(_ record: CSVRecord) -> String? {
		for key in [ "MODEL", "MODELL" ] {
			if record[key] != nil {
				return key
			}
		}

		return nil
	}

	private func keyForCarID(_ record: CSVRecord) -> String? {
		for key in [ "CARID", "FAHRZEUGID" ] {
			if record[key] != nil {
				return key
			}
		}

		return nil
	}

	private func keyForComment(_ record: CSVRecord) -> String? {
		for key in [ "COMMENT", "KOMMENTAR", "COMMENTAIRE" ] {
			if record[key] != nil {
				return key
			}
		}

		return nil
	}

}
