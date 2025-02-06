//
//  Protocol.swift
//  PrivilegedHelperKit
//
//  Created by CodingIran on 2025/1/2.
//

import Foundation

@objc public protocol PrivilegedHelperXPCProtocol: Sendable {
    /// Get helper runner version
    func getHelperVersion(sharedDirectory: String, resultBack: ((PrivilegedHelperVersion?) -> Void)?)

    /// Exit process
    func exitProcess()

    /// Uninstall helper runner
    func uninstall()
}

public protocol PrivilegedHelperDelegate: Sendable {
    func xpcInterfaceProtocol() -> Protocol

    func didOutputLog(level: PrivilegedHelperKit.LogLevel, message: String)
}
