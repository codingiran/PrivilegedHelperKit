//
//  PrivilegedHelperManager+.swift
//  PrivilegedHelperKit
//
//  Created by CodingIran on 2025/1/2.
//

import AppKit.NSPasteboard
import Foundation
import PrivilegedHelperKit
import ServiceManagement

public extension PrivilegedHelperManager {
    protocol HelperDelegate: PrivilegedHelperDelegate {
        func sharedDirectory(of helperManager: PrivilegedHelperManager) -> String?
        func supportUnInstallHelperVersion(of helperManager: PrivilegedHelperManager) -> PrivilegedHelperVersion
        func helperManager(_ manager: PrivilegedHelperManager, xpcDisconnect reason: XPCDisconnectReason)
        func helperManager(_ manager: PrivilegedHelperManager, didInstalledForUpdate: Bool, isLegacy: Bool, didTryCount: Int)
        @MainActor func showTextAlert(_ text: String) async
        @MainActor func showLoginItemAlert() async -> HelperLoginItemAlertResult
        @MainActor func showInstallHelperAlert() async -> HelperInstallAlertResult
        @MainActor func showInstallLegacyHelperAlert() async -> HelperLegacyInstallAlertResult
    }
}

public extension PrivilegedHelperManager {
    enum XPCDisconnectReason: Sendable {
        case connectInvalid
        case connectInterrupt
    }
}

public extension PrivilegedHelperManager {
    enum HelperLoginItemAlertResult: Sendable {
        case openSystemSettings
        case resetDaemon
    }

    enum HelperInstallAlertResult: Sendable {
        case install
        case cancel
        case quit
    }

    enum HelperLegacyInstallAlertResult: Sendable {
        case confirm
        case cancel
    }
}

public extension PrivilegedHelperManager {
    enum HelperStatus: Sendable {
        case installed
        case notFound
        case needUpdate(_ needUnInstall: Bool)
        @available(macOS 13.0, *)
        case requiresApproval

        public var isInstalled: Bool {
            switch self {
            case .installed:
                return true
            default:
                return false
            }
        }
    }
}

// MARK: - Log

extension PrivilegedHelperManager: PrivilegedHelperKit.Loggable {
    public func log(_ level: PrivilegedHelperKit.LogLevel, _ message: any PrivilegedHelperKit.LogMessaging) {
        delegate?.didOutputLog(level: level, message: message.logString)
    }
}

public extension PrivilegedHelperManager {
    enum DaemonInstallResult: Sendable {
        case success
        case authorizationFail
        case getAdminFail
        case blessError(_ code: Int, _ machServiceName: String)

        public var alertContent: String {
            switch self {
            case .success:
                return ""
            case .authorizationFail: return "Failed to create authorization!"
            case .getAdminFail: return "Failed to get admin authorization!"
            case let .blessError(code, machServiceName):
                switch code {
                case kSMErrorInternalFailure: return "blessError: kSMErrorInternalFailure"
                case kSMErrorInvalidSignature: return "blessError: kSMErrorInvalidSignature"
                case kSMErrorAuthorizationFailure: return "blessError: kSMErrorAuthorizationFailure"
                case kSMErrorToolNotValid: return "blessError: kSMErrorToolNotValid"
                case kSMErrorJobNotFound: return "blessError: kSMErrorJobNotFound"
                case kSMErrorServiceUnavailable: return "blessError: kSMErrorServiceUnavailable"
                case kSMErrorJobNotFound: return "blessError: kSMErrorJobNotFound"
                case kSMErrorJobMustBeEnabled: return "Privileged Helper is disabled by other process. Please run \"sudo launchctl enable system/\(machServiceName)\" in your terminal. The command has been copied to your pasteboard"
                case kSMErrorInvalidPlist: return "blessError: kSMErrorInvalidPlist"
                default:
                    return "bless unknown error:\(code)"
                }
            }
        }

        public func shouldRetryLegacyWay() -> Bool {
            switch self {
            case .success: return false
            case let .blessError(code, _):
                switch code {
                case kSMErrorJobMustBeEnabled:
                    return false
                default:
                    return true
                }
            default:
                return true
            }
        }

        @MainActor
        public func alertAction() {
            switch self {
            case let .blessError(code, machServiceName):
                switch code {
                case kSMErrorJobMustBeEnabled:
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("sudo launchctl enable system/\(machServiceName)", forType: .string)
                default:
                    break
                }
            default:
                break
            }
        }
    }
}

public extension PrivilegedHelperManager {
    enum HelperError: LocalizedError, Sendable {
        case delegateNotProvided
        case authorizationFailed(OSStatus)
        case machServiceNameNotProvided
        case workingDirectoryNotProvided
        case helperProxyCreateFailed
        case runnerBundleVersionEmpty

        public var errorDescription: String? {
            switch self {
            case .delegateNotProvided:
                return "Delegate not provided"
            case let .authorizationFailed(status):
                return "Authorization failed with status: \(status)"
            case .machServiceNameNotProvided:
                return "MachServiceName not provided"
            case .workingDirectoryNotProvided:
                return "Working directory not provided"
            case .helperProxyCreateFailed:
                return "Failed to create helper proxy"
            case .runnerBundleVersionEmpty:
                return "Runner bundle version is empty"
            }
        }
    }
}

@globalActor
public enum PrivilegedHelperManagerXPCActor {
    public actor TheActor {}
    public static let shared = TheActor()
}
