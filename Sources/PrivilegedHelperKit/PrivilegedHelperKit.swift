import Foundation

// Enforce minimum Swift version for all platforms and build systems.
#if swift(<5.9)
#error("PrivilegedHelperKit doesn't support Swift versions below 5.9.")
#endif

/// Current PrivilegedHelperKit version 0.1.7. Necessary since SPM doesn't use dynamic libraries. Plus this will be more accurate.
let version = "0.1.7"

public enum PrivilegedHelperKit: Sendable {}

public extension PrivilegedHelperKit {
    enum XPCError: LocalizedError, Sendable {
        case xpcConnectionCreateFailed
        case helperProxyCreateFailed
        case helperProxyCastTypeFailed(String)

        public var errorDescription: String? {
            switch self {
            case .xpcConnectionCreateFailed:
                return "Failed to create XPC connection"
            case .helperProxyCreateFailed:
                return "Failed to create helper proxy"
            case let .helperProxyCastTypeFailed(typeName):
                return "Failed to cast helper proxy to \(typeName)"
            }
        }
    }

    enum XPCConnectionBehavior: Sendable, CustomStringConvertible {
        case established
        case invalid
        case interrupt

        public var description: String {
            switch self {
            case .established:
                return "established"
            case .invalid:
                return "invalid"
            case .interrupt:
                return "interrupt"
            }
        }
    }
}
