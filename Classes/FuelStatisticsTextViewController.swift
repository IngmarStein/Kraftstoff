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

//MARK: - Disposable Sampling Data Objects for ContentCache

private class FuelStatisticsData : DiscardableDataObject {
	var car: Car!

	var firstDate: NSDate!
	var lastDate: NSDate!

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

class FuelStatisticsTextViewController: FuelStatisticsViewController {

	private var gridLeftBorder: CGFloat!
	private var gridRightBorder: CGFloat!
	private var gridDesColumnWidth: CGFloat!

	override func noteStatisticsPageBecomesVisible(visible: Bool) {
		if visible {
			self.scrollView.flashScrollIndicators()
		}
	}

	//MARK: - Graph Computation

	private func resampleFetchedObjects(fetchedObjects: [FuelEvent], forCar car: Car, andState state: FuelStatisticsData, inManagedObjectContext moc: NSManagedObjectContext) {
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

		for var i = fetchedObjects.count - 1; i >= 0; i-- {

			let managedObject: FuelEvent! = CoreDataManager.existingObject(fetchedObjects[i], inManagedObjectContext:moc) as? FuelEvent

			if managedObject == nil {
				continue
			}

			let price = managedObject.price
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
                                                                          liters:fuelVolume + inheritedFuelVolume,
                                                                          inUnit:consumptionUnit)

				state.avgConsumption = state.avgConsumption + consumption

				if consumptionUnit.isEfficiency {
					state.bestConsumption  = max(consumption, state.bestConsumption ?? consumption)
					state.worstConsumption = min(consumption, state.worstConsumption ?? consumption)
				} else {
					state.bestConsumption  = min(consumption, state.bestConsumption ?? consumption)
					state.worstConsumption = max(consumption, state.worstConsumption ?? consumption)
				}

				state.numberOfFullFillups++
			}

			state.numberOfFillups++
		}

