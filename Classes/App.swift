//
//  App.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 20.07.20.
//  Copyright © 2020 Ingmar Stein. All rights reserved.
//

import CoreSpotlight
import SwiftUI

@main
struct KraftstoffApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  @Environment(\.scenePhase) private var scenePhase

  @State private var selectedTab = 0

  var body: some Scene {
    WindowGroup {
      MainView(selectedTab: $selectedTab)
        .environment(\.managedObjectContext, DataManager.managedObjectContext)
        .onContinueUserActivity("com.github.ingmarstein.kraftstoff.fillup", perform: handleFillup)
        .onContinueUserActivity(CSSearchableItemActionType, perform: handleSpotlight)
        .onOpenURL(perform: onOpenURL)
    }
    .onChange(of: scenePhase) { phase in
      switch phase {
      case .background:
        DataManager.saveContext()
      case .active:
        if ProcessInfo.processInfo.arguments.firstIndex(of: "-UNITTEST") != nil {
          UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.forEach { windowScene in
            windowScene.windows.forEach { window in window.layer.speed = 100.0 }
          }
        }

        #if targetEnvironment(macCatalyst)
          if ProcessInfo.processInfo.arguments.firstIndex(of: "-SCREENSHOT") != nil {
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.forEach { windowScene in
              let size = CGSize(width: 1440.0, height: 900.0)
              windowScene.sizeRestrictions?.minimumSize = size
              windowScene.sizeRestrictions?.maximumSize = size
            }
          }
        #endif
      case .inactive:
        break
      @unknown default:
        break
      }
    }
  }

  init() {
    UITableView.appearance().backgroundColor = UIColor.clear
  }

  func handleFillup(_: NSUserActivity) {
    // switch to fill-up tab
    selectedTab = 0
  }

  func handleSpotlight(_: NSUserActivity) { // switch to cars tab and show the fuel history
    selectedTab = 1
    // TODO:
    /*
     if let carIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String, DataManager.managedObjectForModelIdentifier(carIdentifier) != nil {
       if let fuelEventController = tabBarController.storyboard!.instantiateViewController(withIdentifier: "FuelEventController") as? FuelEventController {
         fuelEventController.selectedCarId = carIdentifier
         if let navigationController = tabBarController.selectedViewController as? UINavigationController {
           navigationController.popToRootViewController(animated: false)
           navigationController.pushViewController(fuelEventController, animated: false)
         }
       }
     }
     */
  }

  // MARK: - Data Import

  func onOpenURL(url _: URL) {
    // TODO:
    /*
     let viewController = self.window!.rootViewController!

     if !StoreManager.sharedInstance.checkCarCount() {
       StoreManager.sharedInstance.showBuyOptions(viewController)
       return
     }

     UIApplication.kraftstoffAppDelegate.importCSV(at: url, parentViewController: viewController)
     */

    // Treat imports as successful first startups
    UserDefaults.standard.set(false, forKey: "firstStartup")
  }
}
