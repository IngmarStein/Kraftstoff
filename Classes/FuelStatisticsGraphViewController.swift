//
//  FuelStatisticsGraphViewController.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 05.05.15.
//
//  Graphical Statistics View Controller

import UIKit
import CoreData

protocol FuelStatisticsViewControllerDataSource {
	var curveGradient: CGGradient { get }

	func averageFormatter(precise: Bool, forCar: Car) -> NSNumberFormatter
	func averageFormatString(prefix: Bool, forCar: Car) -> String
	func noAverageStringForCar(_ car: Car) -> String

	func axisFormatterForCar(_ car: Car) -> NSNumberFormatter
	func valueForFuelEvent(_ fuelEvent: FuelEvent, forCar: Car) -> CGFloat
}

protocol FuelStatisticsViewControllerDelegate {
	func graphRightBorder(_ rightBorder: CGFloat, forCar: Car) -> CGFloat
	func graphWidth(_ graphWidth: CGFloat, forCar: Car) -> CGFloat
}

// Coordinates for statistics graph
private let StatisticGraphMargin: CGFloat = 10.0
private let StatisticGraphYAxisLabelWidth: CGFloat = 50.0
private let StatisticGraphXAxisLabelHeight: CGFloat = 32.0
private let StatisticGraphTopBorder: CGFloat = 58.0

// Coordinates for the zoom-track
private let StatisticTrackYPosition: CGFloat = 40.0
private let StatisticTrackThickness: CGFloat = 4.0
private let StatisticTrackInfoXMarginFlat: CGFloat = 4.0
private let StatisticTrackInfoYMarginFlat: CGFloat = 3.0

private let MaxSamples = 256

// MARK: - Disposable Sampling Data Objects for ContentCache

private class FuelStatisticsSamplingData: DiscardableDataObject {
    // Curve data
	var data = [CGPoint](repeating: CGPoint.zero, count: MaxSamples)
	var dataCount = 0

    // Lens data
	var lensDate = [[NSTimeInterval]](repeating: [NSTimeInterval](repeating: 0.0, count: 2), count: MaxSamples)
	var lensValue = [CGFloat](repeating: 0.0, count: MaxSamples)

    // Data for marker positions
	var hMarkPositions = [CGFloat](repeating: 0.0, count: 5)
	var hMarkNames = [String?](repeating: nil, count: 5)
	var hMarkCount = 0

	var vMarkPositions = [CGFloat](repeating: 0.0, count: 3)
	var vMarkNames = [String?](repeating: nil, count: 3)
	var vMarkCount = 0

	var contentImage: UIImage!
	var contentAverage: NSNumber!

	func discardContent() {
		self.contentImage = nil
	}

}

class FuelStatisticsGraphViewController: FuelStatisticsViewController {

	private var zooming = false {
		didSet {
			for subview in self.view.subviews {
				if subview.tag > 0 {
					if subview.tag < 1000 {
						subview.isHidden = zooming
					} else {
						subview.isHidden = !zooming
					}
				}
			}

			if !zooming {
				displayStatisticsForRecentMonths(self.displayedNumberOfMonths)
			}
		}
	}

	private var zoomRecognizer: UILongPressGestureRecognizer!
	private var zoomIndex = 0
	var dataSource: FuelStatisticsViewControllerDataSource?

	// MARK: -  Default Position/Dimension Data for Graphs

	var graphLeftBorder: CGFloat {
		return StatisticGraphMargin
	}

	var graphRightBorder: CGFloat {
		let rightBorder = self.view.bounds.size.width - StatisticGraphMargin - StatisticGraphYAxisLabelWidth
		if let graphDelegate = self.dataSource as? FuelStatisticsViewControllerDelegate {
			return graphDelegate.graphRightBorder(rightBorder, forCar: self.selectedCar)
		} else {
			return rightBorder
		}
	}

	var graphTopBorder: CGFloat {
		return StatisticGraphTopBorder
	}

	var graphBottomBorder: CGFloat {
		return self.graphTopBorder + self.graphHeight
	}

	var graphWidth: CGFloat {
		let width = self.view.bounds.size.width - StatisticGraphMargin - StatisticGraphYAxisLabelWidth - StatisticGraphMargin
		if let graphDelegate = self.dataSource as? FuelStatisticsViewControllerDelegate {
			return graphDelegate.graphWidth(width, forCar: self.selectedCar)
		} else {
			return width
		}
	}

