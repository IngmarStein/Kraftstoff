//
//  AppDelegate.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 05.05.15.
//
//

import UIKit
import SwiftUI
import Combine
import CoreSpotlight
import MobileCoreServices
import CoreData
import TPInAppReceipt

extension UIApplication {
	static var kraftstoffAppDelegate: AppDelegate {
		// swiftlint:disable:next force_cast
		return shared.delegate as! AppDelegate
	}
}

// Read file contents from given URL, guess file encoding
private func contentsOfURL(_ url: URL) -> String? {
	var enc: String.Encoding = String.Encoding.utf8
	if let contents = try? String(contentsOf: url, usedEncoding: &enc) {
		return contents
	}
	if let contents = try? String(contentsOf: url, encoding: String.Encoding.macOSRoman) {
		return contents
	}
	return nil
}

@UIApplicationMain
final class AppDelegate: NSObject, UIApplicationDelegate, NSFetchedResultsControllerDelegate {
	private var initialized = false
	var window: UIWindow?
	private var appReceipt: InAppReceipt?

	private var importAlert: UIAlertController?
	private var importAlertParentViewController: UIViewController?

	private lazy var carsFetchedResultsController: NSFetchedResultsController<Car> = {
		DataManager.fetchedResultsControllerForCars(delegate: self)
	}()

	// MARK: - Application Lifecycle

