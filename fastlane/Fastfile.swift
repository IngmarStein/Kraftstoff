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

    func beforeAll() {
        optOutUsage()
        swiftlint(mode: "lint", configFile: ".swiftlint.yml", strict: false, ignoreExitStatus: false, quiet: false)
    }

    func testLane() {
        desc("Runs all the tests")
        runTests(project: "Kraftstoff.xcodeproj", scheme: "Kraftstoff")
    }

    func betaLane() {
        desc("Submit a new Beta Build to Apple TestFlight. This will also make sure the profile is up to date")

        runTests(project: "Kraftstoff.xcodeproj", scheme: "Kraftstoff")
        incrementBuildNumber()
        // syncCodeSigning(gitUrl: "gitUrl", appIdentifier: [appIdentifier], username: appleID)
        captureScreenshots(project: "Kraftstoff.xcodeproj", languages: ["en-US", "de-DE", "fr-FR", "ja"], scheme: "Fastlane UI Tests")
        buildApp(project: "Kraftstoff.xcodeproj", scheme: "Kraftstoff", configuration: "Release")
        uploadToTestflight(username: appleID)
    }

    func releaseLane() {
        desc("Deploy a new version to the App Store")

        runTests(project: "Kraftstoff.xcodeproj", scheme: "Kraftstoff")
        incrementBuildNumber()
        // syncCodeSigning(gitUrl: "gitUrl", type: "appstore", appIdentifier: [appIdentifier], username: appleID)
        captureScreenshots(project: "Kraftstoff.xcodeproj", languages: ["en-US", "de-DE", "fr-FR", "ja"], scheme: "Fastlane UI Tests")
        buildApp(project: "Kraftstoff.xcodeproj", scheme: "Kraftstoff", configuration: "Release")
        uploadToAppStore(username: appleID, force: true, app: appIdentifier)
        frameScreenshots()

        //addGitTag(buildNumber: getVersionNumber())
    }

    // You can define as many lanes as you want

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

    // All available actions: https://docs.fastlane.tools/actions

    // fastlane reports which actions are used. No personal data is recorded.
    // Learn more at https://github.com/fastlane/fastlane/#metrics
}