	var graphHeight: CGFloat {
		return self.view.bounds.size.height - self.graphTopBorder - StatisticGraphXAxisLabelHeight
	}

	// MARK: - View Lifecycle

	override func viewDidLoad() {
		super.viewDidLoad()

		zoomRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(FuelStatisticsGraphViewController.longPressChanged(_:)))
		zoomRecognizer.minimumPressDuration = 0.4
		zoomRecognizer.numberOfTouchesRequired = 1
		zoomRecognizer.isEnabled = false

		self.view.addGestureRecognizer(zoomRecognizer)
	}

	// MARK: - Graph Computation

	private func resampleFetchedObjects(_ fetchedObjects: [FuelEvent], forCar car: Car, andState state: FuelStatisticsSamplingData, inManagedObjectContext moc: NSManagedObjectContext) -> CGFloat {
		var firstDate: NSDate? = nil
		var midDate: NSDate? = nil
		var lastDate: NSDate? = nil

		// Compute vertical range of curve
		var valCount = 0
		var valFirstIndex = -1
		var valLastIndex = -1

		var valAverage: CGFloat = 0.0

		var valMin = CGFloat.infinity
		var valMax = -CGFloat.infinity
		var valRange: CGFloat
		var valStretchFactorForDisplay: CGFloat

		for i in (0..<fetchedObjects.count).reversed() {
			if let managedObject = CoreDataManager.existingObject(fetchedObjects[i], inManagedObjectContext: moc) as? FuelEvent {
				let value = self.dataSource!.valueForFuelEvent(managedObject, forCar: car)

				if !value.isNaN {
					valCount   += 1
					valAverage += value

					if valMin > value {
						valMin = value
					}

					if valMax < value {
						valMax = value
					}

					if valLastIndex < 0 {
						valLastIndex = i
						lastDate = managedObject.timestamp
					} else {
						valFirstIndex = i
						firstDate = managedObject.timestamp
					}
				}
			}
		}

		// Not enough data
		if valCount < 2 {
			state.dataCount = 0
			state.hMarkCount = 0
			state.vMarkCount = 0

			return valCount == 0 ? CGFloat.nan : valAverage
		}

		valAverage /= CGFloat(valCount)

		valMin = floor (valMin * 2.0) / 2.0
		valMax = ceil  (valMax / 2.0) * 2.0
		valRange = valMax - valMin

		if valRange > 40 {
			valMin = floor (valMin / 10.0) * 10.0
			valMax = ceil  (valMax / 10.0) * 10.0
		} else if valRange > 8 {
			valMin = floor (valMin / 2.0) * 2.0
			valMax = ceil  (valMax / 2.0) * 2.0
		} else if valRange > 4 {
			valMin = floor (valMin)
			valMax = ceil  (valMax)
		} else if valRange < 0.25 {
			valMin = floor (valMin * 4.0 - 0.001) / 4.0
			valMax = ceil  (valMax * 4.0 + 0.001) / 4.0
		}

		valRange = valMax - valMin

		// Shrink the computed graph to keep the top h-marker below the top-border
		if valRange > 0.0001 {
			valStretchFactorForDisplay = StatisticsHeight / (StatisticsHeight + 18.0)
		} else {
			valStretchFactorForDisplay = 1.0
		}

		// Resampling of fetched data
		var samples = [CGFloat](repeating: 0.0, count: MaxSamples)
		var samplesCount = [Int](repeating: 0, count: MaxSamples)

		for i in 0..<MaxSamples {
			state.lensDate  [i][0] = 0.0
			state.lensDate  [i][1] = 0.0
			state.lensValue [i]    = 0.0
		}

		let rangeInterval = firstDate!.timeIntervalSince(lastDate!)

		for i in (valFirstIndex...valLastIndex).reversed() {
			if let managedObject = CoreDataManager.existingObject(fetchedObjects[i], inManagedObjectContext: moc) as? FuelEvent {
				let value = self.dataSource!.valueForFuelEvent(managedObject, forCar: car)

				if !value.isNaN {
					// Collect sample data
					let sampleInterval = firstDate!.timeIntervalSince(managedObject.timestamp)
					let sampleIndex = Int(rint (CGFloat((MaxSamples-1)) * CGFloat(1.0 - sampleInterval/rangeInterval)))

					if valRange < 0.0001 {
						samples[sampleIndex] += 0.5
					} else {
						samples[sampleIndex] += (value - valMin) / valRange * valStretchFactorForDisplay
					}

					// Collect lens data
					state.lensDate [sampleIndex][(samplesCount[sampleIndex] != 0) ? 1 : 0] = managedObject.timestamp.timeIntervalSinceReferenceDate
					state.lensValue[sampleIndex] += value

					samplesCount[sampleIndex] += 1
				}
			}
		}


		// Build curve data from resampled values
		state.dataCount = 0

		for i in 0..<MaxSamples {
			if samplesCount[i] > 0 {

				state.data[state.dataCount] = CGPoint(x: CGFloat(i) / CGFloat(MaxSamples-1), y: 1.0 - samples [i] / CGFloat(samplesCount[i]))

				state.lensDate[state.dataCount][0] = state.lensDate[i][0]
				state.lensDate[state.dataCount][1] = state.lensDate[i][(samplesCount[i] > 1) ? 1 : 0]
				state.lensValue[state.dataCount] = state.lensValue[i] / CGFloat(samplesCount[i])

				state.dataCount += 1
			}
		}

		// Markers for vertical axis
		let numberFormatter = self.dataSource!.axisFormatterForCar(car)

		state.hMarkPositions[0] = 1.0 - (1.0  * valStretchFactorForDisplay)
		state.hMarkNames[0] = numberFormatter.string(from: (valMin + valRange) as NSNumber)!

		state.hMarkPositions[1] = 1.0 - (0.75 * valStretchFactorForDisplay)
		state.hMarkNames[1] = numberFormatter.string(from: (valMin + valRange*0.75) as NSNumber)!

		state.hMarkPositions[2] = 1.0 - (0.5  * valStretchFactorForDisplay)
		state.hMarkNames[2] = numberFormatter.string(from: (valMin + valRange*0.5) as NSNumber)!

		state.hMarkPositions[3] = 1.0 - (0.25 * valStretchFactorForDisplay)
		state.hMarkNames[3] = numberFormatter.string(from: (valMin + valRange*0.25) as NSNumber)!

		state.hMarkPositions[4] = 1.0
		state.hMarkNames[4] = numberFormatter.string(from: valMin as NSNumber)!
		state.hMarkCount = 5

		// Markers for horizontal axis
		let dateFormatter: NSDateFormatter

		if state.dataCount < 3 || firstDate!.timeIntervalSince(lastDate!) < 604800 {
			dateFormatter = Formatters.sharedDateTimeFormatter
			midDate = nil
		} else {
			dateFormatter = Formatters.sharedDateFormatter
			midDate = NSDate(timeInterval: firstDate!.timeIntervalSince(lastDate!)/2.0, since: lastDate!)
		}

		state.vMarkCount = 0
		state.vMarkPositions[state.vMarkCount] = 0.0
		state.vMarkNames[state.vMarkCount] = dateFormatter.string(for: lastDate!)!
		state.vMarkCount += 1

		if let midDate = midDate {
			state.vMarkPositions[state.vMarkCount] = 0.5
			state.vMarkNames[state.vMarkCount] = dateFormatter.string(for: midDate)!
			state.vMarkCount += 1
		}

		state.vMarkPositions[state.vMarkCount] = 1.0
		state.vMarkNames[state.vMarkCount] = dateFormatter.string(for: firstDate!)!
		state.vMarkCount += 1

		return valAverage
	}

	override func computeStatisticsForRecentMonths(_ numberOfMonths: Int, forCar car: Car, withObjects fetchedObjects: [FuelEvent], inManagedObjectContext moc: NSManagedObjectContext) -> DiscardableDataObject {
		// No cache cell exists => resample data and compute average value
		var state: FuelStatisticsSamplingData! = self.contentCache[numberOfMonths] as? FuelStatisticsSamplingData

		if state == nil {
			state = FuelStatisticsSamplingData()
			state.contentAverage = resampleFetchedObjects(fetchedObjects, forCar: car, andState: state, inManagedObjectContext: moc) as NSNumber
		}

		// Create image data from resampled data
		if state.contentImage == nil {
			UIGraphicsBeginImageContextWithOptions(self.view.bounds.size, true, 0.0)

			drawFlatStatisticsForState(state)
            state.contentImage = UIGraphicsGetImageFromCurrentImageContext()

			UIGraphicsEndImageContext()
		}

		return state
	}

	// MARK: - Graph Display

	private func drawFlatStatisticsForState(_ state: FuelStatisticsSamplingData!) {
		guard let cgContext = UIGraphicsGetCurrentContext() else { return }

		// Background colors
		UIColor(white: 0.082, alpha: 1.0).setFill()
		cgContext.fill(self.view.bounds)

		UIColor.black().setFill()
		cgContext.fill(CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: 28.0))

		// Contents if there is a valid state
		if state == nil {
			return
		}

		let font = UIFont.lightApplicationFontForStyle(textStyle: UIFontTextStyleFootnote)
		let path = UIBezierPath()

		cgContext.saveGState()

		if state.dataCount == 0	{

			let attributes = [ NSFontAttributeName: font, NSForegroundColorAttributeName: UIColor.white() ]

			let text = NSLocalizedString("Not enough data to display statistics", comment: "")
			let size = text.size(attributes: attributes)

            let x = floor ((self.view.bounds.size.width - size.width)/2.0)
            let y = floor ((self.view.bounds.size.height - (size.height - font.descender))/2.0)

			text.draw(at: CGPoint(x: x, y: y), withAttributes: attributes)

		} else {

			// Color for coordinate-axes
			UIColor(white: 0.224, alpha: 1.0).setStroke()

			// Horizontal marker lines
			let dashDotPattern: [CGFloat] = [ 0.5, 0.5 ]
            let dashDotPatternLength = 1

            // Marker lines
            path.lineWidth = 0.5
            path.setLineDash(dashDotPattern, count: dashDotPatternLength, phase: 0.0)

			path.removeAllPoints()
			path.move(to: CGPoint(x: self.graphLeftBorder, y: 0.25))
			path.addLine(to: CGPoint(x: self.view.bounds.size.width - self.graphLeftBorder, y: 0.25))

			cgContext.saveGState()

			var y = CGFloat(0.0)
			for i in 0..<state.hMarkCount {
				let lastY = y
				y = rint (self.graphTopBorder + self.graphHeight * state.hMarkPositions [i])

				cgContext.translate(x: 0.0, y: y - lastY)
				path.stroke()
			}

			cgContext.restoreGState()
        }

		cgContext.restoreGState()

        // Axis description for horizontal marker lines markers
		cgContext.saveGState()

		let attributes = [ NSFontAttributeName: font, NSForegroundColorAttributeName: UIColor.white() ]

		for i in 0..<state.hMarkCount {
			if let mark = state.hMarkNames [i] {

				let size = mark.size(attributes: attributes)

				let x = self.graphRightBorder + 6
				let y = floor (self.graphTopBorder + 0.5 + self.graphHeight * state.hMarkPositions [i] - size.height) + 0.5

				mark.draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
			}
		}

		cgContext.restoreGState()

        // Vertical marker lines
        path.lineWidth = 0.5
        path.setLineDash(nil, count: 0, phase: 0.0)

		path.removeAllPoints()
		path.move(to: CGPoint(x: 0.25, y: self.graphTopBorder))
		path.addLine(to: CGPoint(x: 0.25, y: self.graphBottomBorder + 6))

		cgContext.saveGState()

		var x = CGFloat(0.0)
		for i in 0..<state.vMarkCount {
			let lastX = x
			x = rint (self.graphLeftBorder + self.graphWidth * state.vMarkPositions [i])

			cgContext.translate(x: x - lastX, y: 0.0)
			path.stroke()
        }

		cgContext.restoreGState()

        // Axis description for vertical marker lines
		cgContext.saveGState()

		let vMarkAttributes = [ NSFontAttributeName: font, NSForegroundColorAttributeName: UIColor(white: 0.78, alpha: 1.0) ]

		for i in 0..<state.vMarkCount {
			if let mark = state.vMarkNames [i] {

				let size = mark.size(attributes: attributes)

				var x = floor (self.graphLeftBorder + 0.5 + self.graphWidth * state.vMarkPositions[i] - size.width/2.0)
				let y = self.graphBottomBorder + 5

				if x < self.graphLeftBorder {
					x = self.graphLeftBorder
				}

				if x > self.graphRightBorder - size.width {
					x = self.graphRightBorder - size.width
				}

				mark.draw(at: CGPoint(x: x, y: y), withAttributes: vMarkAttributes)
			}
		}

		cgContext.restoreGState()

        // Pattern fill below curve
		cgContext.saveGState()

		path.removeAllPoints()
		path.move(to: CGPoint(x: self.graphLeftBorder + 1, y: self.graphBottomBorder))

		var minY = self.graphBottomBorder - 6

		for i in 0..<state.dataCount {
			let x = rint (self.graphLeftBorder + self.graphWidth * state.data [i].x)
			let y = rint (self.graphTopBorder + self.graphHeight * state.data [i].y)

			path.addLine(to: CGPoint(x: x, y: y))

			if y < minY {
				minY = y
			}
		}

		if minY == self.graphBottomBorder - 6 {
			minY = self.graphTopBorder
		}

		path.addLine(to: CGPoint(x: self.graphRightBorder, y: self.graphBottomBorder))
		path.close()

		// Color gradient
		path.addClip()
		cgContext.drawLinearGradient(self.dataSource!.curveGradient,
		                             start: CGPoint(x: 0, y: self.graphBottomBorder - 6),
		                             end: CGPoint(x: 0, y: minY),
		                             options: [CGGradientDrawingOptions.drawsBeforeStartLocation, CGGradientDrawingOptions.drawsAfterEndLocation])

		cgContext.restoreGState()

		// Top and bottom lines
		UIColor(white: 0.78, alpha: 1.0).setStroke()
		path.lineWidth = 0.5

		path.removeAllPoints()
		path.move(to: CGPoint(x: self.graphLeftBorder, y: self.graphTopBorder + 0.25))
		path.addLine(to: CGPoint(x: self.view.bounds.size.width - self.graphLeftBorder, y: self.graphTopBorder + 0.25))
		path.stroke()

		path.removeAllPoints()
		path.move(to: CGPoint(x: self.graphLeftBorder, y: self.graphBottomBorder + 0.25))
		path.addLine(to: CGPoint(x: self.view.bounds.size.width - self.graphLeftBorder, y: self.graphBottomBorder + 0.25))
		path.stroke()

		// The curve
		path.lineWidth    = 1
		path.lineCapStyle = .round
		UIColor.white().setStroke()

		path.removeAllPoints()
		path.move(to: CGPoint(x: rint (self.graphLeftBorder + self.graphWidth * state.data [0].x),
								 y: rint (self.graphTopBorder + self.graphHeight * state.data [0].y)))

		for i in 0..<state.dataCount {
			let x = rint (self.graphLeftBorder + self.graphWidth * state.data [i].x)
			let y = rint (self.graphTopBorder + self.graphHeight * state.data [i].y)

			path.addLine(to: CGPoint(x: x, y: y))
		}

		path.stroke()
	}

	override func displayCachedStatisticsForRecentMonths(_ numberOfMonths: Int) -> Bool {
		guard let imageView = self.view as? UIImageView else { return false }

		// Cache lookup
		let cell = self.contentCache[numberOfMonths] as? FuelStatisticsSamplingData
		let average = cell?.contentAverage
		let image = cell?.contentImage

		// Update summary in top right of view
		if let average = average where !average.floatValue.isNaN {
			self.rightLabel.text = String(format: self.dataSource!.averageFormatString(prefix: true, forCar: self.selectedCar), self.dataSource!.averageFormatter(precise: false, forCar: self.selectedCar).string(from: average)! as NSString)
		} else {
			self.rightLabel.text = self.dataSource!.noAverageStringForCar(self.selectedCar)
		}

		// Update image contents on cache hit
		if image != nil && average != nil {

			self.activityView.stopAnimating()

			UIView.transition(with: imageView,
                          duration: StatisticTransitionDuration,
                           options: .transitionCrossDissolve,
                        animations: { imageView.image = image },
                        completion: nil)

			zoomRecognizer.isEnabled = (cell?.dataCount ?? 0) > 0

			return true

		} else {
			// Cache Miss => draw prelimary contents

			UIGraphicsBeginImageContextWithOptions (self.view.bounds.size, true, 0.0)

			drawFlatStatisticsForState(nil)
            let image = UIGraphicsGetImageFromCurrentImageContext()

			UIGraphicsEndImageContext()

			UIView.transition(with: imageView,
                          duration: StatisticTransitionDuration,
                           options: .transitionCrossDissolve,
                        animations: { imageView.image = image },
                        completion: { finished in
							if finished {
                                self.activityView.startAnimating()
							}
			})

			zoomRecognizer.isEnabled = false

			return false
		}
	}

	// MARK: - Zoom Lens Handling

	func longPressChanged(_ sender: AnyObject) {
		switch zoomRecognizer.state {
        case .possible:
            break

		case .began:

			// Cancel long press gesture when located above the graph (new the radio buttons)
			if zoomRecognizer.location(in: self.view).y < self.graphTopBorder {

				zoomRecognizer.isEnabled = false
                zoomRecognizer.isEnabled = true
                break
            }

            self.zooming = true
            zoomIndex    = -1

			fallthrough
            // no break

        case .changed:
			var lensLocation = zoomRecognizer.location(in: self.view)

            // Keep horizontal position above graphics
			if lensLocation.x < self.graphLeftBorder {
                lensLocation.x = self.graphLeftBorder
			} else if lensLocation.x > self.graphLeftBorder + self.graphWidth {
                lensLocation.x = self.graphLeftBorder + self.graphWidth
			}

            lensLocation.x -= self.graphLeftBorder
            lensLocation.x /= self.graphWidth

            // Match nearest data point
            let cell = self.contentCache[self.displayedNumberOfMonths] as? FuelStatisticsSamplingData

            if let cell = cell {

                var lb = 0
				var ub = cell.dataCount - 1

                while ub - lb > 1 {

                    let mid = Int((lb+ub)/2)

					if lensLocation.x < cell.data[mid].x {
                        ub = mid
					} else if lensLocation.x > cell.data[mid].x {
                        lb = mid
					} else {
                        lb = mid
						ub = mid
					}
                }

                let minIndex = (fabs (cell.data [lb].x - lensLocation.x) < fabs (cell.data [ub].x - lensLocation.x)) ? lb : ub

                // Update screen contents
                if minIndex >= 0 && minIndex != zoomIndex {

                    zoomIndex = minIndex

                    // Date information
                    let df = Formatters.sharedLongDateFormatter

					if cell.lensDate [minIndex][0] == cell.lensDate [minIndex][1] {
                        self.centerLabel.text = df.string(from: NSDate(timeIntervalSinceReferenceDate: cell.lensDate[minIndex][0]))
					} else {
                        self.centerLabel.text = "\(df.string(from: NSDate(timeIntervalSinceReferenceDate: cell.lensDate[minIndex][0])))  ➡  \(df.string(from: NSDate(timeIntervalSinceReferenceDate: cell.lensDate[minIndex][1])))"
					}

                    // Knob position
                    lensLocation.x = rint (self.graphLeftBorder + self.graphWidth * cell.data[minIndex].x)
                    lensLocation.y = rint (self.graphTopBorder + self.graphHeight * cell.data[minIndex].y)

                    // Image with value information
                    UIGraphicsBeginImageContextWithOptions(self.view.bounds.size, true, 0.0)

					let valueString = String(format: self.dataSource!.averageFormatString(prefix: false, forCar: self.selectedCar),
													 self.dataSource!.averageFormatter(precise: true, forCar: self.selectedCar).string(from: cell.lensValue[minIndex] as NSNumber)! as NSString)

					drawFlatLensWithBGImage(cell.contentImage, lensLocation: lensLocation, info: valueString)

					if let imageView = self.view as? UIImageView {
						imageView.image = UIGraphicsGetImageFromCurrentImageContext()
					}

					UIGraphicsEndImageContext()
                }
            }

        case .ended, .cancelled, .failed:
			if NSProcessInfo.processInfo().arguments.index(of: "-KEEPLENS") == nil {
				self.zooming = false
			}
		}
	}

	private func drawFlatLensWithBGImage(_ background: UIImage, lensLocation location: CGPoint, info: String) {
		var path = UIBezierPath()

		// Graph as background
		background.draw(at: CGPoint.zero, blendMode: .copy, alpha: 1.0)

		// Marker line
		self.view.tintColor.set()

		path.lineWidth = 0.5

		path.removeAllPoints()
		path.move(to: CGPoint(x: location.x + 0.25, y: self.graphTopBorder + 0.5))
		path.addLine(to: CGPoint(x: location.x + 0.25, y: self.graphBottomBorder))
		path.stroke()

		// Marker knob
		path = UIBezierPath(arcCenter: location, radius: 5.5, startAngle: 0.0, endAngle: CGFloat(M_PI)*2.0, clockwise: false)
		UIColor.black().set()
		path.fill()

		path = UIBezierPath(arcCenter: location, radius: 5.0, startAngle: 0.0, endAngle: CGFloat(M_PI)*2.0, clockwise: false)
		self.view.tintColor.set()
		path.fill()

		// Layout for info box
		let attributes = [ NSFontAttributeName: UIFont.lightApplicationFontForStyle(textStyle: UIFontTextStyleCaption2),
                                 NSForegroundColorAttributeName: UIColor.white() ]

		var infoRect = CGRect()
		infoRect.size = info.size(attributes: attributes)
		infoRect.size.width += StatisticTrackInfoXMarginFlat * 2.0
		infoRect.size.height += StatisticTrackInfoYMarginFlat * 2.0
		infoRect.origin.x = rint (location.x - infoRect.size.width/2)
		infoRect.origin.y = StatisticTrackYPosition + rint ((StatisticTrackThickness - infoRect.size.height) / 2)

		if infoRect.origin.x < self.graphLeftBorder {
			infoRect.origin.x = self.graphLeftBorder
		}

		if infoRect.origin.x > self.view.bounds.size.width - self.graphLeftBorder - infoRect.size.width {
			infoRect.origin.x = self.view.bounds.size.width - self.graphLeftBorder - infoRect.size.width
		}

		// Info box
		path = UIBezierPath(roundedRect: infoRect,
                                 byRoundingCorners: .allCorners,
									   cornerRadii: CGSize(width: 4.0, height: 4.0))

		self.view.tintColor.set()
		path.fill()

		// Info text
		info.draw(at: CGPoint(x: infoRect.origin.x + StatisticTrackInfoXMarginFlat, y: infoRect.origin.y + StatisticTrackInfoYMarginFlat), withAttributes: attributes)
	}

}

