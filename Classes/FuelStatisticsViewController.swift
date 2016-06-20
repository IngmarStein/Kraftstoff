//
//  FuelStatisticsViewController.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 06.05.15.
//
//

import UIKit
import CoreData

// Protocol for objects containing computed statistics data
protocol DiscardableDataObject {
	// Throw away easily recomputable content
	func discardContent()
}

class FuelStatisticsViewController: UIViewController {

	// Set by presenting view controller
	var selectedCar: Car!
	var pageIndex = 0

	// Coordinates for the content area
	let StatisticsHeight = CGFloat(214.0)
	let StatisticTransitionDuration = TimeInterval(0.3)

	@IBOutlet weak var activityView: UIActivityIndicatorView!
	@IBOutlet weak var leftLabel: UILabel!
	@IBOutlet weak var rightLabel: UILabel!
	@IBOutlet weak var centerLabel: UILabel!
	@IBOutlet weak var scrollView: UIScrollView!

	// Swift 2016-06-06: this should be [Int: DiscardableDataObject] instead of [Int: Any]
	// but that currently causes a compiler crash, see https://bugs.swift.org/browse/SR-1696
	var contentCache = [Int: Any]()
	var displayedNumberOfMonths = 0 {
		didSet {
			// Update selection status of all buttons
			for view in self.view.subviews {
				if let button = view as? UIButton {
					button.isSelected = button.tag == displayedNumberOfMonths
				}
			}

			// Switch dataset to be shown
			displayStatisticsForRecentMonths(displayedNumberOfMonths)
		}
	}

	private var invalidationCounter = 0
	private var expectedCounter = 0

	// MARK: - View Lifecycle

	override func viewDidLoad() {
		super.viewDidLoad()

		// Labels on top of view
		self.leftLabel.shadowColor = nil
		self.centerLabel.shadowColor = nil
		self.rightLabel.shadowColor = nil

		// Update selection status of all buttons
		for view in self.view.subviews {
			if let button = view as? UIButton {
				button.showsTouchWhenHighlighted = false
			}
		}

		setupFonts()
		NotificationCenter.default().addObserver(self, selector: #selector(FuelStatisticsViewController.contentSizeCategoryDidChange(_:)), name: Notification.Name.UIContentSizeCategoryDidChange, object: nil)
	}

	deinit {
		NotificationCenter.default().removeObserver(self)
	}

	func contentSizeCategoryDidChange(_ notification: NSNotification!) {
		setupFonts()
		invalidateCaches()
	}

	private func setupFonts() {
		let titleFont = UIFont.lightApplicationFontForStyle(UIFontTextStyleCaption2)
		let font = UIFont.lightApplicationFontForStyle(UIFontTextStyleBody)
		let fontSelected = UIFont.boldApplicationFontForStyle(UIFontTextStyleBody)

		self.leftLabel.font = titleFont
		self.centerLabel.font = titleFont
		self.rightLabel.font = titleFont

		let labelAttributes = [NSFontAttributeName: font, NSForegroundColorAttributeName: UIColor(white: 0.78, alpha: 1.0)]
		let labelSelectedAttributes = [NSFontAttributeName: fontSelected, NSForegroundColorAttributeName: UIColor.white()]
		for view in self.view.subviews {
			if let button = view as? UIButton {
				let text = button.titleLabel!.text!
				let label = AttributedString(string: text, attributes: labelAttributes)
				let labelSelected = AttributedString(string: text, attributes: labelSelectedAttributes)
				button.setAttributedTitle(label, for: [])
				button.setAttributedTitle(label, for: .highlighted)
				button.setAttributedTitle(labelSelected, for: .selected)
				button.titleLabel?.shadowColor = nil
			}
		}
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		leftLabel.text  = selectedCar.name
		rightLabel.text = ""

		displayedNumberOfMonths = UserDefaults.standard().integer(forKey: "statisticTimeSpan")
	}

	// MARK: - View Rotation
	override func shouldAutorotate() -> Bool {
		return true
	}

	override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
		return .landscape
	}

