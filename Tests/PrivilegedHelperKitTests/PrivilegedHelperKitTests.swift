@testable import PrivilegedHelperKit
import XCTest

final class PrivilegedHelperKitTests: XCTestCase {
    func testExample() throws {
        // XCTest Documentation
        // https://developer.apple.com/documentation/xctest

        // Defining Test Cases and Test Methods
        // https://developer.apple.com/documentation/xctest/defining_test_cases_and_test_methods
    }

    func testPrivilegedHelperVersion() {
        let version1 = PrivilegedHelperVersion(bundleIdentifier: "com.codingiran.PrivilegedHelperKit", bundleVersion: "9", bundleShortVersion: "1.0")
        let version2 = PrivilegedHelperVersion(bundleIdentifier: "com.codingiran.PrivilegedHelperKit", bundleVersion: "10", bundleShortVersion: "1.1")
        let isEqual = version2.isEqual(version1)
        print(isEqual)
        let isGreaterThan = version2.isGreaterThan(version1)
        print(isGreaterThan)
    }
}
