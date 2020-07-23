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

  var body: some Scene {
    WindowGroup {
      MainView()
    }
  }
}
