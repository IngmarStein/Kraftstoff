//
//  AppDelegate.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 05.05.15.
//
//

import UIKit
import CoreData
import CoreSpotlight
import MobileCoreServices
import StoreKit

extension UIApplication {
	static var kraftstoffAppDelegate: AppDelegate {
		return shared().delegate as! AppDelegate
	}
}

@UIApplicationMain
final class AppDelegate: NSObject, UIApplicationDelegate, NSFetchedResultsControllerDelegate, SKRequestDelegate {
	var window: UIWindow?
	private var appReceiptValid = false
	private var appReceipt : [String : AnyObject]?
	private var receiptRefreshRequest: SKReceiptRefreshRequest?

	private var importAlert: UIAlertController?

	private lazy var carsFetchedResultsController: NSFetchedResultsController = {
		let fetchedResultsController = CoreDataManager.fetchedResultsControllerForCars()
		fetchedResultsController.delegate = self
		return fetchedResultsController
	}()

	//MARK: - Application Lifecycle

	override init() {
		NSUserDefaults.standard().register(
		   ["statisticTimeSpan": 6,
			"preferredStatisticsPage": 1,
			"preferredCarID": "",
			"recentDistance": NSDecimalNumber.zero(),
			"recentPrice": NSDecimalNumber.zero(),
			"recentFuelVolume": NSDecimalNumber.zero(),
			"recentFilledUp": true,
			"recentComment": "",
			"editHelpCounter": 0,
			"firstStartup": true])

		super.init()
	}

	private var launchInitPred: dispatch_once_t = 0

	private func commonLaunchInitialization(_ launchOptions: [NSObject : AnyObject]?) {
		dispatch_once(&launchInitPred) {
			self.window?.makeKeyAndVisible()

			self.validateReceipt(NSBundle.main().appStoreReceiptURL) { (success) -> Void in
				self.appReceiptValid = success
				if !success {
					self.receiptRefreshRequest = SKReceiptRefreshRequest(receiptProperties: nil)
					self.receiptRefreshRequest?.delegate = self
					self.receiptRefreshRequest?.start()
				}
			}

			CoreDataManager.sharedInstance.registerForiCloudNotifications()
			CoreDataManager.migrateToiCloud()

			if NSProcessInfo.processInfo().arguments.index(of: "-STARTFRESH") != nil {
				CoreDataManager.deleteAllObjects()
				let userDefaults = NSUserDefaults.standard()
				for key in ["statisticTimeSpan",
					"preferredStatisticsPage",
					"preferredCarID",
					"recentDistance",
					"recentPrice",
					"recentFuelVolume",
					"recentFilledUp",
					"recentComment",
					"editHelpCounter",
					"firstStartup"] {
					userDefaults.removeObject(forKey: key)
				}
			}

			self.updateShortcutItems()

			// Switch once to the car view for new users
			if launchOptions?[UIApplicationLaunchOptionsURLKey] == nil {
				let defaults = NSUserDefaults.standard()

				if defaults.bool(forKey: "firstStartup") {
					if defaults.string(forKey: "preferredCarID") == "" {
						if let tabBarController = self.window?.rootViewController as? UITabBarController {
							tabBarController.selectedIndex = 1
						}
					}

					defaults.set(false, forKey:"firstStartup")
				}
			}
		}
	}

	private func updateShortcutItems() {
		if let cars = self.carsFetchedResultsController.fetchedObjects as? [Car] {
			UIApplication.shared().shortcutItems = cars.map { car in
				let userInfo = CoreDataManager.modelIdentifierForManagedObject(car).flatMap { ["objectId" : $0] }
				return UIApplicationShortcutItem(type: "fillup", localizedTitle: car.name, localizedSubtitle: car.numberPlate, icon: nil, userInfo: userInfo)
			}

			if CSSearchableIndex.isIndexingAvailable() {
				let searchableItems = cars.map { car -> CSSearchableItem in
					let carIdentifier = CoreDataManager.modelIdentifierForManagedObject(car)
					let attributeset = CSSearchableItemAttributeSet(itemContentType: kUTTypeText as String)
					attributeset.title = car.name
					attributeset.contentDescription = car.numberPlate
					return CSSearchableItem(uniqueIdentifier: carIdentifier, domainIdentifier: "com.github.m-schmidt.Kraftstoff.cars", attributeSet: attributeset)
				}
				CSSearchableIndex.default().indexSearchableItems(searchableItems, completionHandler: nil)
			}
		}
	}