// MARK - Data Sources for Different Statistic Graphs

class FuelStatisticsViewControllerDataSourceAvgConsumption: FuelStatisticsViewControllerDataSource, FuelStatisticsViewControllerDelegate {

	func graphRightBorder(_ rightBorder: CGFloat, forCar car: Car) -> CGFloat {
		let consumptionUnit = car.ksFuelConsumptionUnit
		return rightBorder - (consumptionUnit.isGP10K ? 16.0 : 0.0)
	}

	func graphWidth(_ graphWidth: CGFloat, forCar car: Car) -> CGFloat {
		let consumptionUnit = car.ksFuelConsumptionUnit
		return graphWidth - (consumptionUnit.isGP10K ? 16.0 : 0.0)
	}

	var curveGradient: CGGradient {
		return AppDelegate.greenGradient
	}

	func averageFormatter(precise: Bool, forCar car: Car) -> NSNumberFormatter {
		return Formatters.sharedFuelVolumeFormatter
	}

	func averageFormatString(prefix avgPrefix: Bool, forCar car: Car) -> String {
		let prefix = avgPrefix ? "∅ " : ""
		let unit = car.ksFuelConsumptionUnit.localizedString

		return "\(prefix)%@ \(unit)"
	}

	func noAverageStringForCar(_ car: Car) -> String {
		return car.ksFuelConsumptionUnit.localizedString
	}

