//
//  ReleaseConfigTests.swift
//  EcksteinTests
//
//  The release facts a passing build does not check.
//
//  These are the ones that fail on a device or in review rather than in CI:
//  iOS terminates an app the moment it touches the camera without a usage
//  description in the bundle, and an App Store submission is rejected for an
//  over-broad transport-security exception. Both are invisible to a build and
//  to a Simulator launch, which is exactly why they are asserted here.
//
//  `Bundle.main` is the app under test, not the test bundle: the unit tests run
//  hosted in Eckstein.app, which is also how `PersistenceController` loads its
//  managed object model from `Bundle.main`.
//

import XCTest

final class ReleaseConfigTests: XCTestCase {

    /// Every permission the app actually asks for, and the reason it asks.
    ///
    /// Kept as one list rather than four tests so that adding a permission
    /// without its string is a one-line change at the point of the mistake.
    private static let requiredUsageDescriptions = [
        "NSCameraUsageDescription",
        "NSHealthShareUsageDescription",
        "NSHealthUpdateUsageDescription",
        "NSBluetoothAlwaysUsageDescription",
    ]

    private func string(_ key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }

    func testEveryPermissionTheAppUsesHasAUsageDescription() {
        for key in Self.requiredUsageDescriptions {
            let value = string(key)
            XCTAssertNotNil(value, """
                \(key) is missing from the built Info.plist. iOS terminates an \
                app that uses the camera or HealthKit without it.
                """)
            XCTAssertFalse(value?.isEmpty ?? true, "\(key) is present but empty")
        }
    }

    /// A description has to say what the app does with the data. The audit
    /// found prompts like "This app needs camera access", which tell the user
    /// nothing and read as boilerplate in review.
    func testUsageDescriptionsSayWhatTheDataIsFor() {
        for key in Self.requiredUsageDescriptions {
            guard let value = string(key) else { continue }
            XCTAssertGreaterThan(
                value.split(separator: " ").count, 6,
                "\(key) reads as a stub rather than a reason: \"\(value)\""
            )
        }
    }

    /// An exception here would silently allow cleartext traffic for the whole
    /// app, which is the sort of thing that ships and is noticed in review.
    func testTransportSecurityIsNotDisabled() {
        let ats = Bundle.main.object(forInfoDictionaryKey: "NSAppTransportSecurity") as? [String: Any]
        XCTAssertNil(
            ats?["NSAllowsArbitraryLoads"],
            "NSAllowsArbitraryLoads is set; production traffic must stay on HTTPS"
        )
    }
}