		// Compute average consumption
		if state.totalDistance != NSDecimalNumber.zero() && state.totalFuelVolume != NSDecimalNumber.zero() {
			state.avgConsumption = Units.consumptionForKilometers(state.totalDistance,
                                                               liters:state.totalFuelVolume,
                                                               inUnit:consumptionUnit)
		}
	}

	override func computeStatisticsForRecentMonths(numberOfMonths: Int, forCar car: Car, withObjects fetchedObjects: [FuelEvent], inManagedObjectContext moc: NSManagedObjectContext) -> DiscardableDataObject {

		// No cache cell exists => resample data and compute average value
		var state: FuelStatisticsData! = self.contentCache[numberOfMonths] as? FuelStatisticsData

		if state == nil {
			state = FuelStatisticsData()
			resampleFetchedObjects(fetchedObjects, forCar:car, andState:state, inManagedObjectContext:moc)
		}

		// Create image data from resampled data
		if state.contentImage == nil {
			let height = (state.numberOfFillups == 0) ? StatisticsHeight : GridTextHeight*CGFloat(GridLines) + 10.0

			UIGraphicsBeginImageContextWithOptions(CGSize(width:self.view.bounds.size.width, height:height), false, 0.0)

			drawStatisticsForState(state, withHeight:height)
            state.contentImage = UIGraphicsGetImageFromCurrentImageContext()

			UIGraphicsEndImageContext()
		}

		return state
	}

	//MARK: - Graph Display

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()

		self.gridLeftBorder = GridMargin
		self.gridRightBorder = self.view.bounds.size.width - GridMargin
		self.gridDesColumnWidth = (self.view.bounds.size.width - GridMargin - GridMargin) / 2.0

		// Initialize contents of background view
		UIGraphicsBeginImageContextWithOptions (self.view.bounds.size, true, 0.0)

		drawBackground()

		let imageView = self.view as! UIImageView
		imageView.image = UIGraphicsGetImageFromCurrentImageContext()

		UIGraphicsEndImageContext()
	}

	private func drawBackground() {
		let cgContext = UIGraphicsGetCurrentContext()

		// Background colors
		UIColor(white: 0.082, alpha:1.0).setFill()
		CGContextFillRect(cgContext, self.view.bounds)

		UIColor.blackColor().setFill()
		CGContextFillRect(cgContext, CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height:28))
	}

	private func drawStatisticsForState(state: FuelStatisticsData, withHeight height: CGFloat) {
		let cgContext = UIGraphicsGetCurrentContext()

		UIColor.clearColor().setFill()
		CGContextFillRect(cgContext, CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: height))

		let font = UIFont.lightApplicationFontForStyle(UIFontTextStyleBody)
		let labelAttributes = [ NSFontAttributeName:font, NSForegroundColorAttributeName:UIColor(white:0.78, alpha:1.0) ]
		let valueAttributes = [ NSFontAttributeName:font, NSForegroundColorAttributeName:UIColor.whiteColor() ]

		var x: CGFloat
		var y: CGFloat

		if state.numberOfFillups == 0 {

			CGContextSaveGState (cgContext)

			UIColor.whiteColor().setFill()

			let text = NSLocalizedString("Not enough data to display statistics", comment:"")
			let size = text.sizeWithAttributes(valueAttributes)

            x = floor ((self.view.bounds.size.width -  size.width)/2.0)
            y = floor ((self.view.bounds.size.height - (size.height - font.descender))/2.0)

			text.drawAtPoint(CGPoint(x: x, y: y), withAttributes:valueAttributes)

			CGContextRestoreGState (cgContext)

		} else {

			// Horizontal grid backgrounds
			let path = UIBezierPath()

			path.lineWidth = GridTextHeight - 1
			UIColor(white:0.224, alpha:0.1).setStroke()

			CGContextSaveGState(cgContext)

			path.removeAllPoints()
			path.moveToPoint(   CGPoint(x: self.gridLeftBorder,  y: 1.0))
			path.addLineToPoint(CGPoint(x: self.gridRightBorder, y: 1.0))

            for var i = 1, y = CGFloat(0.0); i < GridLines; i+=2 {

                let lastY = y
                y = rint (GridTextHeight*0.5 + GridTextHeight*CGFloat(i))

                CGContextTranslateCTM(cgContext, 0.0, y - lastY)
                path.stroke()
            }

			CGContextRestoreGState(cgContext)

			UIColor(white:0.45, alpha:0.5).setStroke()

			// Horizontal grid lines
			let dashDotPattern: [CGFloat] = [ 0.5, 0.5 ]
			let dashDotPatternLength = 1
			path.lineWidth = 1.0 / UIScreen.mainScreen().scale

			path.setLineDash(dashDotPattern, count:dashDotPatternLength, phase:0.0)

			CGContextSaveGState (cgContext)

			path.removeAllPoints()
			path.moveToPoint(   CGPoint(x: self.gridLeftBorder,  y: 0.25))
			path.addLineToPoint(CGPoint(x: self.gridRightBorder, y: 0.25))

            for var i = 1, y = CGFloat(0.0); i <= GridLines; i++ {
                let lastY = y
                y = rint (GridTextHeight*CGFloat(i))

                CGContextTranslateCTM(cgContext, 0.0, y - lastY)
                path.stroke()
            }

			CGContextRestoreGState(cgContext)

			// Vertical grid line
			path.lineWidth = 0.5
			path.setLineDash(nil, count:0, phase:0.0)

			CGContextSaveGState(cgContext)

			path.removeAllPoints()
			path.moveToPoint(CGPoint(x: self.gridLeftBorder + self.gridDesColumnWidth + 0.25, y: 0.0))
			path.addLineToPoint(CGPoint(x: self.gridLeftBorder + self.gridDesColumnWidth + 0.25, y: GridTextHeight*CGFloat(GridLines)))
            path.stroke()

			CGContextRestoreGState(cgContext)

			// Textual information
			CGContextSaveGState(cgContext)

			CGContextSetShadowWithColor(cgContext, CGSize(width: 0.0, height: -1.0), 0.0, UIColor.blackColor().CGColor)

            let nf = Formatters.sharedFuelVolumeFormatter
            let cf = Formatters.sharedCurrencyFormatter
            let pcf = Formatters.sharedPreciseCurrencyFormatter
            let zero = NSDecimalNumber.zero()

            let consumptionUnit = state.car.ksFuelConsumptionUnit
            let consumptionUnitString = Units.consumptionUnitString(consumptionUnit)

            let odometerUnit = state.car.ksOdometerUnit
            let odometerUnitString = Units.odometerUnitString(odometerUnit)

			let fuelUnit = state.car.ksFuelUnit
            let fuelUnitString = Units.fuelUnitString(fuelUnit)

            let numberOfDays = NSDate.numberOfCalendarDaysFrom(state.firstDate, to:state.lastDate)

			y = (GridTextHeight - font.lineHeight) / 2.0

			func drawEntry(label: String, value: String) {
				let size = label.sizeWithAttributes(labelAttributes)
				let x1 = self.gridLeftBorder + self.gridDesColumnWidth - size.width - GridTextXMargin
				label.drawAtPoint(CGPoint(x: x1, y: y), withAttributes:labelAttributes)

				let x2 = self.gridLeftBorder + self.gridDesColumnWidth + GridTextXMargin
				value.drawAtPoint(CGPoint(x: x2, y: y), withAttributes:valueAttributes)

				y += GridTextHeight
			}

            // number of days
			drawEntry(
				NSLocalizedString("days", comment:""),
				"\(NSDate.numberOfCalendarDaysFrom(state.firstDate, to:state.lastDate))")

            // avg consumption
            drawEntry(
				NSLocalizedString(consumptionUnit.isEfficiency ? "avg_efficiency" : "avg_consumption", comment:""),
                String(format:"%@ %@", nf.stringFromNumber(state.avgConsumption)!, consumptionUnitString))

            // best consumption
			drawEntry(
				NSLocalizedString(consumptionUnit.isEfficiency ? "max_efficiency" : "min_consumption", comment:""),
                String(format:"%@ %@", nf.stringFromNumber(state.bestConsumption)!, consumptionUnitString))

            // worst consumption
			drawEntry(
				NSLocalizedString(consumptionUnit.isEfficiency ? "min_efficiency" : "max_consumption", comment:""),
                String(format:"%@ %@", nf.stringFromNumber(state.worstConsumption)!, consumptionUnitString))

            // total cost
			drawEntry(NSLocalizedString("ttl_cost", comment:""), cf.stringFromNumber(state.totalCost)!)

            // total distance
			let totalDistance = Units.distanceForKilometers(state.totalDistance, withUnit:odometerUnit)
			drawEntry(
				NSLocalizedString("ttl_distance", comment:""),
                String(format:"%@ %@", Formatters.sharedDistanceFormatter.stringFromNumber(totalDistance)!, odometerUnitString))

            // total volume
			let totalVolume = Units.volumeForLiters(state.totalFuelVolume, withUnit:fuelUnit)
			drawEntry(
				NSLocalizedString("ttl_volume", comment:""),
                String(format:"%@ %@", nf.stringFromNumber(totalVolume)!, fuelUnitString))

            // total events
			drawEntry(NSLocalizedString("ttl_events", comment:""), "\(state.numberOfFillups)")

            // volume per event
			let volumePerEventLabel = NSLocalizedString("volume_event", comment:"")
			if state.numberOfFillups > 0 {
				let val = Units.volumeForLiters(state.totalFuelVolume, withUnit:fuelUnit) / NSDecimalNumber(integer:state.numberOfFillups)
				drawEntry(volumePerEventLabel, String(format:"%@ %@", nf.stringFromNumber(val)!, fuelUnitString))
			} else {
				drawEntry(volumePerEventLabel, NSLocalizedString("-", comment:""))
			}

            // cost per distance
			let costPerDistanceLabel = String(format:NSLocalizedString("cost_per_x", comment:""), Units.odometerUnitDescription(odometerUnit, pluralization:false))
			if zero < state.totalDistance {
				let val = state.totalCost / Units.distanceForKilometers(state.totalDistance, withUnit:odometerUnit)
				drawEntry(costPerDistanceLabel, String(format:"%@/%@", pcf.stringFromNumber(val)!, odometerUnitString))
			} else {
				drawEntry(costPerDistanceLabel, NSLocalizedString("-", comment:""))
			}

            // cost per volume
			let costPerVolumeLabel = String(format:NSLocalizedString("cost_per_x", comment:""), Units.fuelUnitDescription(fuelUnit, discernGallons:true, pluralization:false))
			if zero < state.totalFuelVolume {
				let val = state.totalCost / Units.volumeForLiters(state.totalFuelVolume, withUnit:fuelUnit)
				drawEntry(costPerVolumeLabel, String(format:"%@/%@", pcf.stringFromNumber(val)!, fuelUnitString))
			} else {
				drawEntry(costPerVolumeLabel, NSLocalizedString("-", comment:""))
			}

            // cost per day
			let costPerDayLabel = String(format:NSLocalizedString("cost_per_x", comment:""), NSLocalizedString("day", comment:""))
			if numberOfDays > 0 {
				let val = state.totalCost / NSDecimalNumber(integer: numberOfDays)
				drawEntry(costPerDayLabel, cf.stringFromNumber(val)!)
			} else {
				drawEntry(costPerDayLabel, NSLocalizedString("-", comment:""))
			}

            // cost per event
			let costPerEventLabel = String(format:NSLocalizedString("cost_per_x", comment:""), NSLocalizedString("event", comment:""))
			if state.numberOfFillups > 0 {
				let val = state.totalCost / NSDecimalNumber(integer: state.numberOfFillups)
				drawEntry(costPerEventLabel, cf.stringFromNumber(val)!)
			} else {
				drawEntry(costPerEventLabel, NSLocalizedString("-", comment:""))
			}

            // distance per event
			let distancePerEventLabel = String(format:NSLocalizedString("x_per_y", comment:""), Units.odometerUnitDescription(odometerUnit, pluralization:true), NSLocalizedString("event", comment:""))
			if state.numberOfFillups > 0 {
				let val = Units.distanceForKilometers(state.totalDistance, withUnit:odometerUnit) / NSDecimalNumber(integer: state.numberOfFillups)
				drawEntry(distancePerEventLabel, String(format:"%@ %@", nf.stringFromNumber(val)!, odometerUnitString))
			} else {
				drawEntry(distancePerEventLabel, NSLocalizedString("-", comment:""))
			}

            // distance per day
			let distancePerDayLabel = String(format:NSLocalizedString("x_per_y", comment:""), Units.odometerUnitDescription(odometerUnit, pluralization:true), NSLocalizedString("day", comment:""))
			if numberOfDays > 0 {
				let val = Units.distanceForKilometers(state.totalDistance, withUnit:odometerUnit) / NSDecimalNumber(integer: numberOfDays)
				drawEntry(distancePerDayLabel, String(format: "%@ %@", nf.stringFromNumber(val)!, odometerUnitString))
			} else {
				drawEntry(distancePerDayLabel, NSLocalizedString("-", comment:""))
			}

            // distance per money
			let distancePerMoneyLabel = String(format:NSLocalizedString("x_per_y", comment:""), Units.odometerUnitDescription(odometerUnit, pluralization:true), cf.currencySymbol!)
			if zero < state.totalCost {
				let val = Units.distanceForKilometers(state.totalDistance, withUnit:odometerUnit) / state.totalCost
				drawEntry(distancePerMoneyLabel, String(format: "%@ %@", nf.stringFromNumber(val)!, odometerUnitString))
			} else {
				drawEntry(distancePerMoneyLabel, NSLocalizedString("-", comment:""))
			}

			CGContextRestoreGState (cgContext)
		}
	}

	override func displayCachedStatisticsForRecentMonths(numberOfMonths: Int) -> Bool {
		let cell = self.contentCache[numberOfMonths] as? FuelStatisticsData

		// Cache Hit => Update image contents
		if let contentImage = cell?.contentImage {
			self.activityView.stopAnimating()

			let imageFrame = CGRect(x: 0, y: 0, width: contentImage.size.width, height: contentImage.size.height)

			var imageView: UIImageView! = self.scrollView.viewWithTag(1) as? UIImageView

			if imageView == nil {
				imageView = UIImageView(frame:imageFrame)
				imageView.tag = 1
				imageView.opaque = false
				imageView.backgroundColor = UIColor.clearColor()

				self.scrollView.hidden = false
				self.scrollView.addSubview(imageView)
			}

			if CGRectIsEmpty(imageView.frame) {
				imageView.image = contentImage
				imageView.frame = imageFrame
			} else {
				UIView.transitionWithView(imageView,
                              duration:StatisticTransitionDuration,
                               options:.TransitionCrossDissolve,
                            animations: {
                                imageView.image = contentImage
                                imageView.frame = imageFrame },
                            completion:nil)
			}

			self.scrollView.contentSize = imageView.image!.size

			UIView.animateWithDuration(StatisticTransitionDuration,
                         animations: { self.scrollView.alpha = 1.0 },
                         completion: { finished in
							if finished {
								self.scrollView.flashScrollIndicators()
							}
                         })

			return true
		} else {
			// Cache Miss => draw preliminary contents

			UIView.animateWithDuration(StatisticTransitionDuration,
                         animations: { self.scrollView.alpha = 0.0 },
                         completion: { finished in
                             if finished {
								self.activityView.startAnimating()
								let imageView: UIImageView! = self.scrollView.viewWithTag(1) as? UIImageView
								if imageView != nil {
                                     imageView.image = nil
                                     imageView.frame = CGRectZero
                                     self.scrollView.contentSize = CGSizeZero
                                 }
                             }
                         })

			return false
		}
	}
}
