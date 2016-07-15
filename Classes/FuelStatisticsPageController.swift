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

	// MARK: - View Lifecycle

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)

		self.modalTransitionStyle = .crossDissolve
		self.dataSource = self
		self.delegate = self
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		// Load content pages
		// swiftlint:disable:next force_cast
		let priceDistanceViewController = self.storyboard!.instantiateViewController(withIdentifier: "FuelStatisticsGraphViewController") as! FuelStatisticsGraphViewController
		priceDistanceViewController.dataSource = FuelStatisticsViewControllerDataSourcePriceDistance()
		priceDistanceViewController.selectedCar = self.selectedCar
		priceDistanceViewController.pageIndex = 0

		// swiftlint:disable:next force_cast
		let avgConsumptionViewController = self.storyboard!.instantiateViewController(withIdentifier: "FuelStatisticsGraphViewController") as! FuelStatisticsGraphViewController
		avgConsumptionViewController.dataSource = FuelStatisticsViewControllerDataSourceAvgConsumption()
		avgConsumptionViewController.selectedCar = self.selectedCar
		avgConsumptionViewController.pageIndex = 1

		// swiftlint:disable:next force_cast
		let priceAmountViewController = self.storyboard!.instantiateViewController(withIdentifier: "FuelStatisticsGraphViewController") as! FuelStatisticsGraphViewController
		priceAmountViewController.dataSource = FuelStatisticsViewControllerDataSourcePriceAmount()
		priceAmountViewController.selectedCar = self.selectedCar
		priceAmountViewController.pageIndex = 2

		// swiftlint:disable:next force_cast
		let statisticsViewController = self.storyboard!.instantiateViewController(withIdentifier: "FuelStatisticsTextViewController") as! FuelStatisticsTextViewController
		statisticsViewController.selectedCar = self.selectedCar
		statisticsViewController.pageIndex = 3

		statisticsViewControllers = [priceDistanceViewController, avgConsumptionViewController, priceAmountViewController, statisticsViewController]

		DispatchQueue.main.async {
			var page = UserDefaults.standard.integer(forKey: "preferredStatisticsPage")
			if page < 0 || page >= self.statisticsViewControllers.count {
				page = 0
			}
			self.setViewControllers([self.statisticsViewControllers[page]], direction: .forward, animated: false, completion: nil)
		}

		NotificationCenter.default.addObserver(self,
           selector: #selector(FuelStatisticsPageController.localeChanged(_:)),
               name: Locale.currentLocaleDidChangeNotification,
             object: nil)

		NotificationCenter.default.addObserver(self,
           selector: #selector(FuelStatisticsPageController.didEnterBackground(_:)),
               name: Notification.Name.UIApplicationDidEnterBackground,
             object: nil)

		NotificationCenter.default.addObserver(self,
           selector: #selector(FuelStatisticsPageController.didBecomeActive(_:)),
               name: Notification.Name.UIApplicationDidBecomeActive,
             object: nil)

		NotificationCenter.default.addObserver(self,
           selector: #selector(FuelStatisticsPageController.numberOfMonthsSelected(_:)),
               name: NSNotification.Name("numberOfMonthsSelected"),
             object: nil)
	}

	var currentPage: Int {
		guard let statisticsViewController = viewControllers?.first as? FuelStatisticsViewController else { return -1 }
		return statisticsViewController.pageIndex
	}

	override func preferredStatusBarStyle() -> UIStatusBarStyle {
		return .lightContent
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		UserDefaults.standard.set(currentPage, forKey: "preferredStatisticsPage")
		UserDefaults.standard.synchronize()
	}

	// MARK: - View Rotation

	override func shouldAutorotate() -> Bool {
		return true
	}

	// MARK: - Cache Handling

	func invalidateCaches() {
		for controller in self.childViewControllers {
			if let fuelStatisticsViewController = controller as? FuelStatisticsViewController {
				fuelStatisticsViewController.invalidateCaches()
			}
		}
	}

	// MARK: - System Events

	func localeChanged(_ object: AnyObject) {
		invalidateCaches()
	}

	func didEnterBackground(_ object: AnyObject) {
		UserDefaults.standard.set(currentPage, forKey: "preferredStatisticsPage")
		UserDefaults.standard.synchronize()

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

	func didBecomeActive(_ object: AnyObject) {
		updatePageVisibility()
	}

	// MARK: - User Events

	func numberOfMonthsSelected(_ notification: Notification) {
		// Remember selection in preferences
		if let numberOfMonths = (notification as NSNotification).userInfo?["span"] as? Int {
			UserDefaults.standard.set(numberOfMonths, forKey: "statisticTimeSpan")

			// Update all statistics controllers
			for controller in self.childViewControllers {
				if let fuelStatisticsViewController = controller as? FuelStatisticsViewController {
					fuelStatisticsViewController.displayedNumberOfMonths = numberOfMonths
				}
			}
		}
	}

	// MARK: - Memory Management

	deinit {
		NotificationCenter.default.removeObserver(self)
	}
}

extension FuelStatisticsPageController: UIPageViewControllerDelegate {
	func pageViewControllerSupportedInterfaceOrientations(_ pageViewController: UIPageViewController) -> UIInterfaceOrientationMask {
		return .landscape
	}

	func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
		if completed {
			updatePageVisibility()
		}
	}
}

extension FuelStatisticsPageController: UIPageViewControllerDataSource {

	func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
		guard let statisticsViewController = viewController as? FuelStatisticsViewController else { return nil }
		let page = statisticsViewController.pageIndex
		if statisticsViewController.pageIndex < statisticsViewControllers.count - 1 {
			return statisticsViewControllers[page+1]
		} else {
			return statisticsViewControllers.first!
		}
	}

	func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
		guard let statisticsViewController = viewController as? FuelStatisticsViewController else { return nil }
		let page = statisticsViewController.pageIndex
		if page > 0 {
			return statisticsViewControllers[page-1]
		} else {
			return statisticsViewControllers.last!
		}
	}

	func presentationCount(for pageViewController: UIPageViewController) -> Int {
		return statisticsViewControllers.count
	}

	func presentationIndex(for pageViewController: UIPageViewController) -> Int {
		return currentPage
	}
}