	override init() {
		UserDefaults.standard.register(defaults:
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

	private func commonLaunchInitialization(_ launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) {
		if !initialized {
			initialized = true

			#if !DEBUG
			do {
				appReceipt = try InAppReceipt.localReceipt()
				try appReceipt?.verify()
			} catch {
				fatalError("failed to validate receipt: \(error)")
			}
			#endif

			DataManager.load()

			//UIApplication.shared.registerForRemoteNotifications()

			if ProcessInfo.processInfo.arguments.firstIndex(of: "-STARTFRESH") != nil {
				DataManager.deleteAllObjects()

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
			if launchOptions?[UIApplication.LaunchOptionsKey.url] == nil {
				let defaults = UserDefaults.standard

				if defaults.bool(forKey: "firstStartup") {
					if defaults.string(forKey: "preferredCarID") == "" {
						// FIXME: window
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
			UIApplication.shared.shortcutItems = cars.compactMap { car in
				guard let userInfo = DataManager.modelIdentifierForManagedObject(car).flatMap({ ["objectId": $0] }) else { return nil }
				return UIApplicationShortcutItem(type: "fillup", localizedTitle: car.ksName, localizedSubtitle: car.numberPlate, icon: nil, userInfo: userInfo as [String: NSSecureCoding])
			}

			if CSSearchableIndex.isIndexingAvailable() {
				let searchableItems = cars.map { car -> CSSearchableItem in
					let carIdentifier = DataManager.modelIdentifierForManagedObject(car)
					let attributeset = CSSearchableItemAttributeSet(itemContentType: kUTTypeText as String)
					attributeset.title = car.ksName
					attributeset.contentDescription = car.ksNumberPlate
					return CSSearchableItem(uniqueIdentifier: carIdentifier, domainIdentifier: "com.github.ingmarstein.kraftstoff.cars", attributeSet: attributeset)
				}
				CSSearchableIndex.default().indexSearchableItems(Array(searchableItems), completionHandler: nil)
			}
		}
	}

	func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
		commonLaunchInitialization(launchOptions)
		return true
	}

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
		commonLaunchInitialization(launchOptions)
		return true
	}

	func applicationDidEnterBackground(_ application: UIApplication) {
		DataManager.saveContext()
	}

	func applicationWillTerminate(_ application: UIApplication) {
		DataManager.saveContext()
	}

	// MARK: - State Restoration

	func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
		return true
	}

	func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
		let bundleVersion = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as? Int ?? 0
		let stateVersion = Int(coder.decodeObject(of: NSString.self, forKey: UIApplication.stateRestorationBundleVersionKey) as String? ?? "") ?? 0

		// we don't restore from future versions of the app
		return stateVersion <= bundleVersion
	}

	// MARK: - Data Import

	private func showImportAlert(parentViewController: UIViewController) {
		if self.importAlert == nil {
			self.importAlert = UIAlertController(title: NSLocalizedString("Importing", comment: "") + "\n\n", message: "", preferredStyle: .alert)
			self.importAlertParentViewController = parentViewController

			let progress = UIActivityIndicatorView(frame: self.importAlert!.view.bounds)
			progress.autoresizingMask = [UIView.AutoresizingMask.flexibleWidth, UIView.AutoresizingMask.flexibleHeight]
			progress.isUserInteractionEnabled = false
			progress.style = .large
			progress.color = .black
			let center = self.importAlert!.view.center
			progress.center = CGPoint(x: center.x, y: center.y + 30.0)
			progress.startAnimating()

			self.importAlert!.view.addSubview(progress)

			parentViewController.present(self.importAlert!, animated: true, completion: nil)
		}
	}

	private func hideImportAlert(completion: @escaping () -> Void) {
		self.importAlertParentViewController?.dismiss(animated: true, completion: completion)
		self.importAlert = nil
	}

	func importCSV(at url: URL, parentViewController: UIViewController) {
		// Show modal activity indicator while importing
		showImportAlert(parentViewController: parentViewController)

		// Import in context with private queue
		let parentContext = DataManager.managedObjectContext
		let importContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
		importContext.parent = parentContext

		importContext.perform {
			// Read file contents from given URL, guess file encoding
			let CSVString = contentsOfURL(url)

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
					DataManager.saveContext(importContext)
					parentContext.perform { DataManager.saveContext(parentContext) }
				}

				DispatchQueue.main.async {
					self.hideImportAlert {
						let title = success ? NSLocalizedString("Import Finished", comment: "") : NSLocalizedString("Import Failed", comment: "")

						let message = success
							? String.localizedStringWithFormat(NSLocalizedString("Imported %d car(s) with %d fuel event(s).", comment: ""), numCars, numEvents)
							: NSLocalizedString("No valid CSV data could be found.", comment: "")

						let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
						let defaultAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in () }
						alertController.addAction(defaultAction)
						// FIXME: window
						self.window?.rootViewController?.present(alertController, animated: true, completion: nil)
					}
				}
			} else {
				DispatchQueue.main.async {
					self.hideImportAlert {
						let alertController = UIAlertController(title: NSLocalizedString("Import Failed", comment: ""),
																message: NSLocalizedString("Can't detect file encoding. Please try to convert your CSV file to UTF8 encoding.", comment: ""),
																preferredStyle: .alert)
						let defaultAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: nil)
						alertController.addAction(defaultAction)
						// FIXME: window
						self.window?.rootViewController?.present(alertController, animated: true, completion: nil)
					}
				}
			}
		}
	}

	// MARK: - NSFetchedResultsControllerDelegate
 	func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		updateShortcutItems()
	}

	// MARK: - Receipt validation

	func validReceiptForInAppPurchase(_ productId: String) -> Bool {
		guard let receipt = appReceipt else { return false }
		return !receipt.purchases(ofProductIdentifier: productId).isEmpty
	}

	// MARK: - Modal Alerts

	var alertWindow: UIWindow {
		// TODO
		//if let window = UIApplication.shared.keyWindow {
		//	return window
		//} else {
			let alertWindow = UIWindow(frame: UIScreen.main.bounds)
			alertWindow.rootViewController = UIViewController()
			alertWindow.windowLevel = .alert + 1
			alertWindow.makeKeyAndVisible()
			return alertWindow
		//}
	}

	// MARK: - Shared Color Gradients

	static let blueGradient: CGGradient = {
		let colorComponentsFlat: [CGFloat] = [ 0.360, 0.682, 0.870, 0.0, 0.466, 0.721, 0.870, 0.9 ]

		let colorSpace = CGColorSpaceCreateDeviceRGB()
		let blueGradient = CGGradient(colorSpace: colorSpace, colorComponents: colorComponentsFlat, locations: nil, count: 2)!

		return blueGradient
	}()

	static let greenGradient: CGGradient = {
		let colorComponentsFlat: [CGFloat] = [ 0.662, 0.815, 0.502, 0.0, 0.662, 0.815, 0.502, 0.9 ]

		let colorSpace = CGColorSpaceCreateDeviceRGB()
		let greenGradient = CGGradient(colorSpace: colorSpace, colorComponents: colorComponentsFlat, locations: nil, count: 2)!

		return greenGradient
	}()

	static let orangeGradient: CGGradient = {
		let colorComponentsFlat: [CGFloat] = [ 0.988, 0.662, 0.333, 0.0, 0.988, 0.662, 0.333, 0.9 ]

		let colorSpace = CGColorSpaceCreateDeviceRGB()
		let orangeGradient = CGGradient(colorSpace: colorSpace, colorComponents: colorComponentsFlat, locations: nil, count: 2)!

		return orangeGradient
	}()
}