	func axisFormatterForCar(_ car: Car) -> NSNumberFormatter {
		return Formatters.sharedFuelVolumeFormatter
	}

	func valueForFuelEvent(_ fuelEvent: FuelEvent, forCar car: Car) -> CGFloat {
		if !fuelEvent.filledUp {
			return CGFloat.nan
		}

		let consumptionUnit = car.ksFuelConsumptionUnit
		let distance = fuelEvent.distance + fuelEvent.inheritedDistance
		let fuelVolume = fuelEvent.fuelVolume + fuelEvent.inheritedFuelVolume

		return CGFloat(Units.consumptionForKilometers(distance, liters: fuelVolume, inUnit: consumptionUnit).floatValue)
	}

}

class FuelStatisticsViewControllerDataSourcePriceAmount: FuelStatisticsViewControllerDataSource {

	var curveGradient: CGGradient {
		return AppDelegate.orangeGradient
	}

	func averageFormatter(precise: Bool, forCar car: Car) -> NSNumberFormatter {
		return (precise) ? Formatters.sharedPreciseCurrencyFormatter : Formatters.sharedCurrencyFormatter
	}

	func averageFormatString(prefix avgPrefix: Bool, forCar car: Car) -> String {
		let prefix = avgPrefix ? "∅ " : ""
		let unit = car.ksFuelUnit.description

		return "\(prefix)%@/\(unit)"
	}

