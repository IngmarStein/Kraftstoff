//
//  WindowSceneDelegate.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 05.06.19.
//  Copyright © 2019 Ingmar Stein. All rights reserved.
//

import UIKit
import CoreSpotlight

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
	var window: UIWindow?

	func sceneDidEnterBackground(_ scene: UIScene) {
		DataManager.saveContext()
	}

	func sceneDidBecomeActive(_ scene: UIScene) {
		self.window?.makeKeyAndVisible()

		if ProcessInfo.processInfo.arguments.firstIndex(of: "-SCREENSHOT") != nil {
			if let windowScene = scene as? UIWindowScene {
				let size = CGSize(width: 1440.0 / 1.54, height: 900 / 1.54)
				windowScene.sizeRestrictions?.minimumSize = size
				windowScene.sizeRestrictions?.maximumSize = size
			}
		}
	}

	func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
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

	func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
		if userActivity.activityType == "com.github.ingmarstein.kraftstoff.fillup" {
			// switch to fill-up tab
			if let tabBarController = self.window?.rootViewController as? UITabBarController {
				tabBarController.selectedIndex = 0
			}
		} else {
			if userActivity.activityType == CSSearchableItemActionType {
				// switch to cars tab and show the fuel history
				if let tabBarController = self.window?.rootViewController as? UITabBarController {
					tabBarController.selectedIndex = 1
					if let carIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String, DataManager.managedObjectForModelIdentifier(carIdentifier) != nil {
						if let fuelEventController = tabBarController.storyboard!.instantiateViewController(withIdentifier: "FuelEventController") as? FuelEventController {
							fuelEventController.selectedCarId = carIdentifier
							if let navigationController = tabBarController.selectedViewController as? UINavigationController {
								navigationController.popToRootViewController(animated: false)
								navigationController.pushViewController(fuelEventController, animated: false)
							}
						}
					}
				}
			}
		}
	}

	// MARK: - Data Import

	func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
		let viewController = self.window!.rootViewController!

		for urlContext in URLContexts {
			if !StoreManager.sharedInstance.checkCarCount() {
				StoreManager.sharedInstance.showBuyOptions(viewController)
				return
			}

			UIApplication.kraftstoffAppDelegate.importCSV(at: urlContext.url, parentViewController: viewController)
		}

		// Treat imports as successful first startups
		UserDefaults.standard.set(false, forKey: "firstStartup")
	}

}