	// MARK: - Cache Handling

	func invalidateCaches() {
		contentCache.removeAll(keepingCapacity: false)
		invalidationCounter += 1
	}

	func purgeDiscardableCacheContent() {
		for (key, value) in contentCache {
			if key != displayedNumberOfMonths {
				// https://bugs.swift.org/browse/SR-1696
                // value.discardContent()
				(value as! DiscardableDataObject).discardContent()
			}
        }
	}

	// MARK: - Statistics Computation and Display

	func displayStatisticsForRecentMonths(_ numberOfMonths: Int) {
		if numberOfMonths != displayedNumberOfMonths {
			displayedNumberOfMonths = numberOfMonths
		}

		expectedCounter = invalidationCounter

		// First try to display cached data
		if displayCachedStatisticsForRecentMonths(numberOfMonths) {
			return
		}

		// Compute and draw new contents
		let selectedCarID = self.selectedCar.objectID

		let parentContext = self.selectedCar.managedObjectContext
		let sampleContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
		sampleContext.parent = parentContext
		sampleContext.perform {
			// Get the selected car
			if let sampleCar = (try? sampleContext.existingObject(with: selectedCarID)) as? Car {

				// Fetch some young events to get the most recent fillup date
				let recentEvents = CoreDataManager.objectsForFetchRequest(CoreDataManager.fetchRequestForEvents(car: sampleCar,
																									  beforeDate: Date(),
																									 dateMatches: true,
																						  inManagedObjectContext: sampleContext),
												 inManagedObjectContext: sampleContext)

				var recentFillupDate = Date()

				if recentEvents.count > 0 {
					if let recentEvent = CoreDataManager.existingObject(recentEvents[0], inManagedObjectContext: sampleContext) as? FuelEvent {
						recentFillupDate = recentEvent.timestamp
					}
				}

				// Fetch events for the selected time period
				let samplingStart = Date.dateWithOffsetInMonths(-numberOfMonths, fromDate:recentFillupDate)
				let samplingObjects = CoreDataManager.objectsForFetchRequest(CoreDataManager.fetchRequestForEvents(car: sampleCar,
																										  afterDate: samplingStart,
																										dateMatches: true,
																							 inManagedObjectContext: sampleContext),
													inManagedObjectContext: sampleContext)

				// Compute statistics
				let sampleData = self.computeStatisticsForRecentMonths(numberOfMonths,
															forCar: sampleCar,
													   withObjects: samplingObjects,
											inManagedObjectContext: sampleContext)

				// Schedule update of cache and display in main thread
				DispatchQueue.main.async {
					if self.invalidationCounter == self.expectedCounter {
						self.contentCache[numberOfMonths] = sampleData

						if self.displayedNumberOfMonths == numberOfMonths {
							self.displayCachedStatisticsForRecentMonths(numberOfMonths)
						}
					}
				}
			}
		}
	}

	@discardableResult func displayCachedStatisticsForRecentMonths(_ numberOfMonths: Int) -> Bool {
		// for subclasses
		return false
	}

	func computeStatisticsForRecentMonths(_ numberOfMonths: Int, forCar car: Car, withObjects fetchedObjects: [FuelEvent], inManagedObjectContext moc: NSManagedObjectContext) -> DiscardableDataObject {
		fatalError("computeStatisticsForRecentMonths not implemented")
	}

	func noteStatisticsPageBecomesVisible() {
	}

	// MARK: - Button Handling

	@IBAction func buttonAction(_ sender: UIButton) {
		NotificationCenter.default().post(name: "numberOfMonthsSelected" as Notification.Name, object: self, userInfo: ["span": sender.tag as NSNumber])
	}

	// MARK: - Memory Management

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		purgeDiscardableCacheContent()
	}
}
