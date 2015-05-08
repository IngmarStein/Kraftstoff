//
//  FuelStatisticsViewController.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 06.05.15.
//
//

import UIKit
import CoreData

// Coordinates for the content area
let StatisticsHeight = CGFloat(214.0)
let StatisticTransitionDuration = NSTimeInterval(0.3)

// Protocol for objects containing computed statistics data
protocol DiscardableDataObject {
	// Throw away easily recomputable content
	func discardContent()
}

class FuelStatisticsViewController: UIViewController {

	// Set by presenting view controller
	var selectedCar: Car!

	@IBOutlet weak var activityView: UIActivityIndicatorView!
	@IBOutlet weak var leftLabel: UILabel!
	@IBOutlet weak var rightLabel: UILabel!
	@IBOutlet weak var centerLabel: UILabel!
	@IBOutlet weak var scrollView: UIScrollView!

	var contentCache = [Int : DiscardableDataObject]()
	var displayedNumberOfMonths = 0 {
		didSet {
			// Update selection status of all buttons
			for view in self.view.subviews as! [UIView] {
				if let button = view as? UIButton {
					button.selected = button.tag == displayedNumberOfMonths
				}
			}

			// Switch dataset to be shown
			displayStatisticsForRecentMonths(displayedNumberOfMonths)
		}
	}

	private var invalidationCounter = 0
	private var expectedCounter = 0

	//MARK: - View Lifecycle

	override func viewDidLoad() {
		super.viewDidLoad()

		let titleFont = UIFont(name:"HelveticaNeue-Light", size:17)!
		let font = UIFont(name:"HelveticaNeue-Light", size:14)!
		let fontSelected = UIFont(name:"HelveticaNeue-Bold", size:14)!

		// Labels on top of view
		self.leftLabel.font = titleFont
		self.centerLabel.font = titleFont
		self.rightLabel.font = titleFont
		self.leftLabel.shadowColor = nil
		self.centerLabel.shadowColor = nil
		self.rightLabel.shadowColor = nil

		// Update selection status of all buttons
		let labelAttributes = [NSFontAttributeName:font, NSForegroundColorAttributeName:UIColor(white:0.78, alpha:1.0)]
		let labelSelectedAttributes = [NSFontAttributeName:fontSelected, NSForegroundColorAttributeName:UIColor.whiteColor()]
		for view in self.view.subviews as! [UIView] {
			if let button = view as? UIButton {
				let text = button.titleLabel!.text!
				let label = NSAttributedString(string:text, attributes:labelAttributes)
				let labelSelected = NSAttributedString(string:text, attributes: labelSelectedAttributes)
				button.setAttributedTitle(label, forState:.Normal)
				button.setAttributedTitle(label, forState:.Highlighted)
				button.setAttributedTitle(labelSelected, forState:.Selected)
				button.showsTouchWhenHighlighted = false
				button.titleLabel!.shadowColor = nil
			}
		}
	}

	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)

		leftLabel.text  = selectedCar.name
		rightLabel.text = ""

		displayedNumberOfMonths = NSUserDefaults.standardUserDefaults().integerForKey("statisticTimeSpan")
	}

	//MARK: - View Rotation
	override func shouldAutorotate() -> Bool {
		return true
	}

	override func supportedInterfaceOrientations() -> Int {
		return Int(UIInterfaceOrientationMask.Landscape.rawValue)
	}

	//MARK: - Cache Handling

	func invalidateCaches() {
		contentCache.removeAll(keepCapacity: false)
		invalidationCounter++
	}

	func purgeDiscardableCacheContent() {
		for (key, value) in contentCache {
			if key != displayedNumberOfMonths {
                value.discardContent()
			}
        }
	}

	//MARK: - Statistics Computation and Display

	func displayStatisticsForRecentMonths(numberOfMonths: Int) {
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
		let sampleContext = NSManagedObjectContext(concurrencyType:.PrivateQueueConcurrencyType)
		sampleContext.parentContext = parentContext
		sampleContext.performBlock {
			// Get the selected car
			var error: NSError?
			if let sampleCar = sampleContext.existingObjectWithID(selectedCarID, error:&error) as? Car {

				// Fetch some young events to get the most recent fillup date
				let recentEvents = AppDelegate.objectsForFetchRequest(AppDelegate.fetchRequestForEventsForCar(sampleCar,
                                                                                                      beforeDate:NSDate(),
                                                                                                     dateMatches:true,
                                                                                          inManagedObjectContext:sampleContext),
                                                 inManagedObjectContext:sampleContext)

				var recentFillupDate = NSDate()

				if recentEvents.count > 0 {
					if let recentEvent = AppDelegate.existingObject(recentEvents[0], inManagedObjectContext:sampleContext) as? FuelEvent {
						recentFillupDate = recentEvent.timestamp
					}
				}

				// Fetch events for the selected time period
				let samplingStart = NSDate.dateWithOffsetInMonths(-numberOfMonths, fromDate:recentFillupDate)
				let samplingObjects = AppDelegate.objectsForFetchRequest(AppDelegate.fetchRequestForEventsForCar(sampleCar,
                                                                                                          afterDate:samplingStart,
                                                                                                        dateMatches:true,
                                                                                             inManagedObjectContext:sampleContext),
                                                    inManagedObjectContext:sampleContext) as! [FuelEvent]

				// Compute statistics
				let sampleData = self.computeStatisticsForRecentMonths(numberOfMonths,
                                                            forCar:sampleCar,
                                                       withObjects:samplingObjects,
                                            inManagedObjectContext:sampleContext)

				// Schedule update of cache and display in main thread
				dispatch_async(dispatch_get_main_queue()) {
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

	func displayCachedStatisticsForRecentMonths(numberOfMonths: Int) -> Bool {
		// for subclasses
		return false
	}

	func computeStatisticsForRecentMonths(numberOfMonths: Int, forCar car: Car, withObjects fetchedObjects: [FuelEvent], inManagedObjectContext moc: NSManagedObjectContext) -> DiscardableDataObject {
		fatalError("computeStatisticsForRecentMonths not implemented")
	}

	func noteStatisticsPageBecomesVisible(visible: Bool) {
	}

	//MARK: - Button Handling

	@IBAction func buttonAction(sender: UIButton) {
		NSNotificationCenter.defaultCenter().postNotificationName("numberOfMonthsSelected", object:self, userInfo:["span":sender.tag])
	}

	//MARK: - Memory Management

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		purgeDiscardableCacheContent()
	}
}
