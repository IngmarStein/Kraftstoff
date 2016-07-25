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
import CloudKit

extension UIApplication {
	static var kraftstoffAppDelegate: AppDelegate {
		// swiftlint:disable:next force_cast
		return shared().delegate as! AppDelegate
	}
}

@UIApplicationMain
final class AppDelegate: NSObject, UIApplicationDelegate, NSFetchedResultsControllerDelegate, SKRequestDelegate {
	private var initialized = false
	var window: UIWindow?
	private var appReceiptValid = false
	private var appReceipt: [String: AnyObject]?
	private var receiptRefreshRequest: SKReceiptRefreshRequest?

	private var importAlert: UIAlertController?

	private lazy var carsFetchedResultsController: NSFetchedResultsController<Car> = {
		let fetchedResultsController = CoreDataManager.fetchedResultsControllerForCars()
		fetchedResultsController.delegate = self
		return fetchedResultsController
	}()

	// MARK: - Application Lifecycle

	override init() {
		UserDefaults.standard.register(
		   ["statisticTimeSpan": 6,
			"preferredStatisticsPage": 1,
			"preferredCarID": "",
			"recentDistance": NSDecimalNumber.zero,
			"recentPrice": NSDecimalNumber.zero,
			"recentFuelVolume": NSDecimalNumber.zero,
			"recentFilledUp": true,
			"recentComment": "",
			"editHelpCounter": 0,
			"firstStartup": true])

		super.init()
	}

	private func commonLaunchInitialization(_ launchOptions: [NSObject: AnyObject]?) {
		if !initialized {
			initialized = true

			self.window?.makeKeyAndVisible()

			self.validateReceipt(Bundle.main.appStoreReceiptURL) { success in
				self.appReceiptValid = success
				if !success {
					self.receiptRefreshRequest = SKReceiptRefreshRequest(receiptProperties: nil)
					self.receiptRefreshRequest?.delegate = self
					self.receiptRefreshRequest?.start()
				}
			}

			CoreDataManager.migrateFromiCloud()
			CoreDataManager.load()

			CloudKitManager.initialize()

			UIApplication.shared().registerForRemoteNotifications()

			if ProcessInfo.processInfo.arguments.index(of: "-STARTFRESH") != nil {
				CoreDataManager.deleteAllObjects()
				let userDefaults = UserDefaults.standard
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

			updateShortcutItems()

			// Switch once to the car view for new users
			if launchOptions?[UIApplicationLaunchOptionsURLKey] == nil {
				let defaults = UserDefaults.standard

				if defaults.bool(forKey: "firstStartup") {
					if defaults.string(forKey: "preferredCarID") == "" {
						if let tabBarController = self.window?.rootViewController as? UITabBarController {
							tabBarController.selectedIndex = 1
						}
					}

					defaults.set(false, forKey: "firstStartup")
				}
			}
		}
	}

	private func updateShortcutItems() {
		if let cars = self.carsFetchedResultsController.fetchedObjects {
			UIApplication.shared().shortcutItems = cars.map { car in
				let userInfo = CoreDataManager.modelIdentifierForManagedObject(car).flatMap { ["objectId": $0] }
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

	func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: (Bool) -> Void) {
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

	func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: ([AnyObject]?) -> Void) -> Bool {
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
					if let carIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String, CoreDataManager.managedObjectForModelIdentifier(carIdentifier) as? Car != nil {
						if let fuelEventController = tabBarController.storyboard!.instantiateViewController(withIdentifier: "FuelEventController") as? FuelEventController {
							fuelEventController.selectedCarId = carIdentifier
							if let navigationController = tabBarController.selectedViewController as? UINavigationController {
								navigationController.popToRootViewController(animated: false)
								navigationController.pushViewController(fuelEventController, animated: false)
							}
						}
					}
				}
				return true
			}
		}

		return false
	}

