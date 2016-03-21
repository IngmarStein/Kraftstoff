//
//  FuelStatisticsPageController.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 05.05.15.
//
//

import UIKit

final class FuelStatisticsPageController: UIPageViewController {

	// Set by presenting view controller
	var selectedCar: Car!
	var statisticsViewControllers = [FuelStatisticsViewController]()

	//MARK: - View Lifecycle

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)

		self.modalTransitionStyle = .CrossDissolve
		self.dataSource = self
		self.delegate = self
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		// Load content pages
		let priceDistanceViewController = self.storyboard!.instantiateViewControllerWithIdentifier("FuelStatisticsGraphViewController") as! FuelStatisticsGraphViewController
		priceDistanceViewController.dataSource = FuelStatisticsViewControllerDataSourcePriceDistance()
		priceDistanceViewController.selectedCar = self.selectedCar
		priceDistanceViewController.pageIndex = 0

		let avgConsumptionViewController = self.storyboard!.instantiateViewControllerWithIdentifier("FuelStatisticsGraphViewController") as! FuelStatisticsGraphViewController
		avgConsumptionViewController.dataSource = FuelStatisticsViewControllerDataSourceAvgConsumption()
		avgConsumptionViewController.selectedCar = self.selectedCar
		avgConsumptionViewController.pageIndex = 1

		let priceAmountViewController = self.storyboard!.instantiateViewControllerWithIdentifier("FuelStatisticsGraphViewController") as! FuelStatisticsGraphViewController
		priceAmountViewController.dataSource = FuelStatisticsViewControllerDataSourcePriceAmount()
		priceAmountViewController.selectedCar = self.selectedCar
		priceAmountViewController.pageIndex = 2

		let statisticsViewController = self.storyboard!.instantiateViewControllerWithIdentifier("FuelStatisticsTextViewController") as! FuelStatisticsTextViewController
		statisticsViewController.selectedCar = self.selectedCar
		statisticsViewController.pageIndex = 3

		statisticsViewControllers = [priceDistanceViewController, avgConsumptionViewController, priceAmountViewController, statisticsViewController]

		dispatch_async (dispatch_get_main_queue()) {
			var page = NSUserDefaults.standardUserDefaults().integerForKey("preferredStatisticsPage")
			if page < 0 || page >= self.statisticsViewControllers.count {
				page = 0
			}
			self.setViewControllers([self.statisticsViewControllers[page]], direction: .Forward, animated: false, completion: nil)
		}
    
		NSNotificationCenter.defaultCenter().addObserver(self,
           selector:#selector(FuelStatisticsPageController.localeChanged(_:)),
               name:NSCurrentLocaleDidChangeNotification,
             object:nil)

		NSNotificationCenter.defaultCenter().addObserver(self,
           selector:#selector(FuelStatisticsPageController.didEnterBackground(_:)),
               name:UIApplicationDidEnterBackgroundNotification,
             object:nil)

		NSNotificationCenter.defaultCenter().addObserver(self,
           selector:#selector(FuelStatisticsPageController.didBecomeActive(_:)),
               name:UIApplicationDidBecomeActiveNotification,
             object:nil)

		NSNotificationCenter.defaultCenter().addObserver(self,
           selector:#selector(FuelStatisticsPageController.numberOfMonthsSelected(_:)),
               name:"numberOfMonthsSelected",
             object:nil)
	}

	var currentPage: Int {
		guard let statisticsViewController = viewControllers?.first as? FuelStatisticsViewController else { return -1 }
		return statisticsViewController.pageIndex
	}

	override func preferredStatusBarStyle() -> UIStatusBarStyle {
		return .LightContent
	}

	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)

		NSUserDefaults.standardUserDefaults().setInteger(currentPage, forKey:"preferredStatisticsPage")
		NSUserDefaults.standardUserDefaults().synchronize()
	}

	//MARK: - View Rotation

	override func shouldAutorotate() -> Bool {
		return true
	}

	//MARK: - Cache Handling

	func invalidateCaches() {
		for controller in self.childViewControllers as! [FuelStatisticsViewController] {
			controller.invalidateCaches()
		}
	}

	//MARK: - System Events

	func localeChanged(object: AnyObject) {
		invalidateCaches()
	}

	func didEnterBackground(object: AnyObject) {
		NSUserDefaults.standardUserDefaults().setInteger(currentPage, forKey:"preferredStatisticsPage")
		NSUserDefaults.standardUserDefaults().synchronize()

		for controller in statisticsViewControllers {
			controller.purgeDiscardableCacheContent()
		}
	}

	private func updatePageVisibility() {
		for controller in statisticsViewControllers {
			if viewControllers!.contains(controller) {
				controller.noteStatisticsPageBecomesVisible()
			}
		}
	}

	func didBecomeActive(object: AnyObject) {
		updatePageVisibility()
	}

	//MARK: - User Events

	func numberOfMonthsSelected(notification: NSNotification) {
		// Remember selection in preferences
		if let numberOfMonths = notification.userInfo?["span"] as? Int {
			NSUserDefaults.standardUserDefaults().setInteger(numberOfMonths, forKey:"statisticTimeSpan")

			// Update all statistics controllers
			for controller in self.childViewControllers as! [FuelStatisticsViewController] {
				controller.displayedNumberOfMonths = numberOfMonths
			}
		}
	}

	//MARK: - Memory Management

	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}
}

extension FuelStatisticsPageController : UIPageViewControllerDelegate {
	func pageViewControllerSupportedInterfaceOrientations(pageViewController: UIPageViewController) -> UIInterfaceOrientationMask {
		return .Landscape
	}

	func pageViewController(pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
		if completed {
			updatePageVisibility()
		}
	}
}

extension FuelStatisticsPageController : UIPageViewControllerDataSource {
	func pageViewController(pageViewController: UIPageViewController, viewControllerAfterViewController viewController: UIViewController) -> UIViewController? {
		guard let statisticsViewController = viewController as? FuelStatisticsViewController else { return nil }
		let page = statisticsViewController.pageIndex
		if statisticsViewController.pageIndex < statisticsViewControllers.count - 1 {
			return statisticsViewControllers[page+1]
		} else {
			return statisticsViewControllers.first!
		}
	}

	func pageViewController(pageViewController: UIPageViewController, viewControllerBeforeViewController viewController: UIViewController) -> UIViewController? {
		guard let statisticsViewController = viewController as? FuelStatisticsViewController else { return nil }
		let page = statisticsViewController.pageIndex
		if page > 0 {
			return statisticsViewControllers[page-1]
		} else {
			return statisticsViewControllers.last!
		}
	}

	func presentationCountForPageViewController(pageViewController: UIPageViewController) -> Int {
		return statisticsViewControllers.count
	}

	func presentationIndexForPageViewController(pageViewController: UIPageViewController) -> Int {
		return currentPage
	}
}
