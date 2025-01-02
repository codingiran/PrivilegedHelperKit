//
//  Logging.swift
//  PrivilegedHelperKit
//
//  Created by CodingIran on 2025/1/2.
//

public extension PrivilegedHelperKit {
    enum LogLevel: String {
        case verbose
        case info
        case warning
        case debug
        case error
        case wtf
    }

    protocol LogMessaging: Any {
        var logString: String { get }
    }

    protocol Loggable {
        func log(_ level: PrivilegedHelperKit.LogLevel, _ message: PrivilegedHelperKit.LogMessaging)
    }
}

extension String: PrivilegedHelperKit.LogMessaging {
    public var logString: String { self }
}

extension Array where Element: PrivilegedHelperKit.LogMessaging {
    var logString: String {
        map { $0.logString }.joined(separator: "\n")
    }
}
