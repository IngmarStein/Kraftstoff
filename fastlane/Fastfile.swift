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
    var fastlaneVersion = "2.69.3"

    let macAppIdentifier = "maccatalyst." + appIdentifier
    let catalystDestination = "platform=macOS,arch=x86_64,variant=Mac Catalyst"
    let project = "Kraftstoff.xcodeproj"
    let scheme = "Kraftstoff"
    let screenshotScheme = "Fastlane UI Tests"

    let devices = [
        "iPhone 8",
        "iPhone 8 Plus",
        "iPhone 11",
        "iPhone 11 Pro",
        "iPhone 11 Pro Max",
        "iPad Pro (9.7-inch)",
        "iPad (7th generation)",
        "iPad Pro (11-inch)",
        "iPad Pro (12.9-inch) (3rd generation)"
    ]

    let languages = [
        "en-US",
        "de-DE",
        "fr-FR",
        "ja"
    ]

    func beforeAll() {
        optOutUsage()
        swiftlint(mode: "lint", configFile: ".swiftlint.yml", strict: false, ignoreExitStatus: false, quiet: false)
    }

    func testLane() {
        desc("Runs all the tests")
        runTests(project: project, scheme: scheme)
    }

    func testMacOSLane() {
        desc("Runs all the tests")
        runTests(project: project, scheme: scheme, destination: catalystDestination)
    }

    private func buildIOS() {
        runTests(project: project, scheme: scheme)
        incrementBuildNumber()
        // syncCodeSigning(gitUrl: "gitUrl", appIdentifier: [appIdentifier], username: appleID)
        captureScreenshots(project: project,
                           devices: devices,
                           languages: languages,
                           outputDirectory: "./fastlane/screenshots",
                           scheme: screenshotScheme)
        buildIosApp(project: project, scheme: scheme, configuration: "Release")
    }

    private func buildMacOS() {
        runTests(project: project, scheme: scheme, destination: catalystDestination)
        incrementBuildNumber()
        // syncCodeSigning(gitUrl: "gitUrl", appIdentifier: [appIdentifier], username: appleID)
        //captureScreenshots(project: project,
        //                   devices: devices,
        //                   languages: languages,
        //                   outputDirectory: "./fastlane/screenshots-catalyst",
        //                   scheme: screenshotScheme)
        buildIosApp(project: project, scheme: scheme, configuration: "Release", destination: catalystDestination)
    }

    func betaLane() {
        desc("Submit a new Beta Build to Apple TestFlight. This will also make sure the profile is up to date")

        buildIOS()
        uploadToTestflight(username: appleID)
    }

    func betaMacOSLane() {
        desc("Submit a new Beta macOS Build to Apple TestFlight. This will also make sure the profile is up to date")

        buildMacOS()
        uploadToTestflight(username: appleID, appPlatform: "macOS")
    }

    func releaseLane() {
        desc("Deploy a new version to the App Store")

        buildIOS()
        uploadToAppStore(username: appleID, app: appIdentifier)
        frameScreenshots(path: "./fastlane/screenshots")

       //addGitTag(buildNumber: getVersionNumber())
    }

    func releaseMacOSLane() {
        desc("Deploy a new macOS version to the App Store")

        buildMacOS()
        uploadToAppStore(username: appleID,
                         appIdentifier: macAppIdentifier,
                         platform: "osx",
                         screenshotsPath: "./fastlane/screenshots-catalyst",
                         app: macAppIdentifier)

        //addGitTag(buildNumber: getVersionNumber())
    }

    func afterAll(currentLane: String) {
        // This block is called, only if the executed lane was successful
        // slack(
        //     message: "Successfully deployed new App Update.",
        //     slackUrl: "slackURL"
        // )
    }

    func onError(currentLane: String, errorInfo: String) {
        // slack(
        //     message: errorInfo,
        //     slackUrl: "slackUrl",
        //     success: false
        // )
    }

    // fastlane reports which actions are used. No personal data is recorded.
    // Learn more at https://github.com/fastlane/fastlane/#metrics
}