	func noAverageStringForCar(_ car: Car) -> String {
		return "\(Formatters.sharedCurrencyFormatter.currencySymbol!)/\(car.ksFuelUnit.description)"
	}

	func axisFormatterForCar(_ car: Car) -> NSNumberFormatter {
		return Formatters.sharedAxisCurrencyFormatter
	}

	func valueForFuelEvent(_ fuelEvent: FuelEvent, forCar car: Car) -> CGFloat {
		let price = fuelEvent.price

		if price == NSDecimalNumber.zero() {
			return CGFloat.nan
		}

		return CGFloat(Units.pricePerUnit(literPrice: price, withUnit: car.ksFuelUnit).floatValue)
	}

}

class FuelStatisticsViewControllerDataSourcePriceDistance: FuelStatisticsViewControllerDataSource {
	var curveGradient: CGGradient {
		return AppDelegate.blueGradient
	}

	func averageFormatter(precise: Bool, forCar car: Car) -> NSNumberFormatter {
		let distanceUnit = car.ksOdometerUnit

		if distanceUnit.isMetric {
			return Formatters.sharedCurrencyFormatter
		} else {
			return Formatters.sharedDistanceFormatter
		}
	}

	func averageFormatString(prefix avgPrefix: Bool, forCar car: Car) -> String {
		let prefix = avgPrefix ? "∅ " : ""
		if car.ksOdometerUnit.isMetric {
			return "\(prefix)%@/100km"
		} else {
			let currencySymbol = Formatters.sharedCurrencyFormatter.currencySymbol!
			return "\(prefix)%@ mi/\(currencySymbol)"
		}
	}

