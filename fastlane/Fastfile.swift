// Customize this file, documentation can be found here:
// https://docs.fastlane.tools/
// All available actions: https://docs.fastlane.tools/actions
// can also be listed using the `fastlane actions` command

// Change the syntax highlighting to Swift
// All lines starting with // are ignored when running `fastlane`

// If you want to automatically update fastlane if a new version is available:
// updateFastlane()

import Foundation

class Fastfile: LaneFile {
  // This is the minimum version number required.
  // Update this, if you use features of a newer version
  var fastlaneVersion = "2.141.0"

  let catalystDestination = "platform=macOS,variant=Mac Catalyst"
  let project: OptionalConfigValue<String?> = "Kraftstoff.xcodeproj"
  let scheme: OptionalConfigValue<String?> = "Kraftstoff"
  let screenshotScheme: OptionalConfigValue<String?> = "Fastlane UI Tests"

  let devices: OptionalConfigValue<[String]?> = .userDefined([
    "iPhone 8",
    "iPhone 8 Plus",
    "iPhone 11",
    "iPhone 11 Pro",
    "iPhone 11 Pro Max",
    "iPhone 13",
    "iPhone 13 Pro",
    "iPhone 13 Pro Max",
    "iPhone SE (2nd generation)",
    "iPad Pro (9.7-inch)",
    "iPad Pro (11-inch) (3rd generation)",
    "iPad Pro (12.9-inch) (5th generation)"
  ])

  let languages = [
    "en-US",
    "de-DE",
    "fr-FR",
    "ja"
  ]

  func beforeAll() {
    optOutUsage()
    setupCi()
    swiftlint(mode: "lint", configFile: ".swiftlint.yml", strict: false, ignoreExitStatus: false, quiet: false)
  }

  func testLane() {
    desc("Runs all the tests")
    runTests(project: project, scheme: scheme, configuration: "Automation")
  }

  func testMacOSLane() {
    desc("Runs all the tests")
    runTests(project: project, scheme: scheme, configuration: "Automation", catalystPlatform: "macos")
  }

  private func buildIOS() {
    incrementBuildNumber()
    captureScreenshots(project: project,
                       devices: devices,
                       languages: languages,
                       outputDirectory: "./fastlane/screenshots",
                       scheme: screenshotScheme,
                       disableSlideToType: true)
    buildIosApp(project: project, scheme: scheme, configuration: "Automation", exportXcargs: "-allowProvisioningUpdates")
  }

  private func buildMacOS() {
    incrementBuildNumber()
    //captureScreenshots(project: project,
    //           devices: devices,
    //           languages: languages,
    //           outputDirectory: "./fastlane/screenshots-catalyst",
    //           scheme: screenshotScheme)
    buildMacApp(project: project, scheme: scheme, configuration: "Automation", exportXcargs: "-allowProvisioningUpdates")
  }

  func betaLane() {
    desc("Submit a new beta iOS build to Apple TestFlight. This will also make sure the profile is up to date")

    testLane()
    buildIOS()
    uploadToTestflight(username: "\(appleID)")
  }

  func betaMacOSLane() {
    desc("Submit a new beta macOS build to Apple TestFlight. This will also make sure the profile is up to date")

    testMacOSLane()
    buildMacOS()
    //notarize(package: <#T##String#>, username: appleID)
    uploadToTestflight(username: "\(appleID)")
  }

  func releaseLane() {
    desc("Deploy a new version to the App Store")

    buildIOS()
    uploadToAppStore(username: "\(appleID)", appIdentifier: "\(appIdentifier)")
    frameScreenshots(path: "./fastlane/screenshots")

     //addGitTag(buildNumber: getVersionNumber())
  }

  func releaseMacOSLane() {
    desc("Deploy a new macOS version to the App Store")

    buildMacOS()
    uploadToAppStore(username: "\(appleID)",
                     appIdentifier: "\(appIdentifier)",
                     platform: "osx",
                     screenshotsPath: "./fastlane/screenshots-catalyst")

    //addGitTag(buildNumber: getVersionNumber())
  }

  func afterAll(currentLane: String) {
    // This block is called, only if the executed lane was successful
    // slack(
    //   message: "Successfully deployed new App Update.",
    //   slackUrl: "slackURL"
    // )
  }

  func onError(currentLane: String, errorInfo: String) {
    // slack(
    //   message: errorInfo,
    //   slackUrl: "slackUrl",
    //   success: false
    // )
  }
}
