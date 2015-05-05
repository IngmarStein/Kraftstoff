//
//  FuelStatisticsPageController.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 05.05.15.
//
//

import UIKit

class FuelStatisticsPageController: UIViewController, UIScrollViewDelegate {

	// Set by presenting view controller
	var selectedCar: Car!

	@IBOutlet private weak var scrollView: FuelStatisticsScrollView!
	@IBOutlet private weak var pageControl: UIPageControl!

	private var pageControlUsed = false

	//MARK: - View Lifecycle

	required init(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)

		self.modalTransitionStyle = .CrossDissolve
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()

		for var page = 0; page < pageControl.numberOfPages; page++ {
			let controller = self.childViewControllers[page] as! UIViewController
			controller.view.frame = frameForPage(page)
		}

		scrollView.contentSize = CGSize(width:scrollView.frame.size.width * CGFloat(pageControl.numberOfPages), height: scrollView.frame.size.height)
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		// Load content pages
		for var page = 0; page < pageControl.numberOfPages; page++ {
			let controller: FuelStatisticsViewController?

			switch page {
			case 0:
				let graphViewController = self.storyboard!.instantiateViewControllerWithIdentifier("FuelStatisticsGraphViewController") as! FuelStatisticsGraphViewController
				graphViewController.delegate = FuelStatisticsViewControllerDelegatePriceDistance()
				controller = graphViewController
			case 1:
				let graphViewController = self.storyboard!.instantiateViewControllerWithIdentifier("FuelStatisticsGraphViewController") as! FuelStatisticsGraphViewController
				graphViewController.delegate = FuelStatisticsViewControllerDelegateAvgConsumption()
				controller = graphViewController
			case 2:
				let graphViewController = self.storyboard!.instantiateViewControllerWithIdentifier("FuelStatisticsGraphViewController") as! FuelStatisticsGraphViewController
				graphViewController.delegate = FuelStatisticsViewControllerDelegatePriceAmount()
				controller = graphViewController
			case 3:
				controller = self.storyboard!.instantiateViewControllerWithIdentifier("FuelStatisticsTextViewController") as! FuelStatisticsTextViewController
			default:
				controller = nil
			}

			if let controller = controller {
				controller.selectedCar = self.selectedCar
				addChildViewController(controller)
				scrollView.addSubview(controller.view)
			}
		}

		// Configure scroll view
		scrollView.scrollsToTop = false

		// Hide pageControl
		//pageControl.hidden = true

		// Select preferred page
		dispatch_async (dispatch_get_main_queue()) {
			self.pageControl.currentPage = NSUserDefaults.standardUserDefaults().integerForKey("preferredStatisticsPage")
			self.scrollToPage(self.pageControl.currentPage, animated:false)

			self.pageControlUsed = false
		}
    
		NSNotificationCenter.defaultCenter().addObserver(self,
           selector:"localeChanged:",
               name:NSCurrentLocaleDidChangeNotification,
             object:nil)

		NSNotificationCenter.defaultCenter().addObserver(self,
           selector:"didEnterBackground:",
               name:UIApplicationDidEnterBackgroundNotification,
             object:nil)

		NSNotificationCenter.defaultCenter().addObserver(self,
           selector:"didBecomeActive:",
               name:UIApplicationDidBecomeActiveNotification,
             object:nil)

		NSNotificationCenter.defaultCenter().addObserver(self,
           selector:"numberOfMonthsSelected:",
               name:"numberOfMonthsSelected",
             object:nil)
	}

	override func preferredStatusBarStyle() -> UIStatusBarStyle {
		return .LightContent
	}

	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)

		NSUserDefaults.standardUserDefaults().setInteger(pageControl.currentPage, forKey:"preferredStatisticsPage")
		NSUserDefaults.standardUserDefaults().synchronize()
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
		for controller in self.childViewControllers as! [FuelStatisticsViewController] {
			controller.invalidateCaches()
		}
	}

	//MARK: - System Events

	func localeChanged(object: AnyObject) {
		invalidateCaches()
	}

	func didEnterBackground(object: AnyObject) {
		NSUserDefaults.standardUserDefaults().setInteger(pageControl.currentPage, forKey:"preferredStatisticsPage")
		NSUserDefaults.standardUserDefaults().synchronize()

		for controller in self.childViewControllers as! [FuelStatisticsViewController] {
			controller.purgeDiscardableCacheContent()
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
				controller.setDisplayedNumberOfMonths(numberOfMonths)
			}
		}
	}

	//MARK: - Frame Computation for Pages

	func frameForPage(page: Int) -> CGRect {
		let visiblePage = scrollView.visiblePageForPage(page)

		var frame = scrollView.frame
		frame.origin.x = frame.size.width * CGFloat(visiblePage)
		frame.origin.y = 0

		return frame
	}

	//MARK: - Sync ScrollView with Page Indicator

	func scrollViewDidScroll(scrollView: UIScrollView) {
		if !pageControlUsed {
			let newPage = self.scrollView.pageForVisiblePage(Int(floor((scrollView.contentOffset.x - scrollView.frame.size.width*0.5) / scrollView.frame.size.width) + 1))
			if pageControl.currentPage != newPage {
				pageControl.currentPage = newPage
				updatePageVisibility()
			}
		}
	}

	func scrollViewWillBeginDragging(scrollView: UIScrollView) {
		pageControlUsed = false
	}

	func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
		pageControlUsed = false
	}

	//MARK: - Page Control Handling

	private func updatePageVisibility() {
		for var page = 0; page < pageControl.numberOfPages; page++ {
			let controller = self.childViewControllers[page] as! FuelStatisticsViewController
			controller.noteStatisticsPageBecomesVisible(page == pageControl.currentPage)
		}
	}

	private func scrollToPage(page: Int, animated: Bool) {
		pageControlUsed = true

		scrollView.scrollRectToVisible(frameForPage(page), animated:animated)
		updatePageVisibility()
	}

	@IBAction func pageAction(sender: AnyObject) {
		scrollToPage(pageControl.currentPage, animated:true)
	}

	//MARK: - Memory Management

	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}
}
