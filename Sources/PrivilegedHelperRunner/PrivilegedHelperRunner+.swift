//
//  PrivilegedHelperRunner+.swift
//  PrivilegedHelperKit
//
//  Created by CodingIran on 2025/1/2.
//

import Foundation
import PrivilegedHelperKit

public extension PrivilegedHelperRunner {
    protocol RunnerDelegate: PrivilegedHelperDelegate {
        func helperVersion(of runner: PrivilegedHelperRunner, sharedDirectory: String) -> PrivilegedHelperVersion?
    }
}

// MARK: - Log

extension PrivilegedHelperRunner: PrivilegedHelperKit.Loggable {
    public func log(_ level: PrivilegedHelperKit.LogLevel, _ message: any PrivilegedHelperKit.LogMessaging) {
        guard let delegate = delegate else { return }
        delegate.didOutputLog(level: level, message: message.logString)
    }
}
