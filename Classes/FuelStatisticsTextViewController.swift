//
//  FuelStatisticsTextViewController.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 05.05.15.
//
//  Textual Statistics View Controller

import UIKit
import CoreData

private let GridLines = 16
private let GridMargin: CGFloat = 16.0
private let GridTextXMargin: CGFloat = 10.0
private let GridTextHeight: CGFloat = 23.0

// MARK: - Disposable Sampling Data Objects for ContentCache

private final class FuelStatisticsData: DiscardableDataObject {
	var car: Car!

	var firstDate: Date!
	var lastDate: Date!

	var totalCost = NSDecimalNumber.zero()
	var totalFuelVolume = NSDecimalNumber.zero()
	var totalDistance = NSDecimalNumber.zero()

	var avgConsumption = NSDecimalNumber.zero()
	var bestConsumption: NSDecimalNumber!
	var worstConsumption: NSDecimalNumber!

	var numberOfFillups = 0
	var numberOfFullFillups = 0

	var contentImage: UIImage?

	func discardContent() {
		self.contentImage = nil
	}

}

final class FuelStatisticsTextViewController: FuelStatisticsViewController {

	private var gridLeftBorder: CGFloat!
	private var gridRightBorder: CGFloat!
	private var gridDesColumnWidth: CGFloat!

	override func noteStatisticsPageBecomesVisible() {
		self.scrollView.flashScrollIndicators()
	}

	// MARK: - Graph Computation

	private func resampleFetchedObjects(_ fetchedObjects: [FuelEvent], forCar car: Car, andState state: FuelStatisticsData, inManagedObjectContext moc: NSManagedObjectContext) {
		state.car = car
		state.firstDate = nil
		state.lastDate = nil

		let zero = NSDecimalNumber.zero()

		state.totalCost = zero
		state.totalFuelVolume = zero
		state.totalDistance = zero

		state.avgConsumption = zero
		state.bestConsumption = nil
		state.worstConsumption = nil

		state.numberOfFillups = 0
		state.numberOfFullFillups = 0

		let consumptionUnit = car.ksFuelConsumptionUnit

		for fetchedObject in fetchedObjects.lazy.reversed() {
			let managedObject: FuelEvent! = CoreDataManager.existingObject(fetchedObject, inManagedObjectContext: moc) as? FuelEvent

			if managedObject == nil {
				continue
			}

			let distance = managedObject.distance
			let fuelVolume = managedObject.fuelVolume
			let cost = managedObject.cost

			// Collect dates of events
			let timestamp = managedObject.timestamp

			if state.firstDate == nil || timestamp <= state.firstDate {
				state.firstDate = timestamp
			}

			if state.lastDate == nil || timestamp >= state.lastDate {
				state.lastDate = timestamp
			}

			// Summarize all amounts
			state.totalCost = state.totalCost + cost
			state.totalFuelVolume = state.totalFuelVolume + fuelVolume
			state.totalDistance = state.totalDistance + distance

			// Track consumption
			if managedObject.filledUp {

				let inheritedDistance = managedObject.inheritedDistance
				let inheritedFuelVolume = managedObject.inheritedFuelVolume

				let consumption = Units.consumptionForKilometers(distance + inheritedDistance,
                                                                          liters: fuelVolume + inheritedFuelVolume,
                                                                          inUnit: consumptionUnit)

				state.avgConsumption = state.avgConsumption + consumption

				if consumptionUnit.isEfficiency {
					state.bestConsumption  = max(consumption, state.bestConsumption ?? consumption)
					state.worstConsumption = min(consumption, state.worstConsumption ?? consumption)
				} else {
					state.bestConsumption  = min(consumption, state.bestConsumption ?? consumption)
					state.worstConsumption = max(consumption, state.worstConsumption ?? consumption)
				}

				state.numberOfFullFillups += 1
			}

			state.numberOfFillups += 1
		}

		// Compute average consumption
		if state.totalDistance != .zero() && state.totalFuelVolume != .zero() {
			state.avgConsumption = Units.consumptionForKilometers(state.totalDistance,
                                                               liters: state.totalFuelVolume,
                                                               inUnit: consumptionUnit)
		}
	}