	func noAverageStringForCar(_ car: Car) -> String {
		let distanceUnit = car.ksOdometerUnit

		return distanceUnit.isMetric ? "\(Formatters.sharedCurrencyFormatter.currencySymbol!)/100km" : "mi/\(Formatters.sharedCurrencyFormatter.currencySymbol!)"
	}

	func axisFormatterForCar(_ car: Car) -> NSNumberFormatter {
		let distanceUnit = car.ksOdometerUnit

		if distanceUnit.isMetric {
			return Formatters.sharedAxisCurrencyFormatter
		} else {
			return Formatters.sharedDistanceFormatter
		}
	}

	func valueForFuelEvent(_ fuelEvent: FuelEvent, forCar car: Car) -> CGFloat {
		if !fuelEvent.filledUp {
			return CGFloat.nan
		}

		let handler = Formatters.sharedConsumptionRoundingHandler
		let distanceUnit = car.ksOdometerUnit

		var distance = fuelEvent.distance
		var cost = fuelEvent.cost

		distance = distance + fuelEvent.inheritedDistance
		cost     = cost + fuelEvent.inheritedCost

		if cost == NSDecimalNumber.zero() {
			return CGFloat.nan
		}

		if distanceUnit.isMetric {
			return CGFloat((cost << 2).dividing(by: distance, withBehavior: handler).floatValue)
		} else {
			return CGFloat(distance.dividing(by: Units.kilometersPerStatuteMile).dividing(by: cost, withBehavior: handler).floatValue)
		}
	}

}
