//
//  Protocol.swift
//  PrivilegedHelperKit
//
//  Created by CodingIran on 2025/1/2.
//

import Foundation

@objc public protocol PrivilegedHelperXPCProtocol: NSObjectProtocol {
    /// Get helper runner version
    func getVersion(workingDir: String, resultBack: ((String?) -> Void)?)
    
    /// Exit process
    func exitProcess()

    /// Uninstall helper runner
    func uninstall()
}
