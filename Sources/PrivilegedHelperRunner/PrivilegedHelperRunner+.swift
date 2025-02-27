//
//  PrivilegedHelperRunner+.swift
//  PrivilegedHelperKit
//
//  Created by CodingIran on 2025/1/2.
//

import Foundation
@_exported import PrivilegedHelperKit

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

// MARK: - CodesignCheck

// https://github.com/duanefields/VirtualKVM/blob/master/VirtualKVM/CodesignCheck.swift
let kSecCSDefaultFlags = 0

extension PrivilegedHelperRunner {
    enum CodesignCheckError: LocalizedError, Sendable {
        case codeSignNotMatched
        case codeSignCheckFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .codeSignNotMatched:
                return "codesign not matched"
            case .codeSignCheckFailed(let message):
                return "code sign check error: \(message)"
            }
        }
    }
    
    func checkConnectionCodesign(_ connection: NSXPCConnection) -> Result<Bool, Error> {
        do {
            guard try PrivilegedHelperRunner.codeSigningMatches(pid: connection.processIdentifier) else {
                return .failure(CodesignCheckError.codeSignNotMatched)
            }
            return .success(true)
        } catch {
            return .failure(error)
        }
    }
    
    private static func codeSigningMatches(pid: pid_t) throws -> Bool {
        return try codeSigningCertificatesForSelf() == codeSigningCertificates(forPID: pid)
    }
    
    private static func codeSigningCertificatesForSelf() throws -> [SecCertificate] {
        guard let secStaticCode = try secStaticCodeSelf() else { return [] }
        return try codeSigningCertificates(forStaticCode: secStaticCode)
    }
    
    private static func codeSigningCertificates(forPID pid: pid_t) throws -> [SecCertificate] {
        guard let secStaticCode = try secStaticCode(forPID: pid) else { return [] }
        return try codeSigningCertificates(forStaticCode: secStaticCode)
    }
    
    private static func executeSecFunction(_ secFunction: () -> (OSStatus)) throws {
        let osStatus = secFunction()
        guard osStatus == errSecSuccess else {
            throw CodesignCheckError.codeSignCheckFailed(String(describing: SecCopyErrorMessageString(osStatus, nil)))
        }
    }
    
    private static func secStaticCodeSelf() throws -> SecStaticCode? {
        var secCodeSelf: SecCode?
        try executeSecFunction { SecCodeCopySelf(SecCSFlags(rawValue: 0), &secCodeSelf) }
        guard let secCode = secCodeSelf else {
            throw CodesignCheckError.codeSignCheckFailed("SecCode returned empty from SecCodeCopySelf")
        }
        return try secStaticCode(forSecCode: secCode)
    }
    
    private static func secStaticCode(forPID pid: pid_t) throws -> SecStaticCode? {
        var secCodePID: SecCode?
        try executeSecFunction { SecCodeCopyGuestWithAttributes(nil, [kSecGuestAttributePid: pid] as CFDictionary, [], &secCodePID) }
        guard let secCode = secCodePID else {
            throw CodesignCheckError.codeSignCheckFailed("SecCode returned empty from SecCodeCopyGuestWithAttributes")
        }
        return try secStaticCode(forSecCode: secCode)
    }
    
    private static func secStaticCode(forSecCode secCode: SecCode) throws -> SecStaticCode? {
        var secStaticCodeCopy: SecStaticCode?
        try executeSecFunction { SecCodeCopyStaticCode(secCode, [], &secStaticCodeCopy) }
        guard let secStaticCode = secStaticCodeCopy else {
            throw CodesignCheckError.codeSignCheckFailed("SecStaticCode returned empty from SecCodeCopyStaticCode")
        }
        return secStaticCode
    }
    
    private static func isValid(secStaticCode: SecStaticCode) throws {
        try executeSecFunction { SecStaticCodeCheckValidity(secStaticCode, SecCSFlags(rawValue: kSecCSDoNotValidateResources | kSecCSCheckNestedCode), nil) }
    }
    
    private static func secCodeInfo(forStaticCode secStaticCode: SecStaticCode) throws -> [String: Any]? {
        try isValid(secStaticCode: secStaticCode)
        var secCodeInfoCFDict: CFDictionary?
        try executeSecFunction { SecCodeCopySigningInformation(secStaticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &secCodeInfoCFDict) }
        guard let secCodeInfo = secCodeInfoCFDict as? [String: Any] else {
            throw CodesignCheckError.codeSignCheckFailed("CFDictionary returned empty from SecCodeCopySigningInformation")
        }
        return secCodeInfo
    }
    
    private static func codeSigningCertificates(forStaticCode secStaticCode: SecStaticCode) throws -> [SecCertificate] {
        guard
            let secCodeInfo = try secCodeInfo(forStaticCode: secStaticCode),
            let secCertificates = secCodeInfo[kSecCodeInfoCertificates as String] as? [SecCertificate] else { return [] }
        return secCertificates
    }
}
