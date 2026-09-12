//
//  SupabaseConfigurationTests.swift
//  EcksteinTests
//
//  How the Supabase client key is resolved.
//
//  Every value here is invented. A test that needed a real key would put one in
//  the repository, which is the thing this whole arrangement exists to avoid.
//
//  These exercise `EnvironmentLoader`'s pure resolution functions rather than
//  `AppEnvironment`, because the latter reads a singleton that is populated
//  once from whatever the test host happens to ship with. The functions tested
//  here are the ones that singleton delegates to, so the logic under test is
//  the logic that runs.
//

import XCTest
@testable import Eckstein

final class SupabaseConfigurationTests: XCTestCase {

    private let urlKey = EnvironmentLoader.supabaseURLKey
    private let publishable = EnvironmentLoader.publishableKeyKey
    private let legacy = EnvironmentLoader.legacyAnonKeyKey

    // MARK: - Which key wins

    func testPublishableKeyIsPreferredOverTheLegacyName() {
        let config = [
            publishable: "sb_publishable_current",
            legacy: "legacy-anon-value",
        ]
        XCTAssertEqual(
            EnvironmentLoader.publishableKey(in: config),
            "sb_publishable_current",
            "The current name has to win; a stale legacy value must not override it"
        )
    }

    func testLegacyAnonKeyIsStillAcceptedWhenItIsTheOnlyOne() {
        // A `.env` written before the rename carries only the old name.
        let config = [legacy: "legacy-anon-value"]
        XCTAssertEqual(EnvironmentLoader.publishableKey(in: config), "legacy-anon-value")
    }

    func testAnEmptyCurrentValueFallsBackRatherThanWinning() {
        // An unset CI variable arrives as an empty string. Treating that as a
        // value would shadow a perfectly good legacy key with nothing.
        let config = [publishable: "", legacy: "legacy-anon-value"]
        XCTAssertEqual(EnvironmentLoader.publishableKey(in: config), "legacy-anon-value")
    }

    // MARK: - Missing configuration

    func testNoConfigurationYieldsNoKey() {
        XCTAssertNil(EnvironmentLoader.publishableKey(in: [:]))
        XCTAssertNil(EnvironmentLoader.resolvedURL(in: [:]))
    }

    func testAnEmptyURLIsTreatedAsAbsent() {
        XCTAssertNil(EnvironmentLoader.resolvedURL(in: [urlKey: ""]))
        XCTAssertEqual(EnvironmentLoader.resolvedURL(in: [urlKey: "https://example.supabase.co"]),
                       "https://example.supabase.co")
    }

    // MARK: - Info.plist

    func testInfoPlistIsReadAsASource() throws {
        // A bundle built here rather than the test host's, so the test says
        // what the plist contains instead of depending on the build.
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("supabase-config-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let plist: [String: Any] = [
            urlKey: "https://example.supabase.co",
            publishable: "sb_publishable_from_plist",
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist, format: .xml, options: 0
        )
        try data.write(to: directory.appendingPathComponent("Info.plist"))

        let bundle = try XCTUnwrap(Bundle(url: directory), "could not open the built bundle")
        let values = EnvironmentLoader.infoPlistValues(in: bundle)

        XCTAssertEqual(values[urlKey], "https://example.supabase.co")
        XCTAssertEqual(EnvironmentLoader.publishableKey(in: values), "sb_publishable_from_plist")
    }

    func testAnEmptyInfoPlistValueIsNotASource() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("supabase-config-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        // What a build with the repository variables unset produces.
        let plist: [String: Any] = [urlKey: "", publishable: "   "]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist, format: .xml, options: 0
        )
        try data.write(to: directory.appendingPathComponent("Info.plist"))

        let bundle = try XCTUnwrap(Bundle(url: directory))
        XCTAssertTrue(
            EnvironmentLoader.infoPlistValues(in: bundle).isEmpty,
            "blank values must leave the build unconfigured, not half-configured"
        )
    }

    // MARK: - Secrets

    func testASecretKeyIsRecognised() {
        XCTAssertTrue(EnvironmentLoader.isSecretKey("sb_secret_abc123"))
        XCTAssertTrue(
            EnvironmentLoader.isSecretKey(#"{"role":"service_role"}"#),
            "a service_role token must be refused however it is spelled"
        )
    }

    func testPublicKeysAreNotMistakenForSecrets() {
        XCTAssertFalse(EnvironmentLoader.isSecretKey("sb_publishable_abc123"))
        XCTAssertFalse(EnvironmentLoader.isSecretKey("eyJhbGciOiJIUzI1NiJ9.anon.body"))
    }

    // MARK: - Placeholders

    func testAnUnexpandedBuildSettingIsAPlaceholder() {
        // The shipped Info.plist holds `$(SUPABASE_URL)` and the build replaces
        // it. If the expansion ever does not happen the app must read the
        // literal as unconfigured, not as the host it should talk to.
        XCTAssertTrue(EnvironmentLoader.containsPlaceholder("$(SUPABASE_URL)"))
        XCTAssertTrue(EnvironmentLoader.containsPlaceholder("$(SUPABASE_PUBLISHABLE_KEY)"))
    }

    func testTheTemplateValuesArePlaceholders() {
        // What `.env.example` carries.
        XCTAssertTrue(EnvironmentLoader.containsPlaceholder("https://your-project-ref.supabase.co"))
        XCTAssertTrue(EnvironmentLoader.containsPlaceholder("YOUR_PUBLISHABLE_KEY"))
    }

    func testRealLookingValuesAreNotPlaceholders() {
        XCTAssertFalse(EnvironmentLoader.containsPlaceholder("https://abcdefghijklm.supabase.co"))
        XCTAssertFalse(EnvironmentLoader.containsPlaceholder("sb_publishable_abc123"))
    }
}
