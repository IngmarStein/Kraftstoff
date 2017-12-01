//
//  FuelStatisticsViewController.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 06.05.15.
//
//

import UIKit
import RealmSwift

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
	let statisticsHeight = CGFloat(214.0)
	let statisticTransitionDuration = TimeInterval(0.3)

	@IBOutlet weak var activityView: UIActivityIndicatorView!
	@IBOutlet weak var leftLabel: UILabel!
	@IBOutlet weak var rightLabel: UILabel!
	@IBOutlet weak var centerLabel: UILabel!
	@IBOutlet weak var scrollView: UIScrollView!

	var contentCache = [Int: DiscardableDataObject]()
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
		NotificationCenter.default.addObserver(self, selector: #selector(FuelStatisticsViewController.contentSizeCategoryDidChange(_:)), name: Notification.Name.UIContentSizeCategoryDidChange, object: nil)
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}

	@objc func contentSizeCategoryDidChange(_ notification: NSNotification!) {
		invalidateCaches()
	}

	private func setupFonts() {
		let font = UIFont.preferredFont(forTextStyle: .body)
		let fontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body).withSymbolicTraits(.traitBold)!
		let fontSelected = UIFont(descriptor: fontDescriptor, size: fontDescriptor.pointSize)

		let labelAttributes: [NSAttributedStringKey: Any] = [NSAttributedStringKey.font: font, NSAttributedStringKey.foregroundColor: UIColor.text]
		let labelSelectedAttributes: [NSAttributedStringKey: Any] = [NSAttributedStringKey.font: fontSelected, NSAttributedStringKey.foregroundColor: UIColor.white]
		for view in self.view.subviews {
			if let button = view as? UIButton {
				let text = button.titleLabel!.text!
				let label = NSAttributedString(string: text, attributes: labelAttributes)
				let labelSelected = NSAttributedString(string: text, attributes: labelSelectedAttributes)
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

		displayedNumberOfMonths = UserDefaults.standard.integer(forKey: "statisticTimeSpan")
	}

	// MARK: - View Rotation

	override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
		return .landscape
	}

	// MARK: - Cache Handling

	func invalidateCaches() {
		contentCache.removeAll(keepingCapacity: false)
		invalidationCounter += 1
	}

	func purgeDiscardableCacheContent() {
		for (key, value) in contentCache where key != displayedNumberOfMonths {
			value.discardContent()
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
		let selectedCarID = self.selectedCar.id

		DispatchQueue(label: "sample").async {
			autoreleasepool {
				let realm = try! Realm()

				// Get the selected car
				if let sampleCar = realm.object(ofType: Car.self, forPrimaryKey: selectedCarID) {

					// Fetch some young events to get the most recent fillup date
					let recentEvents = DataManager.fuelEventsForCar(car: sampleCar,
																	beforeDate: Date(),
																	dateMatches: true)

					var recentFillupDate = Date()

					if recentEvents.count > 0 {
						recentFillupDate = recentEvents[0].timestamp
					}

					// Fetch events for the selected time period
					let samplingStart = Date.dateWithOffsetInMonths(-numberOfMonths, fromDate: recentFillupDate)

					// Schedule update of cache and display in main thread
					DispatchQueue.main.async {
						let samplingObjects = DataManager.fuelEventsForCar(car: self.selectedCar,
																		   afterDate: samplingStart,
																		   dateMatches: true)

						// Compute statistics
						let sampleData = self.computeStatisticsForRecentMonths(numberOfMonths,
																			   forCar: self.selectedCar,
																			   withObjects: Array(samplingObjects))

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
	}

	@discardableResult func displayCachedStatisticsForRecentMonths(_ numberOfMonths: Int) -> Bool {
		// for subclasses
		return false
	}

	func computeStatisticsForRecentMonths(_ numberOfMonths: Int, forCar car: Car, withObjects fetchedObjects: [FuelEvent]) -> DiscardableDataObject {
		fatalError("computeStatisticsForRecentMonths not implemented")
	}

	func noteStatisticsPageBecomesVisible() {
	}

	// MARK: - Button Handling

	@IBAction func buttonAction(_ sender: UIButton) {
		NotificationCenter.default.post(name: Notification.Name("numberOfMonthsSelected"), object: self, userInfo: ["span": sender.tag])
	}

	// MARK: - Memory Management

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		purgeDiscardableCacheContent()
	}

}
