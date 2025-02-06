//
//  Version.swift
//  PrivilegedHelperKit
//
//  Created by CodingIran on 2025/1/3.
//

import Foundation

@objc(PrivilegedHelperVersion)
public final class PrivilegedHelperVersion: NSObject, NSSecureCoding, Sendable {
    public let bundleIdentifier: String
    public let bundleVersion: String
    public let bundleShortVersion: String

    public init(bundleIdentifier: String, bundleVersion: String, bundleShortVersion: String) {
        self.bundleIdentifier = bundleIdentifier
        self.bundleVersion = bundleVersion
        self.bundleShortVersion = bundleShortVersion
    }

    public static var supportsSecureCoding: Bool { true }

    public func encode(with coder: NSCoder) {
        coder.encode(bundleIdentifier, forKey: "bundleIdentifier")
        coder.encode(bundleVersion, forKey: "bundleVersion")
        coder.encode(bundleShortVersion, forKey: "bundleShortVersion")
    }

    public required init?(coder: NSCoder) {
        guard
            let bundleIdentifier = coder.decodeObject(of: NSString.self, forKey: "bundleIdentifier") as? String,
            let bundleVersion = coder.decodeObject(of: NSString.self, forKey: "bundleVersion") as? String,
            let bundleShortVersion = coder.decodeObject(of: NSString.self, forKey: "bundleShortVersion") as? String
        else {
            return nil
        }
        self.bundleIdentifier = bundleIdentifier
        self.bundleVersion = bundleVersion
        self.bundleShortVersion = bundleShortVersion
    }
}

public extension PrivilegedHelperVersion {
    static func == (lhs: PrivilegedHelperVersion, rhs: PrivilegedHelperVersion) -> Bool {
        return lhs.bundleIdentifier == rhs.bundleIdentifier
            && lhs.bundleVersion == rhs.bundleVersion
            && lhs.bundleShortVersion == rhs.bundleShortVersion
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? PrivilegedHelperVersion else {
            return false
        }
        return bundleIdentifier == object.bundleIdentifier
            && bundleVersion == object.bundleVersion
            && bundleShortVersion == object.bundleShortVersion
    }

    func isGreaterThan(_ version: PrivilegedHelperVersion) -> Bool {
        guard bundleIdentifier == version.bundleIdentifier else {
            return false
        }
        if bundleShortVersion.compare(version.bundleShortVersion, options: .numeric) == .orderedDescending {
            return true
        }
        if bundleVersion.compare(version.bundleVersion, options: .numeric) == .orderedDescending {
            return true
        }
        return false
    }

    func isGreaterThanOrEqualTo(_ version: PrivilegedHelperVersion) -> Bool {
        return isEqual(version) || isGreaterThan(version)
    }

    override var description: String {
        "bundleIdentifier: \(bundleIdentifier), bundleVersion: \(bundleVersion), bundleShortVersion: \(bundleShortVersion)"
    }
}