	override func computeStatisticsForRecentMonths(_ numberOfMonths: Int, forCar car: Car, withObjects fetchedObjects: [FuelEvent], inManagedObjectContext moc: NSManagedObjectContext) -> DiscardableDataObject {

		// No cache cell exists => resample data and compute average value
		var state: FuelStatisticsData! = self.contentCache[numberOfMonths] as? FuelStatisticsData

		if state == nil {
			state = FuelStatisticsData()
			resampleFetchedObjects(fetchedObjects, forCar: car, andState: state, inManagedObjectContext: moc)
		}

		// Create image data from resampled data
		if state.contentImage == nil {
			let height = (state.numberOfFillups == 0) ? StatisticsHeight : GridTextHeight*CGFloat(GridLines) + 10.0

			UIGraphicsBeginImageContextWithOptions(CGSize(width: self.view.bounds.size.width, height: height), false, 0.0)

			drawStatisticsForState(state, withHeight: height)
            state.contentImage = UIGraphicsGetImageFromCurrentImageContext()

			UIGraphicsEndImageContext()
		}

		return state
	}

	// MARK: - Graph Display

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()

		self.gridLeftBorder = GridMargin
		self.gridRightBorder = self.view.bounds.size.width - GridMargin
		self.gridDesColumnWidth = (self.view.bounds.size.width - GridMargin - GridMargin) / 2.0

		// Initialize contents of background view
		UIGraphicsBeginImageContextWithOptions(self.view.bounds.size, true, 0.0)

		drawBackground()

		if let imageView = self.view as? UIImageView {
			imageView.image = UIGraphicsGetImageFromCurrentImageContext()
		}

