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
	let layoutCondition = NSCondition()
	var didLayout = false

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
	@IBOutlet weak var stackView: UIStackView!

	var contentCache = [Int: DiscardableDataObject]()
	var displayedNumberOfMonths = 0 {
		didSet {
			// Update selection status of all buttons
			for view in stackView.subviews {
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
		for view in stackView.subviews {
			if let button = view as? UIButton {
				button.showsTouchWhenHighlighted = false
			}
		}

		setupFonts()
		NotificationCenter.default.addObserver(self, selector: #selector(FuelStatisticsViewController.contentSizeCategoryDidChange(_:)), name: UIContentSizeCategory.didChangeNotification, object: nil)
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

		let labelAttributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.text]
		let labelSelectedAttributes: [NSAttributedString.Key: Any] = [.font: fontSelected, .foregroundColor: UIColor.white]
		for view in stackView.subviews {
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

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()

		layoutCondition.lock()
		didLayout = true
		layoutCondition.signal()
		layoutCondition.unlock()
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
				// swiftlint:disable:next force_try
				let realm = try! Realm()

				// Get the selected car
				// TODO: UBsan detects null pointer usage in the following call:
//				#0	0x000000010dd046e0 in __ubsan_on_report ()
//				#1	0x000000010dcfeaad in __ubsan::Diag::~Diag() ()
//				#2	0x000000010dd00424 in handleTypeMismatchImpl(__ubsan::TypeMismatchData*, unsigned long, __ubsan::ReportOptions) ()
//				#3	0x000000010dd0016b in __ubsan_handle_type_mismatch_v1 ()
//				#4	0x000000010a68c32b in RLMAccessorContext::is_null(objc_object*) at /Users/ingmar/Devel/Kraftstoff/Pods/Realm/include/RLMAccessor.hpp:83
//				#5	0x000000010a75e9f7 in unsigned long realm::Object::get_for_primary_key_impl<objc_object* __strong, RLMAccessorContext>(RLMAccessorContext&, realm::Table const&, realm::Property const&, objc_object* __strong) at /Users/ingmar/Devel/Kraftstoff/Pods/Realm/include/object_accessor.hpp:318
//				#6	0x000000010a75e131 in realm::Object realm::Object::get_for_primary_key<objc_object* __strong, RLMAccessorContext>(RLMAccessorContext&, std::__1::shared_ptr<realm::Realm> const&, realm::ObjectSchema const&, objc_object* __strong) at /Users/ingmar/Devel/Kraftstoff/Pods/Realm/include/object_accessor.hpp:309
//				#7	0x000000010a75d6ae in ::RLMGetObject(RLMRealm *, NSString *, id) at /Users/ingmar/Devel/Kraftstoff/Pods/Realm/Realm/RLMObjectStore.mm:238
//				#8	0x000000010c6d9c77 in Realm.object<A, B>(ofType:forPrimaryKey:) at /Users/ingmar/Devel/Kraftstoff/Pods/RealmSwift/RealmSwift/Realm.swift:510
//				#9	0x0000000109b363a9 in closure #1 in closure #1 in FuelStatisticsViewController.displayStatisticsForRecentMonths(_:) at /Users/ingmar/Devel/Kraftstoff/Classes/FuelStatisticsViewController.swift:153

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

					self.layoutCondition.lock()
					while !self.didLayout {
						self.layoutCondition.wait()
					}
					self.layoutCondition.unlock()

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
		NotificationCenter.default.post(name: NSNotification.Name(rawValue: "numberOfMonthsSelected"), object: self, userInfo: ["span": sender.tag])
	}

	// MARK: - Memory Management

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		purgeDiscardableCacheContent()
	}

}
