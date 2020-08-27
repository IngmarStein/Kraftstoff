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
  let priceDistanceDataSource = FuelStatisticsViewControllerDataSourcePriceDistance()
  let avgConsumptionDataSource = FuelStatisticsViewControllerDataSourceAvgConsumption()
  let priceAmountDataSource = FuelStatisticsViewControllerDataSourcePriceAmount()

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
    priceDistanceViewController.dataSource = priceDistanceDataSource
    priceDistanceViewController.selectedCar = self.selectedCar
    priceDistanceViewController.pageIndex = 0

    // swiftlint:disable:next force_cast
    let avgConsumptionViewController = self.storyboard!.instantiateViewController(withIdentifier: "FuelStatisticsGraphViewController") as! FuelStatisticsGraphViewController
    avgConsumptionViewController.dataSource = avgConsumptionDataSource
    avgConsumptionViewController.selectedCar = self.selectedCar
    avgConsumptionViewController.pageIndex = 1

    // swiftlint:disable:next force_cast
    let priceAmountViewController = self.storyboard!.instantiateViewController(withIdentifier: "FuelStatisticsGraphViewController") as! FuelStatisticsGraphViewController
    priceAmountViewController.dataSource = priceAmountDataSource
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
               name: NSLocale.currentLocaleDidChangeNotification,
             object: nil)

    NotificationCenter.default.addObserver(self,
           selector: #selector(FuelStatisticsPageController.didEnterBackground(_:)),
               name: UIApplication.didEnterBackgroundNotification,
             object: nil)

    NotificationCenter.default.addObserver(self,
           selector: #selector(FuelStatisticsPageController.didBecomeActive(_:)),
               name: UIApplication.didBecomeActiveNotification,
             object: nil)

    NotificationCenter.default.addObserver(self,
           selector: #selector(FuelStatisticsPageController.numberOfMonthsSelected(_:)),
       name: NSNotification.Name(rawValue: "numberOfMonthsSelected"),
             object: nil)
  }

  var currentPage: Int {
    guard let statisticsViewController = viewControllers?.first as? FuelStatisticsViewController else { return -1 }
    return statisticsViewController.pageIndex
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    UserDefaults.standard.set(currentPage, forKey: "preferredStatisticsPage")
    UserDefaults.standard.synchronize()
  }

  // MARK: - View Rotation

  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    return .landscape
  }

  override var prefersStatusBarHidden: Bool {
    return true
  }

  // MARK: - Cache Handling

  func invalidateCaches() {
    for controller in self.children {
      if let fuelStatisticsViewController = controller as? FuelStatisticsViewController {
        fuelStatisticsViewController.invalidateCaches()
      }
    }
  }

  // MARK: - System Events

  @objc func localeChanged(_ object: AnyObject) {
    invalidateCaches()
  }

  @objc func didEnterBackground(_ object: AnyObject) {
    UserDefaults.standard.set(currentPage, forKey: "preferredStatisticsPage")
    UserDefaults.standard.synchronize()

    for controller in statisticsViewControllers {
      controller.purgeDiscardableCacheContent()
    }
  }

  fileprivate func updatePageVisibility() {
    for controller in statisticsViewControllers {
      if viewControllers!.contains(controller) {
        controller.noteStatisticsPageBecomesVisible()
      }
    }
  }

  @objc func didBecomeActive(_ object: AnyObject) {
    updatePageVisibility()
  }

  // MARK: - User Events

  @objc func numberOfMonthsSelected(_ notification: Notification) {
    // Remember selection in preferences
    if let numberOfMonths = (notification as NSNotification).userInfo?["span"] as? Int {
      UserDefaults.standard.set(numberOfMonths, forKey: "statisticTimeSpan")

      // Update all statistics controllers
      for controller in self.children {
        if let fuelStatisticsViewController = controller as? FuelStatisticsViewController {
          fuelStatisticsViewController.displayedNumberOfMonths = numberOfMonths
        }
      }
    }
  }

}

extension FuelStatisticsPageController: UIPageViewControllerDelegate {

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
