//
//  App.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 20.07.20.
//  Copyright © 2020 Ingmar Stein. All rights reserved.
//

import SwiftUI

@main
struct KraftstoffApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup {
      MainView()
        .environment(\.managedObjectContext, DataManager.managedObjectContext)
    }
    .onChange(of: scenePhase) { phase in
      switch phase {
      case .background:
        DataManager.saveContext()
      case .active:
        if ProcessInfo.processInfo.arguments.firstIndex(of: "-UNITTEST") != nil {
          //TODO
          //self.window?.layer.speed = 100
        }

        #if targetEnvironment(macCatalyst)
        if ProcessInfo.processInfo.arguments.firstIndex(of: "-SCREENSHOT") != nil {
          if let windowScene = scene as? UIWindowScene {
            let size = CGSize(width: 1440.0, height: 900.0)
            windowScene.sizeRestrictions?.minimumSize = size
            windowScene.sizeRestrictions?.maximumSize = size
          }
        }
        #endif
      default: break
      }
    }
  }
}