		UIGraphicsEndImageContext()
	}

	private func drawBackground() {
		guard let cgContext = UIGraphicsGetCurrentContext() else { return }

		// Background colors
		UIColor(white: 0.082, alpha: 1.0).setFill()
		cgContext.fill(self.view.bounds)

		UIColor.black().setFill()
		cgContext.fill(CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: 28))
	}

	private func drawStatisticsForState(_ state: FuelStatisticsData, withHeight height: CGFloat) {
		guard let cgContext = UIGraphicsGetCurrentContext() else { return }

		UIColor.clear().setFill()
		cgContext.fill(CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: height))

		let font = UIFont.lightApplicationFontForStyle(UIFontTextStyleBody)
		let labelAttributes = [ NSFontAttributeName: font, NSForegroundColorAttributeName: UIColor(white: 0.78, alpha: 1.0) ]
		let valueAttributes = [ NSFontAttributeName: font, NSForegroundColorAttributeName: UIColor.white() ]

		var x: CGFloat
		var y: CGFloat

		if state.numberOfFillups == 0 {

			cgContext.saveGState()

			UIColor.white().setFill()

			let text = NSLocalizedString("Not enough data to display statistics", comment: "")
			let size = text.size(attributes: valueAttributes)

            x = floor ((self.view.bounds.size.width -  size.width)/2.0)
            y = floor ((self.view.bounds.size.height - (size.height - font.descender))/2.0)

			text.draw(at: CGPoint(x: x, y: y), withAttributes: valueAttributes)

			cgContext.restoreGState()

		} else {

			// Horizontal grid backgrounds
			let path = UIBezierPath()

			path.lineWidth = GridTextHeight - 1
			UIColor(white: 0.224, alpha: 0.1).setStroke()

			cgContext.saveGState()

			path.removeAllPoints()
			path.move(to: CGPoint(x: self.gridLeftBorder, y: 1.0))
			path.addLine(to: CGPoint(x: self.gridRightBorder, y: 1.0))

			var y = CGFloat(0.0)
			for i in stride(from: 1, to: GridLines, by: 2) {
                let lastY = y
                y = rint (GridTextHeight*0.5 + GridTextHeight*CGFloat(i))

				cgContext.translate(x: 0.0, y: y - lastY)
                path.stroke()
            }

			cgContext.restoreGState()

			UIColor(white: 0.45, alpha: 0.5).setStroke()

			// Horizontal grid lines
			let dashDotPattern: [CGFloat] = [ 0.5, 0.5 ]
			let dashDotPatternLength = 1
			path.lineWidth = 1.0 / UIScreen.main().scale

			path.setLineDash(dashDotPattern, count: dashDotPatternLength, phase: 0.0)

			cgContext.saveGState()

			path.removeAllPoints()
			path.move(to: CGPoint(x: self.gridLeftBorder, y: 0.25))
			path.addLine(to: CGPoint(x: self.gridRightBorder, y: 0.25))

			y = CGFloat(0.0)
            for i in 1...GridLines {
                let lastY = y
                y = rint (GridTextHeight*CGFloat(i))

				cgContext.translate(x: 0.0, y: y - lastY)
                path.stroke()
            }

			cgContext.restoreGState()

			// Vertical grid line
			path.lineWidth = 0.5
			path.setLineDash(nil, count: 0, phase: 0.0)

			cgContext.saveGState()

			path.removeAllPoints()
			path.move(to: CGPoint(x: self.gridLeftBorder + self.gridDesColumnWidth + 0.25, y: 0.0))
			path.addLine(to: CGPoint(x: self.gridLeftBorder + self.gridDesColumnWidth + 0.25, y: GridTextHeight*CGFloat(GridLines)))
            path.stroke()

			cgContext.restoreGState()

			// Textual information
			cgContext.saveGState()

			cgContext.setShadow(offset: CGSize(width: 0.0, height: -1.0), blur: 0.0, color: UIColor.black().cgColor)

            let nf = Formatters.sharedFuelVolumeFormatter
            let cf = Formatters.sharedCurrencyFormatter
            let pcf = Formatters.sharedPreciseCurrencyFormatter
            let zero = NSDecimalNumber.zero()

            let consumptionUnit = state.car.ksFuelConsumptionUnit
            let consumptionUnitString = consumptionUnit.localizedString

            let odometerUnit = state.car.ksOdometerUnit
            let odometerUnitString = Formatters.sharedShortMeasurementFormatter.string(from: odometerUnit)

			let fuelUnit = state.car.ksFuelUnit
            let fuelUnitString = Formatters.sharedShortMeasurementFormatter.string(from: fuelUnit)

            let numberOfDays = Date.numberOfCalendarDaysFrom(state.firstDate, to: state.lastDate)

			y = (GridTextHeight - font.lineHeight) / 2.0

			func drawEntry(label: String, value: String) {
				let size = label.size(attributes: labelAttributes)
				let x1 = self.gridLeftBorder + self.gridDesColumnWidth - size.width - GridTextXMargin
				label.draw(at: CGPoint(x: x1, y: y), withAttributes: labelAttributes)

				let x2 = self.gridLeftBorder + self.gridDesColumnWidth + GridTextXMargin
				value.draw(at: CGPoint(x: x2, y: y), withAttributes: valueAttributes)

				y += GridTextHeight
			}

            // number of days
			drawEntry(
				label: NSLocalizedString("days", comment: ""),
				value: "\(Date.numberOfCalendarDaysFrom(state.firstDate, to:state.lastDate))")

            // avg consumption
            drawEntry(
				label: NSLocalizedString(consumptionUnit.isEfficiency ? "avg_efficiency" : "avg_consumption", comment: ""),
				value: "\(nf.string(from: state.avgConsumption)!) \(consumptionUnitString)")

            // best consumption
			drawEntry(
				label: NSLocalizedString(consumptionUnit.isEfficiency ? "max_efficiency" : "min_consumption", comment: ""),
				value: "\(nf.string(from: state.bestConsumption)!) \(consumptionUnitString)")

            // worst consumption
			drawEntry(
				label: NSLocalizedString(consumptionUnit.isEfficiency ? "min_efficiency" : "max_consumption", comment: ""),
				value: "\(nf.string(from: state.worstConsumption)!) \(consumptionUnitString)")

            // total cost
			drawEntry(label: NSLocalizedString("ttl_cost", comment: ""), value: cf.string(from: state.totalCost)!)

            // total distance
			let totalDistance = Units.distanceForKilometers(state.totalDistance, withUnit: odometerUnit)
			drawEntry(
				label: NSLocalizedString("ttl_distance", comment: ""),
                value: "\(Formatters.sharedDistanceFormatter.string(from: totalDistance)!) \(odometerUnitString)")

            // total volume
			let totalVolume = Units.volumeForLiters(state.totalFuelVolume, withUnit: fuelUnit)
			drawEntry(
				label: NSLocalizedString("ttl_volume", comment: ""),
				value: "\(nf.string(from: totalVolume)!) \(fuelUnitString)")

            // total events
			drawEntry(label: NSLocalizedString("ttl_events", comment: ""), value: "\(state.numberOfFillups)")

            // volume per event
			let volumePerEventLabel = NSLocalizedString("volume_event", comment: "")
			if state.numberOfFillups > 0 {
				let val = Units.volumeForLiters(state.totalFuelVolume, withUnit: fuelUnit) / NSDecimalNumber(value: state.numberOfFillups)
				drawEntry(label: volumePerEventLabel, value: "\(nf.string(from: val)!) \(fuelUnitString)")
			} else {
				drawEntry(label: volumePerEventLabel, value: NSLocalizedString("-", comment: ""))
			}

            // cost per distance
			let costPerDistanceLabel = String(format: NSLocalizedString("cost_per_x", comment: ""), Units.odometerUnitDescription(odometerUnit, pluralization: false) as NSString)
			if zero < state.totalDistance {
				let val = state.totalCost / Units.distanceForKilometers(state.totalDistance, withUnit: odometerUnit)
				drawEntry(label: costPerDistanceLabel, value: "\(pcf.string(from: val)!)/\(odometerUnitString)")
			} else {
				drawEntry(label: costPerDistanceLabel, value: NSLocalizedString("-", comment: ""))
			}

            // cost per volume
			let costPerVolumeLabel = String(format: NSLocalizedString("cost_per_x", comment: ""), Units.fuelUnitDescription(fuelUnit, discernGallons: true, pluralization: false) as NSString)
			if zero < state.totalFuelVolume {
				let val = state.totalCost / Units.volumeForLiters(state.totalFuelVolume, withUnit: fuelUnit)
				drawEntry(label: costPerVolumeLabel, value: "\(pcf.string(from: val)!)/\(fuelUnitString)")
			} else {
				drawEntry(label: costPerVolumeLabel, value: NSLocalizedString("-", comment: ""))
			}

            // cost per day
			let costPerDayLabel = String(format: NSLocalizedString("cost_per_x", comment: ""), NSLocalizedString("day", comment: "") as NSString)
			if numberOfDays > 0 {
				let val = state.totalCost / NSDecimalNumber(value: numberOfDays)
				drawEntry(label: costPerDayLabel, value: cf.string(from: val)!)
			} else {
				drawEntry(label: costPerDayLabel, value: NSLocalizedString("-", comment: ""))
			}

            // cost per event
			let costPerEventLabel = String(format: NSLocalizedString("cost_per_x", comment: ""), NSLocalizedString("event", comment: "") as NSString)
			if state.numberOfFillups > 0 {
				let val = state.totalCost / NSDecimalNumber(value: state.numberOfFillups)
				drawEntry(label: costPerEventLabel, value: cf.string(from: val)!)
			} else {
				drawEntry(label: costPerEventLabel, value: NSLocalizedString("-", comment: ""))
			}

            // distance per event
			let distancePerEventLabel = String(format: NSLocalizedString("x_per_y", comment: ""), Units.odometerUnitDescription(odometerUnit, pluralization: true) as NSString, NSLocalizedString("event", comment: "") as NSString)
			if state.numberOfFillups > 0 {
				let val = Units.distanceForKilometers(state.totalDistance, withUnit: odometerUnit) / NSDecimalNumber(value: state.numberOfFillups)
				drawEntry(label: distancePerEventLabel, value: "\(nf.string(from: val)!) \(odometerUnitString)")
			} else {
				drawEntry(label: distancePerEventLabel, value: NSLocalizedString("-", comment: ""))
			}

            // distance per day
			let distancePerDayLabel = String(format: NSLocalizedString("x_per_y", comment: ""), Units.odometerUnitDescription(odometerUnit, pluralization: true) as NSString, NSLocalizedString("day", comment: "") as NSString)
			if numberOfDays > 0 {
				let val = Units.distanceForKilometers(state.totalDistance, withUnit: odometerUnit) / NSDecimalNumber(value: numberOfDays)
				drawEntry(label: distancePerDayLabel, value: "\(nf.string(from: val)!) \(odometerUnitString)")
			} else {
				drawEntry(label: distancePerDayLabel, value: NSLocalizedString("-", comment: ""))
			}

            // distance per money
			let distancePerMoneyLabel = String(format: NSLocalizedString("x_per_y", comment: ""), Units.odometerUnitDescription(odometerUnit, pluralization: true) as NSString, cf.currencySymbol! as NSString)
			if zero < state.totalCost {
				let val = Units.distanceForKilometers(state.totalDistance, withUnit: odometerUnit) / state.totalCost
				drawEntry(label: distancePerMoneyLabel, value: "\(nf.string(from: val)!) \(odometerUnitString)")
			} else {
				drawEntry(label: distancePerMoneyLabel, value: NSLocalizedString("-", comment: ""))
			}

			cgContext.restoreGState()
		}
	}

	override func displayCachedStatisticsForRecentMonths(_ numberOfMonths: Int) -> Bool {
		let cell = self.contentCache[numberOfMonths] as? FuelStatisticsData

		// Cache Hit => Update image contents
		if let contentImage = cell?.contentImage {
			self.activityView.stopAnimating()

			let imageFrame = CGRect(x: 0, y: 0, width: contentImage.size.width, height: contentImage.size.height)

			var imageView: UIImageView! = self.scrollView.viewWithTag(1) as? UIImageView

			if imageView == nil {
				imageView = UIImageView(frame: imageFrame)
				imageView.tag = 1
				imageView.isOpaque = false
				imageView.backgroundColor = UIColor.clear()

				self.scrollView.isHidden = false
				self.scrollView.addSubview(imageView)
			}

			if imageView.frame.isEmpty {
				imageView.image = contentImage
				imageView.frame = imageFrame
			} else {
				UIView.transition(with: imageView,
                              duration: StatisticTransitionDuration,
                               options: .transitionCrossDissolve,
                            animations: {
                                imageView.image = contentImage
                                imageView.frame = imageFrame
							},
                            completion: nil)
			}

			self.scrollView.contentSize = imageView.image!.size

			UIView.animate(withDuration: StatisticTransitionDuration,
                         animations: { self.scrollView.alpha = 1.0 },
                         completion: { finished in
							if finished {
								self.scrollView.flashScrollIndicators()
							}
                         })

			return true
		} else {
			// Cache Miss => draw preliminary contents

			UIView.animate(withDuration: StatisticTransitionDuration,
                         animations: { self.scrollView.alpha = 0.0 },
                         completion: { finished in
                             if finished {
								self.activityView.startAnimating()
								let imageView: UIImageView! = self.scrollView.viewWithTag(1) as? UIImageView
								if imageView != nil {
                                     imageView.image = nil
                                     imageView.frame = .zero
                                     self.scrollView.contentSize = .zero
                                 }
                             }
                         })

			return false
		}
	}

}
