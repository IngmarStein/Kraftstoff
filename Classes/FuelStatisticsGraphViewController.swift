//
//  FuelStatisticsGraphViewController.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 05.05.15.
//
//  Graphical Statistics View Controller

import CoreData
import UIKit

protocol FuelStatisticsViewControllerDataSource: AnyObject {
  var curveGradient: CGGradient { get }

  func averageFormatter(_ precise: Bool, forCar: Car) -> NumberFormatter
  func averageFormatString(_ prefix: Bool, forCar: Car) -> String
  func noAverageStringForCar(_ car: Car) -> String

  func axisFormatterForCar(_ car: Car) -> NumberFormatter
  func valueForFuelEvent(_ fuelEvent: FuelEvent) -> CGFloat
}

// Coordinates for statistics graph
private let statisticGraphMargin: CGFloat = 10.0
private let statisticGraphYAxisLabelWidth: CGFloat = 50.0
private let statisticGraphXAxisLabelHeight: CGFloat = 32.0
private let statisticGraphTopBorder: CGFloat = 58.0

// Coordinates for the zoom-track
private let statisticTrackYPosition: CGFloat = 40.0
private let statisticTrackThickness: CGFloat = 4.0
private let statisticTrackInfoXMarginFlat: CGFloat = 4.0
private let statisticTrackInfoYMarginFlat: CGFloat = 3.0

private let maxSamples = 256

// MARK: - Disposable Sampling Data Objects for ContentCache

private final class FuelStatisticsSamplingData: DiscardableDataObject {
  // Curve data
  var data = [CGPoint](repeating: CGPoint.zero, count: maxSamples)
  var dataCount = 0

  // Lens data
  var lensDate = [[TimeInterval]](repeating: [TimeInterval](repeating: 0.0, count: 2), count: maxSamples)
  var lensValue = [CGFloat](repeating: 0.0, count: maxSamples)

  // Data for marker positions
  var hMarkPositions = [CGFloat](repeating: 0.0, count: 5)
  var hMarkNames = [String?](repeating: nil, count: 5)
  var hMarkCount = 0

  var vMarkPositions = [CGFloat](repeating: 0.0, count: 3)
  var vMarkNames = [String?](repeating: nil, count: 3)
  var vMarkCount = 0

  var contentImage: UIImage!
  var contentAverage: CGFloat?

  func discardContent() {
    contentImage = nil
  }
}

class FuelStatisticsGraphViewController: FuelStatisticsViewController {
  private var zooming = false {
    didSet {
      for subview in stackView.subviews where subview.tag > 0 {
        if subview.tag < 1000 {
          subview.isHidden = zooming
        } else {
          subview.isHidden = !zooming
        }
      }

      if !zooming {
        displayStatisticsForRecentMonths(displayedNumberOfMonths)
      }
    }
  }

  private var zoomRecognizer: UILongPressGestureRecognizer!
  private var zoomIndex = 0
  weak var dataSource: FuelStatisticsViewControllerDataSource?

  // MARK: - Default Position/Dimension Data for Graphs

  var graphLeftBorder: CGFloat {
    statisticGraphMargin
  }

  var graphRightBorder: CGFloat {
    view.bounds.size.width - statisticGraphMargin - statisticGraphYAxisLabelWidth
  }

  var graphTopBorder: CGFloat {
    statisticGraphTopBorder
  }

  var graphBottomBorder: CGFloat {
    graphTopBorder + graphHeight
  }

  var graphWidth: CGFloat {
    view.bounds.size.width - statisticGraphMargin - statisticGraphYAxisLabelWidth - statisticGraphMargin
  }

  var graphHeight: CGFloat {
    self.view.bounds.size.height - self.graphTopBorder - statisticGraphXAxisLabelHeight
  }

  // MARK: - View Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()

    zoomRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(FuelStatisticsGraphViewController.longPressChanged(_:)))
    zoomRecognizer.minimumPressDuration = 0.4
    zoomRecognizer.numberOfTouchesRequired = 1
    zoomRecognizer.isEnabled = false

    view.addGestureRecognizer(zoomRecognizer)
  }

  // MARK: - Graph Computation

  private func resampleFetchedObjects(_ fuelEvents: [FuelEvent], forCar car: Car, andState state: FuelStatisticsSamplingData, inManagedObjectContext _: NSManagedObjectContext) -> CGFloat {
    var firstDate: Date?
    var midDate: Date?
    var lastDate: Date?

    // Compute vertical range of curve
    var valCount = 0
    var valFirstIndex = -1
    var valLastIndex = -1

    var valAverage: CGFloat = 0.0

    var valMin = CGFloat.infinity
    var valMax = -CGFloat.infinity
    var valRange: CGFloat
    var valStretchFactorForDisplay: CGFloat

    for i in (0 ..< fuelEvents.count).reversed() {
      let fuelEvent = fuelEvents[i]
      let value = dataSource!.valueForFuelEvent(fuelEvent)

      if !value.isNaN {
        valCount += 1
        valAverage += value

        if valMin > value {
          valMin = value
        }

        if valMax < value {
          valMax = value
        }

        if valLastIndex < 0 {
          valLastIndex = i
          lastDate = fuelEvent.timestamp
        } else {
          valFirstIndex = i
          firstDate = fuelEvent.timestamp
        }
      }
    }

    // Not enough data
    if valCount < 2 {
      state.dataCount = 0
      state.hMarkCount = 0
      state.vMarkCount = 0

      return valCount == 0 ? .nan : valAverage
    }

    valAverage /= CGFloat(valCount)

    valMin = floor(valMin * 2.0) / 2.0
    valMax = ceil(valMax / 2.0) * 2.0
    valRange = valMax - valMin

    if valRange > 40 {
      valMin = floor(valMin / 10.0) * 10.0
      valMax = ceil(valMax / 10.0) * 10.0
    } else if valRange > 8 {
      valMin = floor(valMin / 2.0) * 2.0
      valMax = ceil(valMax / 2.0) * 2.0
    } else if valRange > 4 {
      valMin = floor(valMin)
      valMax = ceil(valMax)
    } else if valRange < 0.25 {
      valMin = floor(valMin * 4.0 - 0.001) / 4.0
      valMax = ceil(valMax * 4.0 + 0.001) / 4.0
    }

    valRange = valMax - valMin

    // Shrink the computed graph to keep the top h-marker below the top-border
    if valRange > 0.0001 {
      valStretchFactorForDisplay = statisticsHeight / (statisticsHeight + 18.0)
    } else {
      valStretchFactorForDisplay = 1.0
    }

    // Resampling of fetched data
    var samples = [CGFloat](repeating: 0.0, count: maxSamples)
    var samplesCount = [Int](repeating: 0, count: maxSamples)

    for i in 0 ..< maxSamples {
      state.lensDate[i][0] = 0.0
      state.lensDate[i][1] = 0.0
      state.lensValue[i] = 0.0
    }

    let rangeInterval = firstDate!.timeIntervalSince(lastDate!)

    for i in (valFirstIndex ... valLastIndex).reversed() {
      let fuelEvent = fuelEvents[i]
      let value = dataSource!.valueForFuelEvent(fuelEvent)

      if !value.isNaN {
        // Collect sample data
        let sampleInterval = firstDate!.timeIntervalSince(fuelEvent.ksTimestamp)
        let sampleIndex = Int(rint(CGFloat(maxSamples - 1) * CGFloat(1.0 - sampleInterval / rangeInterval)))

        if valRange < 0.0001 {
          samples[sampleIndex] += 0.5
        } else {
          samples[sampleIndex] += (value - valMin) / valRange * valStretchFactorForDisplay
        }

        // Collect lens data
        state.lensDate[sampleIndex][(samplesCount[sampleIndex] != 0) ? 1 : 0] = fuelEvent.ksTimestamp.timeIntervalSinceReferenceDate
        state.lensValue[sampleIndex] += value

        samplesCount[sampleIndex] += 1
      }
    }

    // Build curve data from resampled values
    state.dataCount = 0

    for i in 0 ..< maxSamples where samplesCount[i] > 0 {
      state.data[state.dataCount] = CGPoint(x: CGFloat(i) / CGFloat(maxSamples - 1), y: 1.0 - samples[i] / CGFloat(samplesCount[i]))

      state.lensDate[state.dataCount][0] = state.lensDate[i][0]
      state.lensDate[state.dataCount][1] = state.lensDate[i][(samplesCount[i] > 1) ? 1 : 0]
      state.lensValue[state.dataCount] = state.lensValue[i] / CGFloat(samplesCount[i])

      state.dataCount += 1
    }

    // Markers for vertical axis
    let numberFormatter = dataSource!.axisFormatterForCar(car)

    state.hMarkPositions[0] = 1.0 - (1.0 * valStretchFactorForDisplay)
    state.hMarkNames[0] = numberFormatter.string(from: NSNumber(value: valMin + valRange))!

    state.hMarkPositions[1] = 1.0 - (0.75 * valStretchFactorForDisplay)
    state.hMarkNames[1] = numberFormatter.string(from: NSNumber(value: valMin + valRange * 0.75))!

    state.hMarkPositions[2] = 1.0 - (0.5 * valStretchFactorForDisplay)
    state.hMarkNames[2] = numberFormatter.string(from: NSNumber(value: valMin + valRange * 0.5))!

    state.hMarkPositions[3] = 1.0 - (0.25 * valStretchFactorForDisplay)
    state.hMarkNames[3] = numberFormatter.string(from: NSNumber(value: valMin + valRange * 0.25))!

    state.hMarkPositions[4] = 1.0
    state.hMarkNames[4] = numberFormatter.string(from: NSNumber(value: valMin))!
    state.hMarkCount = 5

    // Markers for horizontal axis
    let dateFormatter: DateFormatter

    if state.dataCount < 3 || firstDate!.timeIntervalSince(lastDate!) < 604_800 {
      dateFormatter = Formatters.dateTimeFormatter
      midDate = nil
    } else {
      dateFormatter = Formatters.dateFormatter
      midDate = Date(timeInterval: firstDate!.timeIntervalSince(lastDate!) / 2.0, since: lastDate!)
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
    var state: FuelStatisticsSamplingData! = contentCache[numberOfMonths] as? FuelStatisticsSamplingData

    if state == nil {
      state = FuelStatisticsSamplingData()
      state.contentAverage = resampleFetchedObjects(fetchedObjects, forCar: car, andState: state, inManagedObjectContext: moc)
    }

    // Create image data from resampled data
    if state.contentImage == nil {
      let format = UIGraphicsImageRendererFormat.default()
      format.opaque = true
      let renderer = UIGraphicsImageRenderer(bounds: view.bounds, format: format)
      state.contentImage = renderer.image { context in
        drawFlatStatisticsForState(state, context: context.cgContext)
      }
    }

    return state
  }

  // MARK: - Graph Display

  private func drawFlatStatisticsForState(_ state: FuelStatisticsSamplingData!, context: CGContext) {
    // Background colors
    UIColor.statisticsBackground.setFill()
    context.fill(view.bounds)

    UIColor.black.setFill()
    context.fill(CGRect(x: 0, y: 0, width: view.bounds.size.width, height: 28.0))

    // Contents if there is a valid state
    if state == nil {
      return
    }

    let font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.footnote)
    let path = UIBezierPath()

    context.saveGState()

    if state.dataCount == 0 {
      let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]

      let text = NSLocalizedString("Not enough data to display statistics", comment: "")
      let size = text.size(withAttributes: attributes)

      let x = floor((view.bounds.size.width - size.width) / 2.0)
      let y = floor((view.bounds.size.height - (size.height - font.descender)) / 2.0)

      text.draw(at: CGPoint(x: x, y: y), withAttributes: attributes)

    } else {
      // Color for coordinate-axes
      UIColor.coordinateAxes.setStroke()

      // Horizontal marker lines
      let dashDotPattern: [CGFloat] = [0.5, 0.5]
      let dashDotPatternLength = 1

      // Marker lines
      path.lineWidth = 0.5
      path.setLineDash(dashDotPattern, count: dashDotPatternLength, phase: 0.0)

      path.removeAllPoints()
      path.move(to: CGPoint(x: graphLeftBorder, y: 0.25))
      path.addLine(to: CGPoint(x: view.bounds.size.width - graphLeftBorder, y: 0.25))

      context.saveGState()

      var y = CGFloat(0.0)
      for i in 0 ..< state.hMarkCount {
        let lastY = y
        y = rint(graphTopBorder + graphHeight * state.hMarkPositions[i])

        context.translateBy(x: 0.0, y: y - lastY)
        path.stroke()
      }

      context.restoreGState()
    }

    context.restoreGState()

    // Axis description for horizontal marker lines markers
    context.saveGState()

    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]

    for i in 0 ..< state.hMarkCount {
      if let mark = state.hMarkNames[i] {
        let size = mark.size(withAttributes: attributes)

        let x = graphRightBorder + 6
        let y = floor(graphTopBorder + 0.5 + graphHeight * state.hMarkPositions[i] - size.height) + 0.5

        mark.draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
      }
    }

    context.restoreGState()

    // Vertical marker lines
    path.lineWidth = 0.5
    path.setLineDash(nil, count: 0, phase: 0.0)

    path.removeAllPoints()
    path.move(to: CGPoint(x: 0.25, y: graphTopBorder))
    path.addLine(to: CGPoint(x: 0.25, y: graphBottomBorder + 6))

    context.saveGState()

    var x = CGFloat(0.0)
    for i in 0 ..< state.vMarkCount {
      let lastX = x
      x = rint(graphLeftBorder + graphWidth * state.vMarkPositions[i])

      context.translateBy(x: x - lastX, y: 0.0)
      path.stroke()
    }

    context.restoreGState()

    // Axis description for vertical marker lines
    context.saveGState()

    let vMarkAttributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.text]

    for i in 0 ..< state.vMarkCount {
      if let mark = state.vMarkNames[i] {
        let size = mark.size(withAttributes: attributes)

        let center = size.width * 0.5
        var x = floor(graphLeftBorder + 0.5 + graphWidth * state.vMarkPositions[i] - center)
        let y = graphBottomBorder + 5

        if x < graphLeftBorder {
          x = graphLeftBorder
        }

        if x > graphRightBorder - size.width {
          x = graphRightBorder - size.width
        }

        mark.draw(at: CGPoint(x: x, y: y), withAttributes: vMarkAttributes)
      }
    }

    context.restoreGState()

    // Pattern fill below curve
    context.saveGState()

    path.removeAllPoints()
    path.move(to: CGPoint(x: graphLeftBorder + 1, y: graphBottomBorder))

    var minY = graphBottomBorder - 6

    for i in 0 ..< state.dataCount {
      let x = rint(graphLeftBorder + graphWidth * state.data[i].x)
      let y = rint(graphTopBorder + graphHeight * state.data[i].y)

      path.addLine(to: CGPoint(x: x, y: y))

      if y < minY {
        minY = y
      }
    }

    if minY == graphBottomBorder - 6 {
      minY = graphTopBorder
    }

    path.addLine(to: CGPoint(x: graphRightBorder, y: graphBottomBorder))
    path.close()

    // Color gradient
    path.addClip()
    context.drawLinearGradient(dataSource!.curveGradient,
                               start: CGPoint(x: 0, y: graphBottomBorder - 6),
                               end: CGPoint(x: 0, y: minY),
                               options: [CGGradientDrawingOptions.drawsBeforeStartLocation, CGGradientDrawingOptions.drawsAfterEndLocation])

    context.restoreGState()

    // Top and bottom lines
    UIColor.text.setStroke()
    path.lineWidth = 0.5

    path.removeAllPoints()
    path.move(to: CGPoint(x: graphLeftBorder, y: graphTopBorder + 0.25))
    path.addLine(to: CGPoint(x: view.bounds.size.width - graphLeftBorder, y: graphTopBorder + 0.25))
    path.stroke()

    path.removeAllPoints()
    path.move(to: CGPoint(x: graphLeftBorder, y: graphBottomBorder + 0.25))
    path.addLine(to: CGPoint(x: view.bounds.size.width - graphLeftBorder, y: graphBottomBorder + 0.25))
    path.stroke()

    // The curve
    path.lineWidth = 1
    path.lineCapStyle = .round
    UIColor.white.setStroke()

    path.removeAllPoints()
    path.move(to: CGPoint(x: rint(graphLeftBorder + graphWidth * state.data[0].x),
                          y: rint(graphTopBorder + graphHeight * state.data[0].y)))

    for i in 0 ..< state.dataCount {
      let x = rint(graphLeftBorder + graphWidth * state.data[i].x)
      let y = rint(graphTopBorder + graphHeight * state.data[i].y)

      path.addLine(to: CGPoint(x: x, y: y))
    }

    path.stroke()
  }

  override func displayCachedStatisticsForRecentMonths(_ numberOfMonths: Int) -> Bool {
    guard let imageView = view as? UIImageView else { return false }

    // Cache lookup
    let cell = contentCache[numberOfMonths] as? FuelStatisticsSamplingData
    let average = cell?.contentAverage
    let image = cell?.contentImage

    // Update summary in top right of view
    if let average = average {
      rightLabel.text = String(format: dataSource!.averageFormatString(true, forCar: selectedCar), dataSource!.averageFormatter(false, forCar: selectedCar).string(from: average as NSNumber)!)
    } else {
      rightLabel.text = dataSource!.noAverageStringForCar(selectedCar)
    }

    // Update image contents on cache hit
    if image != nil, average != nil {
      activityView.stopAnimating()

      UIView.transition(with: imageView,
                        duration: statisticTransitionDuration,
                        options: UIView.AnimationOptions.transitionCrossDissolve,
                        animations: { imageView.image = image },
                        completion: nil)

      zoomRecognizer.isEnabled = (cell?.dataCount ?? 0) > 0

      return true

    } else {
      // Cache Miss => draw prelimary contents

      let format = UIGraphicsImageRendererFormat.default()
      format.opaque = true
      let renderer = UIGraphicsImageRenderer(bounds: view.bounds, format: format)
      let image = renderer.image { context in
        drawFlatStatisticsForState(nil, context: context.cgContext)
      }

      UIView.transition(with: imageView,
                        duration: statisticTransitionDuration,
                        options: UIView.AnimationOptions.transitionCrossDissolve,
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

  @objc func longPressChanged(_: AnyObject) {
    switch zoomRecognizer.state {
    case .possible:
      break

    case .began:

      // Cancel long press gesture when located above the graph (new the radio buttons)
      if zoomRecognizer.location(in: view).y < graphTopBorder {
        zoomRecognizer.isEnabled = false
        zoomRecognizer.isEnabled = true
        break
      }

      zooming = true
      zoomIndex = -1

      fallthrough

    case .changed:
      var lensLocation = zoomRecognizer.location(in: view)

      // Keep horizontal position above graphics
      if lensLocation.x < graphLeftBorder {
        lensLocation.x = graphLeftBorder
      } else if lensLocation.x > graphLeftBorder + graphWidth {
        lensLocation.x = graphLeftBorder + graphWidth
      }

      lensLocation.x -= graphLeftBorder
      lensLocation.x /= graphWidth

      // Match nearest data point
      let cell = contentCache[displayedNumberOfMonths] as? FuelStatisticsSamplingData

      if let cell = cell {
        var lb = 0
        var ub = cell.dataCount - 1

        while ub - lb > 1 {
          let mid = Int((lb + ub) / 2)

          if lensLocation.x < cell.data[mid].x {
            ub = mid
          } else if lensLocation.x > cell.data[mid].x {
            lb = mid
          } else {
            lb = mid
            ub = mid
          }
        }

        let minIndex = (abs(cell.data[lb].x - lensLocation.x) < abs(cell.data[ub].x - lensLocation.x)) ? lb : ub

        // Update screen contents
        if minIndex >= 0, minIndex != zoomIndex {
          zoomIndex = minIndex

          // Date information
          let df = Formatters.longDateFormatter

          if cell.lensDate[minIndex][0] == cell.lensDate[minIndex][1] {
            centerLabel.text = df.string(from: Date(timeIntervalSinceReferenceDate: cell.lensDate[minIndex][0]))
          } else {
            centerLabel.text = "\(df.string(from: Date(timeIntervalSinceReferenceDate: cell.lensDate[minIndex][0])))  ➡  \(df.string(from: Date(timeIntervalSinceReferenceDate: cell.lensDate[minIndex][1])))"
          }

          // Knob position
          lensLocation.x = rint(graphLeftBorder + graphWidth * cell.data[minIndex].x)
          lensLocation.y = rint(graphTopBorder + graphHeight * cell.data[minIndex].y)

          // Image with value information
          if let imageView = view as? UIImageView {
            let format = UIGraphicsImageRendererFormat.default()
            format.opaque = true
            let renderer = UIGraphicsImageRenderer(bounds: view.bounds, format: format)

            let valueString = String(format: dataSource!.averageFormatString(false, forCar: selectedCar),
                                     dataSource!.averageFormatter(true, forCar: selectedCar).string(from: NSNumber(value: cell.lensValue[minIndex]))!)

            imageView.image = renderer.image { context in
              drawFlatLensWithBGImage(cell.contentImage, lensLocation: lensLocation, info: valueString, context: context.cgContext)
            }
          }
        }
      }

    case .ended, .cancelled, .failed:
      if ProcessInfo.processInfo.arguments.firstIndex(of: "-KEEPLENS") == nil {
        zooming = false
      }

    @unknown default:
      break
    }
  }

  private func drawFlatLensWithBGImage(_ background: UIImage, lensLocation location: CGPoint, info: String, context _: CGContext) {
    var path = UIBezierPath()

    // Graph as background
    background.draw(at: CGPoint.zero, blendMode: .copy, alpha: 1.0)

    // Marker line
    view.tintColor.set()

    path.lineWidth = 0.5

    path.removeAllPoints()
    path.move(to: CGPoint(x: location.x + 0.25, y: graphTopBorder + 0.5))
    path.addLine(to: CGPoint(x: location.x + 0.25, y: graphBottomBorder))
    path.stroke()

    // Marker knob
    path = UIBezierPath(arcCenter: location, radius: 5.5, startAngle: 0.0, endAngle: .pi * 2.0, clockwise: false)
    UIColor.black.set()
    path.fill()

    path = UIBezierPath(arcCenter: location, radius: 5.0, startAngle: 0.0, endAngle: .pi * 2.0, clockwise: false)
    view.tintColor.set()
    path.fill()

    // Layout for info box
    let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.preferredFont(forTextStyle: UIFont.TextStyle.caption2),
                                                     .foregroundColor: UIColor.white]

    var infoRect = CGRect()
    infoRect.size = info.size(withAttributes: attributes)
    infoRect.size.width += statisticTrackInfoXMarginFlat * 2.0
    infoRect.size.height += statisticTrackInfoYMarginFlat * 2.0
    infoRect.origin.x = rint(location.x - infoRect.size.width / 2)
    infoRect.origin.y = statisticTrackYPosition + rint((statisticTrackThickness - infoRect.size.height) / 2)

    if infoRect.origin.x < graphLeftBorder {
      infoRect.origin.x = graphLeftBorder
    }

    if infoRect.origin.x > view.bounds.size.width - graphLeftBorder - infoRect.size.width {
      infoRect.origin.x = view.bounds.size.width - graphLeftBorder - infoRect.size.width
    }

    // Info box
    path = UIBezierPath(roundedRect: infoRect,
                        byRoundingCorners: .allCorners,
                        cornerRadii: CGSize(width: 4.0, height: 4.0))

    view.tintColor.set()
    path.fill()

    // Info text
    info.draw(at: CGPoint(x: infoRect.origin.x + statisticTrackInfoXMarginFlat, y: infoRect.origin.y + statisticTrackInfoYMarginFlat), withAttributes: attributes)
  }
}

// MARK: - Data Sources for Different Statistic Graphs

class FuelStatisticsViewControllerDataSourceAvgConsumption: FuelStatisticsViewControllerDataSource {
  var curveGradient: CGGradient = {
    let colorComponentsFlat: [CGFloat] = [0.662, 0.815, 0.502, 0.0, 0.662, 0.815, 0.502, 0.9]

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let greenGradient = CGGradient(colorSpace: colorSpace, colorComponents: colorComponentsFlat, locations: nil, count: 2)!

    return greenGradient
  }()

  func averageFormatter(_: Bool, forCar _: Car) -> NumberFormatter {
    Formatters.fuelVolumeFormatter
  }

  func averageFormatString(_ avgPrefix: Bool, forCar car: Car) -> String {
    let prefix = avgPrefix ? "∅ " : ""
    let unit = Formatters.shortMeasurementFormatter.string(from: car.ksFuelConsumptionUnit)

    return "\(prefix)%@ \(unit)"
  }

  func noAverageStringForCar(_ car: Car) -> String {
    Formatters.shortMeasurementFormatter.string(from: car.ksFuelConsumptionUnit)
  }

  func axisFormatterForCar(_: Car) -> NumberFormatter {
    Formatters.fuelVolumeFormatter
  }

  func valueForFuelEvent(_ fuelEvent: FuelEvent) -> CGFloat {
    if !fuelEvent.filledUp {
      return .nan
    }

    let consumptionUnit = fuelEvent.car!.ksFuelConsumptionUnit
    let distance = fuelEvent.ksDistance + fuelEvent.ksInheritedDistance
    let fuelVolume = fuelEvent.ksFuelVolume + fuelEvent.ksInheritedFuelVolume

    return CGFloat((Units.consumptionForKilometers(distance, liters: fuelVolume, inUnit: consumptionUnit) as NSDecimalNumber).floatValue)
  }
}

class FuelStatisticsViewControllerDataSourcePriceAmount: FuelStatisticsViewControllerDataSource {
  var curveGradient: CGGradient = {
    let colorComponentsFlat: [CGFloat] = [0.988, 0.662, 0.333, 0.0, 0.988, 0.662, 0.333, 0.9]

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let orangeGradient = CGGradient(colorSpace: colorSpace, colorComponents: colorComponentsFlat, locations: nil, count: 2)!

    return orangeGradient
  }()

  func averageFormatter(_ precise: Bool, forCar _: Car) -> NumberFormatter {
    precise ? Formatters.preciseCurrencyFormatter : Formatters.currencyFormatter
  }

  func averageFormatString(_ avgPrefix: Bool, forCar car: Car) -> String {
    let prefix = avgPrefix ? "∅ " : ""
    let unit = Formatters.shortMeasurementFormatter.string(from: car.ksFuelUnit)

    return "\(prefix)%@/\(unit)"
  }

  func noAverageStringForCar(_ car: Car) -> String {
    "\(Formatters.currencyFormatter.currencySymbol!)/\(Formatters.shortMeasurementFormatter.string(from: car.ksFuelUnit))"
  }

  func axisFormatterForCar(_: Car) -> NumberFormatter {
    Formatters.axisCurrencyFormatter
  }

  func valueForFuelEvent(_ fuelEvent: FuelEvent) -> CGFloat {
    let price = fuelEvent.ksPrice

    if price.isZero {
      return .nan
    }

    return CGFloat((Units.pricePerUnit(price, withUnit: fuelEvent.car!.ksFuelUnit) as NSDecimalNumber).floatValue)
  }
}

class FuelStatisticsViewControllerDataSourcePriceDistance: FuelStatisticsViewControllerDataSource {
  var curveGradient: CGGradient = {
    let colorComponentsFlat: [CGFloat] = [0.360, 0.682, 0.870, 0.0, 0.466, 0.721, 0.870, 0.9]

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let blueGradient = CGGradient(colorSpace: colorSpace, colorComponents: colorComponentsFlat, locations: nil, count: 2)!

    return blueGradient
  }()

  func averageFormatter(_: Bool, forCar car: Car) -> NumberFormatter {
    let distanceUnit = car.ksOdometerUnit

    if distanceUnit == UnitLength.kilometers {
      return Formatters.currencyFormatter
    } else {
      return Formatters.distanceFormatter
    }
  }

  func averageFormatString(_ avgPrefix: Bool, forCar car: Car) -> String {
    let prefix = avgPrefix ? "∅ " : ""
    if car.ksOdometerUnit == UnitLength.kilometers {
      return "\(prefix)%@/100km"
    } else {
      let currencySymbol = Formatters.currencyFormatter.currencySymbol!
      return "\(prefix)%@ mi/\(currencySymbol)"
    }
  }

  func noAverageStringForCar(_ car: Car) -> String {
    let distanceUnit = car.ksOdometerUnit

    return distanceUnit == UnitLength.kilometers ? "\(Formatters.currencyFormatter.currencySymbol!)/100km" : "mi/\(Formatters.currencyFormatter.currencySymbol!)"
  }

  func axisFormatterForCar(_ car: Car) -> NumberFormatter {
    let distanceUnit = car.ksOdometerUnit

    if distanceUnit == UnitLength.kilometers {
      return Formatters.axisCurrencyFormatter
    } else {
      return Formatters.distanceFormatter
    }
  }

  func valueForFuelEvent(_ fuelEvent: FuelEvent) -> CGFloat {
    if !fuelEvent.filledUp {
      return .nan
    }

    let handler = Formatters.consumptionRoundingHandler
    let distanceUnit = fuelEvent.car!.ksOdometerUnit

    let distance = fuelEvent.ksDistance + fuelEvent.ksInheritedDistance
    let cost = fuelEvent.cost + fuelEvent.ksInheritedCost

    if cost.isZero {
      return .nan
    }

    if distanceUnit == UnitLength.kilometers {
      return CGFloat(((cost << 2) as NSDecimalNumber).dividing(by: distance as NSDecimalNumber, withBehavior: handler).floatValue)
    } else {
      return CGFloat((distance as NSDecimalNumber).dividing(by: Units.kilometersPerStatuteMile as NSDecimalNumber).dividing(by: cost as NSDecimalNumber, withBehavior: handler).floatValue)
    }
  }
}
