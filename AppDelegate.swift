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

extension UIApplication {
	static var kraftstoffAppDelegate: AppDelegate {
		return sharedApplication().delegate as! AppDelegate
	}
}

@UIApplicationMain
final class AppDelegate: NSObject, UIApplicationDelegate, NSFetchedResultsControllerDelegate {
	var window: UIWindow?

	private var importAlert: UIAlertController?

	private lazy var carsFetchedResultsController: NSFetchedResultsController = {
		let fetchedResultsController = CoreDataManager.fetchedResultsControllerForCars()
		fetchedResultsController.delegate = self
		return fetchedResultsController
	}()

	//MARK: - Application Lifecycle

	override init() {
		NSUserDefaults.standardUserDefaults().registerDefaults(
		   ["statisticTimeSpan": 6,
			"preferredStatisticsPage": 1,
			"preferredCarID": "",
			"recentDistance": NSDecimalNumber.zero(),
			"recentPrice": NSDecimalNumber.zero(),
			"recentFuelVolume": NSDecimalNumber.zero(),
			"recentFilledUp": true,
			"editHelpCounter": 0,
			"firstStartup": true])

		super.init()
	}

	private var launchInitPred: dispatch_once_t = 0

	private func commonLaunchInitialization(launchOptions: [NSObject : AnyObject]?) {
		dispatch_once(&launchInitPred) {
			self.window?.makeKeyAndVisible()

			CoreDataManager.sharedInstance.registerForiCloudNotifications()
			CoreDataManager.migrateToiCloud()

			self.updateShortcutItems()

			// Switch once to the car view for new users
			if launchOptions?[UIApplicationLaunchOptionsURLKey] == nil {
				let defaults = NSUserDefaults.standardUserDefaults()

				if defaults.boolForKey("firstStartup") {
					if defaults.stringForKey("preferredCarID") == "" {
						if let tabBarController = self.window?.rootViewController as? UITabBarController {
							tabBarController.selectedIndex = 1
						}
					}

					defaults.setObject(false, forKey:"firstStartup")
				}
			}
		}
	}

