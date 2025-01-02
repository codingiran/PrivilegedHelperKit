//
//  PrivilegedHelperRunner+.swift
//  PrivilegedHelperKit
//
//  Created by CodingIran on 2025/1/2.
//

import Foundation
import PrivilegedHelperKit

public extension PrivilegedHelperRunner {
    protocol RunnerDelegate: NSObjectProtocol {
        func version(of runner: PrivilegedHelperRunner, workingDir: String) -> String?
        func helperRunner(_ runner: PrivilegedHelperRunner, didOutputLog level: PrivilegedHelperKit.LogLevel, message: String)
    }
}

// MARK: - Log

extension PrivilegedHelperRunner: PrivilegedHelperKit.Loggable {
    public func log(_ level: PrivilegedHelperKit.LogLevel, _ message: any PrivilegedHelperKit.LogMessaging) {
        guard let delegate = delegate else { return }
        delegate.helperRunner(self, didOutputLog: level, message: message.logString)
    }
}