	func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
		commonLaunchInitialization(launchOptions)
		return true
	}

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
		commonLaunchInitialization(launchOptions)
		return true
	}

	func applicationDidEnterBackground(_ application: UIApplication) {
		CoreDataManager.saveContext()
	}

	func applicationWillTerminate(_ application: UIApplication) {
		CoreDataManager.saveContext()
	}

	// MARK: - Notifications

	func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject: AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
		CloudKitManager.handlePush(userInfo, completionHandler: completionHandler)
	}

	// MARK: - State Restoration

	func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
		return true
	}

	func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
		let bundleVersion = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as? Int ?? 0
		let stateVersion = Int(coder.decodeObjectOfClass(NSString.self, forKey: UIApplicationStateRestorationBundleVersionKey) as? String ?? "") ?? 0

		// we don't restore from iOS6 compatible or future versions of the App
		return stateVersion >= 1572 && stateVersion <= bundleVersion
	}

	// MARK: - Data Import

	private func showImportAlert() {
		if self.importAlert == nil {
			self.importAlert = UIAlertController(title: NSLocalizedString("Importing", comment: "") + "\n\n", message: "", preferredStyle: .alert)

			let progress = UIActivityIndicatorView(frame: self.importAlert!.view.bounds)
			progress.autoresizingMask = [.flexibleWidth, .flexibleHeight]
			progress.isUserInteractionEnabled = false
			progress.activityIndicatorViewStyle = .whiteLarge
			progress.color = .black()
			let center = self.importAlert!.view.center
			progress.center = CGPoint(x: center.x, y: center.y + 30.0)
			progress.startAnimating()

			self.importAlert!.view.addSubview(progress)

			self.window?.rootViewController?.present(self.importAlert!, animated: true, completion: nil)
		}
	}

	private func hideImportAlert() {
		self.window?.rootViewController?.dismiss(animated: true, completion: nil)
		self.importAlert = nil
	}

	// Read file contents from given URL, guess file encoding
	private static func contentsOfURL(_ url: URL) -> String? {
		var enc: String.Encoding = String.Encoding.utf8
		if let contents = try? String(contentsOf: url as URL, usedEncoding: &enc) { return contents }
		if let contents = try? String(contentsOf: url as URL, encoding: String.Encoding.macOSRoman) { return contents }
		return nil
	}

	// Removes files from the inbox
	private func removeFileItem(at url: URL) {
		if url.isFileURL {
			do {
				try FileManager.default.removeItem(at: url as URL)
			} catch let error as NSError {
				print(error.localizedDescription)
			}
		}
	}

	func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: AnyObject) -> Bool {
		// Ugly, but don't allow nested imports
		if self.importAlert != nil {
			removeFileItem(at: url)
			return false
		}

		if !StoreManager.sharedInstance.checkCarCount() {
			StoreManager.sharedInstance.showBuyOptions(self.window!.rootViewController!)
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

				let success = importer.`import`(CSVString,
                                            detectedCars: &numCars,
                                          detectedEvents: &numEvents,
                                               sourceURL: url,
                                               inContext: importContext)

				// On success propagate changes to parent context
				if success {
					CoreDataManager.saveContext(importContext)
					parentContext.perform { CoreDataManager.saveContext(parentContext) }
				}

				DispatchQueue.main.async {
					self.hideImportAlert()

					let title = success ? NSLocalizedString("Import Finished", comment: "") : NSLocalizedString("Import Failed", comment: "")

					let message = success
						? String.localizedStringWithFormat(NSLocalizedString("Imported %d car(s) with %d fuel event(s).", comment: ""), numCars, numEvents)
						: NSLocalizedString("No valid CSV-data could be found.", comment: "")

					let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
					let defaultAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in () }
					alertController.addAction(defaultAction)
					self.window?.rootViewController?.present(alertController, animated: true, completion: nil)
				}
			} else {
				DispatchQueue.main.async {
					self.hideImportAlert()

					let alertController = UIAlertController(title: NSLocalizedString("Import Failed", comment: ""),
						message: NSLocalizedString("Can't detect file encoding. Please try to convert your CSV-file to UTF8 encoding.", comment: ""),
						preferredStyle: .alert)
					let defaultAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: nil)
					alertController.addAction(defaultAction)
					self.window?.rootViewController?.present(alertController, animated: true, completion: nil)
				}
			}
		}

		// Treat imports as successful first startups
		UserDefaults.standard.set(false, forKey: "firstStartup")
		return true
	}

	// MARK: - NSFetchedResultsControllerDelegate

	func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		updateShortcutItems()
	}

	// MARK: - SKRequestDelegate

	func requestDidFinish(_ request: SKRequest) {
		validateReceipt(Bundle.main.appStoreReceiptURL) { success in
			self.appReceiptValid = success
		}
	}

	func request(_ request: SKRequest, didFailWithError error: NSError) {
		print("receipt request failed: \(error)")
	}

	// MARK: - Receipt validation

	private func receiptData(_ appStoreReceiptURL: URL?) -> Data? {
		guard let receiptURL = appStoreReceiptURL, let receipt = try? Data(contentsOf: receiptURL as URL) else { return nil }

		do {
			let receiptData = receipt.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0))
			let requestContents = ["receipt-data": receiptData]
			let requestData = try JSONSerialization.data(withJSONObject: requestContents as AnyObject, options: [])
			return requestData
		} catch let error as NSError {
			print(error)
		}

		return nil
	}

	private func validateReceiptInternal(_ appStoreReceiptURL: URL?, isProd: Bool, onCompletion: (Int?, AnyObject?) -> Void) {
		let serverURL = isProd ? "https://buy.itunes.apple.com/verifyReceipt" : "https://sandbox.itunes.apple.com/verifyReceipt"

		guard let receiptData = receiptData(appStoreReceiptURL), let url = URL(string: serverURL) else {
			onCompletion(nil, nil)
			return
		}

		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.httpBody = receiptData

		let task = URLSession.shared.dataTask(with: request, completionHandler: {data, response, error -> Void in

			guard let data = data, error == nil else {
				onCompletion(nil, nil)
				return
			}

			do {
				let json = try JSONSerialization.jsonObject(with: data, options: [])
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

	private func validateReceipt(_ appStoreReceiptURL: URL?, onCompletion: (Bool) -> Void) {
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
					if let receipt = json?["receipt"] as? [String: AnyObject], let bundleId = receipt["bundle_id"] as? String, statusValue == 0 && bundleId == "com.github.m-schmidt.kraftstoff" {
						self.appReceipt = receipt
						onCompletion(true)
					} else {
						onCompletion(false)
					}
				}

				// 0 if the receipt is valid
			} else if let receipt = json?["receipt"] as? [String: AnyObject], let bundleId = receipt["bundle_id"] as? String, status == 0 && bundleId == "com.github.m-schmidt.kraftstoff" {
				self.appReceipt = receipt
				onCompletion(true)
			} else {
				onCompletion(false)
			}
		}
	}

	func validReceiptForInAppPurchase(_ productId: String) -> Bool {
		guard let receipt = appReceipt, let inApps = receipt["in_app"] as? [[String: AnyObject]], appReceiptValid else { return false }
		for inApp in inApps {
			if let id = inApp["product_id"] as? String {
				if id == productId {
					return true
				}
			}
		}
		return false
	}

	// MARK: - Shared Color Gradients

	static let blueGradient: CGGradient = {
		let colorComponentsFlat: [CGFloat] = [ 0.360, 0.682, 0.870, 0.0, 0.466, 0.721, 0.870, 0.9 ]

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let blueGradient = CGGradient(colorComponentsSpace: colorSpace, components: colorComponentsFlat, locations: nil, count: 2)!

		return blueGradient
	}()

	static let greenGradient: CGGradient = {
		let colorComponentsFlat: [CGFloat] = [ 0.662, 0.815, 0.502, 0.0, 0.662, 0.815, 0.502, 0.9 ]

        let colorSpace = CGColorSpaceCreateDeviceRGB()
		let greenGradient = CGGradient(colorComponentsSpace: colorSpace, components: colorComponentsFlat, locations: nil, count: 2)!

		return greenGradient
    }()

	static let orangeGradient: CGGradient = {
		let colorComponentsFlat: [CGFloat] = [ 0.988, 0.662, 0.333, 0.0, 0.988, 0.662, 0.333, 0.9 ]

        let colorSpace = CGColorSpaceCreateDeviceRGB()
		let orangeGradient = CGGradient(colorComponentsSpace: colorSpace, components: colorComponentsFlat, locations: nil, count: 2)!

		return orangeGradient
    }()
}