	private func updateShortcutItems() {
		if #available(iOS 9.0, *) {
			if let cars = self.carsFetchedResultsController.fetchedObjects as? [Car] {
				UIApplication.sharedApplication().shortcutItems = cars.map { car in
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
					CSSearchableIndex.defaultSearchableIndex().indexSearchableItems(searchableItems, completionHandler: nil)
				}
			}
		}
	}

	@available(iOS 9.0, *)
	func application(application: UIApplication, performActionForShortcutItem shortcutItem: UIApplicationShortcutItem, completionHandler: (Bool) -> Void) {
		if shortcutItem.type == "fillup" {
			// switch to fill-up tab and select the car
			if let tabBarController = self.window?.rootViewController as? UITabBarController {
				tabBarController.selectedIndex = 0
				if let navigationController = tabBarController.selectedViewController as? UINavigationController {
					navigationController.popToRootViewControllerAnimated(false)
					if let fuelCalculatorController = navigationController.viewControllers.first as? FuelCalculatorController {
						fuelCalculatorController.selectedCarId = shortcutItem.userInfo?["objectId"] as? String
					}
				}
			}
		}
	}

	func application(application: UIApplication, continueUserActivity userActivity: NSUserActivity, restorationHandler: ([AnyObject]?) -> Void) -> Bool {
		if userActivity.activityType == "com.github.m-schmidt.Kraftstoff.fillup" {
			// switch to fill-up tab
			if let tabBarController = self.window?.rootViewController as? UITabBarController {
				tabBarController.selectedIndex = 0
			}

			return true
		} else if #available(iOS 9.0, *) {
			if userActivity.activityType == CSSearchableItemActionType {
				// switch to cars tab and show the fuel history
				if let tabBarController = self.window?.rootViewController as? UITabBarController {
					tabBarController.selectedIndex = 1
					if let carIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String where CoreDataManager.managedObjectForModelIdentifier(carIdentifier) as? Car != nil {
						let fuelEventController = tabBarController.storyboard!.instantiateViewControllerWithIdentifier("FuelEventController") as! FuelEventController
						fuelEventController.selectedCarId = carIdentifier
						if let navigationController = tabBarController.selectedViewController as? UINavigationController {
							navigationController.popToRootViewControllerAnimated(false)
							navigationController.pushViewController(fuelEventController, animated: false)
						}
					}
				}
				return true
			}
		}

		return false
	}

	func application(application: UIApplication, willFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
		commonLaunchInitialization(launchOptions)
		return true
	}

	func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
		commonLaunchInitialization(launchOptions)
		return true
	}

	func applicationDidEnterBackground(application: UIApplication) {
		CoreDataManager.saveContext()
	}

	func applicationWillTerminate(application: UIApplication) {
		CoreDataManager.saveContext()
	}

	//MARK: - State Restoration

	func application(application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
		return true
	}

	func application(application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
		let bundleVersion = NSBundle.mainBundle().infoDictionary?[kCFBundleVersionKey as String] as? Int ?? 0
		let stateVersion = Int(coder.decodeObjectOfClass(NSString.self, forKey:UIApplicationStateRestorationBundleVersionKey) as? String ?? "") ?? 0

		// we don't restore from iOS6 compatible or future versions of the App
		return stateVersion >= 1572 && stateVersion <= bundleVersion
	}

	//MARK: - Data Import

	private func showImportAlert() {
		if self.importAlert == nil {
			self.importAlert = UIAlertController(title:NSLocalizedString("Importing", comment:""), message:"", preferredStyle:.Alert)

			let progress = UIActivityIndicatorView(frame:self.importAlert!.view.bounds)
			progress.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
			progress.userInteractionEnabled = false
			progress.activityIndicatorViewStyle = .WhiteLarge
			progress.startAnimating()

			self.importAlert!.view.addSubview(progress)

			self.window?.rootViewController?.presentViewController(self.importAlert!, animated:true, completion:nil)
		}
	}

	private func hideImportAlert() {
		self.window?.rootViewController?.dismissViewControllerAnimated(true, completion:nil)
		self.importAlert = nil
	}

	// Read file contents from given URL, guess file encoding
	private func contentsOfURL(url: NSURL) -> String? {
		var enc: NSStringEncoding = NSUTF8StringEncoding
		if let contents = try? String(contentsOfURL: url, usedEncoding: &enc) { return contents }
		if let contents = try? String(contentsOfURL: url, encoding: NSMacOSRomanStringEncoding) { return contents }
		return nil
	}

	// Removes files from the inbox
	private func removeFileItemAtURL(url: NSURL) {
		if url.fileURL {
			do {
				try NSFileManager.defaultManager().removeItemAtURL(url)
			} catch let error as NSError {
				NSLog("%@", error.localizedDescription)
			}
		}
	}

	private func pluralizedImportMessageForCarCount(carCount: Int, eventCount: Int) -> String {
		let format: String
    
		if carCount == 1 {
			format = NSLocalizedString(((eventCount == 1) ? "Imported %d car with %d fuel event."  : "Imported %d car with %d fuel events."), comment:"")
		} else {
			format = NSLocalizedString(((eventCount == 1) ? "Imported %d cars with %d fuel event." : "Imported %d cars with %d fuel events."), comment:"")
		}

		return String(format:format, carCount, eventCount)
	}

	func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject) -> Bool {
		// Ugly, but don't allow nested imports
		if self.importAlert != nil {
			removeFileItemAtURL(url)
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
		let importContext = NSManagedObjectContext(concurrencyType:.PrivateQueueConcurrencyType)
		importContext.parentContext = parentContext

		importContext.performBlock {
			// Read file contents from given URL, guess file encoding
			let CSVString = self.contentsOfURL(url)
			self.removeFileItemAtURL(url)

			if let CSVString = CSVString {
				// Try to import data from CSV file
				let importer = CSVImporter()

				var numCars   = 0
				var numEvents = 0

				let success = importer.importFromCSVString(CSVString,
                                            detectedCars:&numCars,
                                          detectedEvents:&numEvents,
                                               sourceURL:url,
                                              inContext:importContext)

				// On success propagate changes to parent context
				if success {
					CoreDataManager.saveContext(importContext)
					parentContext.performBlock { CoreDataManager.saveContext(parentContext) }
				}

				dispatch_async(dispatch_get_main_queue()) {
					self.hideImportAlert()

					let title = success ? NSLocalizedString("Import Finished", comment:"") : NSLocalizedString("Import Failed", comment:"")

					let message = success
						? self.pluralizedImportMessageForCarCount(numCars, eventCount:numEvents)
						: NSLocalizedString("No valid CSV-data could be found.", comment:"")

					let alertController = UIAlertController(title:title, message:message, preferredStyle:.Alert)
					let defaultAction = UIAlertAction(title:NSLocalizedString("OK", comment:""), style:.Default) { _ in () }
					alertController.addAction(defaultAction)
					self.window?.rootViewController?.presentViewController(alertController, animated:true, completion:nil)
				}
			} else {
				dispatch_async(dispatch_get_main_queue()) {
					self.hideImportAlert()

					let alertController = UIAlertController(title:NSLocalizedString("Import Failed", comment:""),
						message:NSLocalizedString("Can't detect file encoding. Please try to convert your CSV-file to UTF8 encoding.", comment:""),
						preferredStyle:.Alert)
					let defaultAction = UIAlertAction(title:NSLocalizedString("OK", comment:""), style:.Default, handler: nil)
					alertController.addAction(defaultAction)
					self.window?.rootViewController?.presentViewController(alertController, animated:true, completion:nil)
				}
			}
		}

		// Treat imports as successful first startups
		NSUserDefaults.standardUserDefaults().setObject(false, forKey:"firstStartup")
		return true
	}

	//MARK: - NSFetchedResultsControllerDelegate

	func controllerDidChangeContent(controller: NSFetchedResultsController) {
		updateShortcutItems()
	}

	//MARK: - Shared Color Gradients

	static let blueGradient: CGGradientRef = {
		let colorComponentsFlat: [CGFloat] = [ 0.360, 0.682, 0.870, 0.0,  0.466, 0.721, 0.870, 0.9 ]

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let blueGradient = CGGradientCreateWithColorComponents(colorSpace, colorComponentsFlat, nil, 2)!

		return blueGradient
	}()

	static let greenGradient: CGGradientRef = {
		let colorComponentsFlat: [CGFloat] = [ 0.662, 0.815, 0.502, 0.0,  0.662, 0.815, 0.502, 0.9 ]

        let colorSpace = CGColorSpaceCreateDeviceRGB()
		let greenGradient = CGGradientCreateWithColorComponents(colorSpace, colorComponentsFlat, nil, 2)!

		return greenGradient
    }()

	static let orangeGradient: CGGradientRef = {
		let colorComponentsFlat: [CGFloat] = [ 0.988, 0.662, 0.333, 0.0,  0.988, 0.662, 0.333, 0.9 ]

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let orangeGradient = CGGradientCreateWithColorComponents(colorSpace, colorComponentsFlat, nil, 2)!

		return orangeGradient
    }()
}