	@objc(application:performActionForShortcutItem:completionHandler:) func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: (Bool) -> Void) {
		if shortcutItem.type == "fillup" {
			// switch to fill-up tab and select the car
			if let tabBarController = self.window?.rootViewController as? UITabBarController {
				tabBarController.selectedIndex = 0
				if let navigationController = tabBarController.selectedViewController as? UINavigationController {
					navigationController.popToRootViewController(animated: false)
					if let fuelCalculatorController = navigationController.viewControllers.first as? FuelCalculatorController {
						fuelCalculatorController.selectedCarId = shortcutItem.userInfo?["objectId"] as? String
						fuelCalculatorController.recreateTableContentsWithAnimation(.none)
					}
				}
			}
		}
	}

	@objc(application:continueUserActivity:restorationHandler:) func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: ([AnyObject]?) -> Void) -> Bool {
		if userActivity.activityType == "com.github.m-schmidt.Kraftstoff.fillup" {
			// switch to fill-up tab
			if let tabBarController = self.window?.rootViewController as? UITabBarController {
				tabBarController.selectedIndex = 0
			}

			return true
		} else {
			if userActivity.activityType == CSSearchableItemActionType {
				// switch to cars tab and show the fuel history
				if let tabBarController = self.window?.rootViewController as? UITabBarController {
					tabBarController.selectedIndex = 1
					if let carIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String where CoreDataManager.managedObjectForModelIdentifier(carIdentifier) as? Car != nil {
						let fuelEventController = tabBarController.storyboard!.instantiateViewController(withIdentifier: "FuelEventController") as! FuelEventController
						fuelEventController.selectedCarId = carIdentifier
						if let navigationController = tabBarController.selectedViewController as? UINavigationController {
							navigationController.popToRootViewController(animated: false)
							navigationController.pushViewController(fuelEventController, animated: false)
						}
					}
				}
				return true
			}
		}

		return false
	}

	@objc(application:willFinishLaunchingWithOptions:) func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
		commonLaunchInitialization(launchOptions)
		return true
	}

	@objc(application:didFinishLaunchingWithOptions:) func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
		commonLaunchInitialization(launchOptions)
		return true
	}

	@objc(applicationDidEnterBackground:) func applicationDidEnterBackground(_ application: UIApplication) {
		CoreDataManager.saveContext()
	}

	@objc(applicationWillTerminate:) func applicationWillTerminate(_ application: UIApplication) {
		CoreDataManager.saveContext()
	}

	//MARK: - State Restoration

	@objc(application:shouldSaveApplicationState:) func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
		return true
	}

	@objc(application:shouldRestoreApplicationState:) func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
		let bundleVersion = NSBundle.main().infoDictionary?[kCFBundleVersionKey as String] as? Int ?? 0
		let stateVersion = Int(coder.decodeObjectOfClass(NSString.self, forKey:UIApplicationStateRestorationBundleVersionKey) as? String ?? "") ?? 0

		// we don't restore from iOS6 compatible or future versions of the App
		return stateVersion >= 1572 && stateVersion <= bundleVersion
	}

	//MARK: - Data Import

	private func showImportAlert() {
		if self.importAlert == nil {
			self.importAlert = UIAlertController(title:NSLocalizedString("Importing", comment:"") + "\n\n", message:"", preferredStyle:.alert)

			let progress = UIActivityIndicatorView(frame:self.importAlert!.view.bounds)
			progress.autoresizingMask = [.flexibleWidth, .flexibleHeight]
			progress.isUserInteractionEnabled = false
			progress.activityIndicatorViewStyle = .whiteLarge
			progress.color = UIColor.black()
			let center = self.importAlert!.view.center
			progress.center = CGPoint(x: center.x, y: center.y + 30.0)
			progress.startAnimating()

			self.importAlert!.view.addSubview(progress)

			self.window?.rootViewController?.present(self.importAlert!, animated:true, completion:nil)
		}
	}

	private func hideImportAlert() {
		self.window?.rootViewController?.dismiss(animated: true, completion:nil)
		self.importAlert = nil
	}

	// Read file contents from given URL, guess file encoding
	private static func contentsOfURL(_ url: NSURL) -> String? {
		var enc: NSStringEncoding = NSUTF8StringEncoding
		if let contents = try? String(contentsOf: url, usedEncoding: &enc) { return contents }
		if let contents = try? String(contentsOf: url, encoding: NSMacOSRomanStringEncoding) { return contents }
		return nil
	}

	// Removes files from the inbox
	private func removeFileItem(at url: NSURL) {
		if url.isFileURL {
			do {
				try NSFileManager.default().removeItem(at: url)
			} catch let error as NSError {
				NSLog("%@", error.localizedDescription)
			}
		}
	}

	@objc(application:openURL:sourceApplication:annotation:) func application(_ application: UIApplication, open url: NSURL, sourceApplication: String?, annotation: AnyObject) -> Bool {
		// Ugly, but don't allow nested imports
		if self.importAlert != nil {
			removeFileItem(at: url)
			return false
		}

		if !StoreManager.sharedInstance.checkCarCount() {
			StoreManager.sharedInstance.showBuyOptions(parent: self.window!.rootViewController!)
			return false
		}

		// Show modal activity indicator while importing
		showImportAlert()

		// Import in context with private queue
		let parentContext = CoreDataManager.managedObjectContext
		let importContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
		importContext.parent = parentContext

		importContext.perform {
			// Read file contents from given URL, guess file encoding
			let CSVString = AppDelegate.contentsOfURL(url)
			self.removeFileItem(at: url)

			if let CSVString = CSVString {
				// Try to import data from CSV file
				let importer = CSVImporter()

				var numCars   = 0
				var numEvents = 0

				let success = importer.`import`(csv: CSVString,
                                            detectedCars:&numCars,
                                          detectedEvents:&numEvents,
                                               sourceURL:url,
                                              inContext:importContext)

				// On success propagate changes to parent context
				if success {
					CoreDataManager.saveContext(importContext)
					parentContext.perform { CoreDataManager.saveContext(parentContext) }
				}

				dispatch_async(dispatch_get_main_queue()) {
					self.hideImportAlert()

					let title = success ? NSLocalizedString("Import Finished", comment:"") : NSLocalizedString("Import Failed", comment:"")

					let message = success
						? String.localizedStringWithFormat(NSLocalizedString("Imported %d car(s) with %d fuel event(s).", comment:""), numCars, numEvents)
						: NSLocalizedString("No valid CSV-data could be found.", comment:"")

					let alertController = UIAlertController(title:title, message:message, preferredStyle: .alert)
					let defaultAction = UIAlertAction(title:NSLocalizedString("OK", comment:""), style:.`default`) { _ in () }
					alertController.addAction(defaultAction)
					self.window?.rootViewController?.present(alertController, animated: true, completion: nil)
				}
			} else {
				dispatch_async(dispatch_get_main_queue()) {
					self.hideImportAlert()

					let alertController = UIAlertController(title:NSLocalizedString("Import Failed", comment:""),
						message:NSLocalizedString("Can't detect file encoding. Please try to convert your CSV-file to UTF8 encoding.", comment:""),
						preferredStyle: .alert)
					let defaultAction = UIAlertAction(title:NSLocalizedString("OK", comment:""), style: .`default`, handler: nil)
					alertController.addAction(defaultAction)
					self.window?.rootViewController?.present(alertController, animated:true, completion:nil)
				}
			}
		}

		// Treat imports as successful first startups
		NSUserDefaults.standard().set(false, forKey:"firstStartup")
		return true
	}

	//MARK: - NSFetchedResultsControllerDelegate

	@objc(controllerDidChangeContent:) func controllerDidChangeContent(_ controller: NSFetchedResultsController) {
		updateShortcutItems()
	}

	//MARK: - SKRequestDelegate

	@objc(requestDidFinish:) func requestDidFinish(_ request: SKRequest) {
		validateReceipt(NSBundle.main().appStoreReceiptURL) { (success) -> Void in
			self.appReceiptValid = success
		}
	}

	@objc(request:didFailWithError:) func request(_ request: SKRequest, didFailWithError error: NSError) {
		print("receipt request failed: \(error)")
	}

	// MARK: - Receipt validation

	private func receiptData(_ appStoreReceiptURL : NSURL?) -> NSData? {
		guard let receiptURL = appStoreReceiptURL, receipt = NSData(contentsOf: receiptURL) else { return nil }

		do {
			let receiptData = receipt.base64EncodedString(NSDataBase64EncodingOptions(rawValue: 0))
			let requestContents = ["receipt-data" : receiptData]
			let requestData = try NSJSONSerialization.data(withJSONObject: requestContents, options: [])
			return requestData
		} catch let error as NSError {
			print(error)
		}

		return nil
	}

	private func validateReceiptInternal(_ appStoreReceiptURL : NSURL?, isProd: Bool , onCompletion: (Int?, AnyObject?) -> Void) {
		let serverURL = isProd ? "https://buy.itunes.apple.com/verifyReceipt" : "https://sandbox.itunes.apple.com/verifyReceipt"

		guard let receiptData = receiptData(appStoreReceiptURL), url = NSURL(string: serverURL) else {
			onCompletion(nil, nil)
			return
		}

		let request = NSMutableURLRequest(url: url)
		request.httpMethod = "POST"
		request.httpBody = receiptData

		let task = NSURLSession.shared().dataTask(with: request, completionHandler: {data, response, error -> Void in

			guard let data = data where error == nil else {
				onCompletion(nil, nil)
				return
			}

			do {
				let json = try NSJSONSerialization.jsonObject(with: data, options:[])
				//print(json)
				guard let statusCode = json["status"] as? Int else {
					onCompletion(nil, json)
					return
				}
				onCompletion(statusCode, json)
			} catch let error as NSError {
				print(error)
				onCompletion(nil, nil)
			}
		})
		task.resume()
	}

	private func validateReceipt(_ appStoreReceiptURL : NSURL?, onCompletion: (Bool) -> Void) {
		validateReceiptInternal(appStoreReceiptURL, isProd: true) { (statusCode: Int?, json: AnyObject?) -> Void in
			guard let status = statusCode else {
				onCompletion(false)
				return
			}

			// This receipt is from the test environment, but it was sent to the production environment for verification.
			if status == 21007 {
				self.validateReceiptInternal(appStoreReceiptURL, isProd: false) { (statusCode: Int?, json: AnyObject?) -> Void in
					guard let statusValue = statusCode else {
						onCompletion(false)
						return
					}

					// 0 if the receipt is valid
					if let receipt = json?["receipt"] as? [String:AnyObject], bundleId = receipt["bundle_id"] as? String where statusValue == 0 && bundleId == "com.github.m-schmidt.kraftstoff" {
						self.appReceipt = receipt
						onCompletion(true)
					} else {
						onCompletion(false)
					}
				}

				// 0 if the receipt is valid
			} else if let receipt = json?["receipt"] as? [String:AnyObject], bundleId = receipt["bundle_id"] as? String where status == 0 && bundleId == "com.github.m-schmidt.kraftstoff" {
				self.appReceipt = receipt
				onCompletion(true)
			} else {
				onCompletion(false)
			}
		}
	}

	func validReceiptForInAppPurchase(_ productId: String) -> Bool {
		guard let receipt = appReceipt, inApps = receipt["in_app"] as? [[String:AnyObject]] where appReceiptValid else { return false }
		for inApp in inApps {
			if let id = inApp["product_id"] as? String {
				if id == productId {
					return true
				}
			}
		}
		return false
	}

	//MARK: - Shared Color Gradients

	static let blueGradient: CGGradient = {
		let colorComponentsFlat: [CGFloat] = [ 0.360, 0.682, 0.870, 0.0,  0.466, 0.721, 0.870, 0.9 ]

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let blueGradient = CGGradient(withColorComponentsSpace: colorSpace, components: colorComponentsFlat, locations: nil, count: 2)!

		return blueGradient
	}()

	static let greenGradient: CGGradient = {
		let colorComponentsFlat: [CGFloat] = [ 0.662, 0.815, 0.502, 0.0,  0.662, 0.815, 0.502, 0.9 ]

        let colorSpace = CGColorSpaceCreateDeviceRGB()
		let greenGradient = CGGradient(withColorComponentsSpace: colorSpace, components: colorComponentsFlat, locations: nil, count: 2)!

		return greenGradient
    }()

	static let orangeGradient: CGGradient = {
		let colorComponentsFlat: [CGFloat] = [ 0.988, 0.662, 0.333, 0.0,  0.988, 0.662, 0.333, 0.9 ]

        let colorSpace = CGColorSpaceCreateDeviceRGB()
		let orangeGradient = CGGradient(withColorComponentsSpace: colorSpace, components: colorComponentsFlat, locations: nil, count: 2)!

		return orangeGradient
    }()
}
