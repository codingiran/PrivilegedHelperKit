import Foundation

// Enforce minimum Swift version for all platforms and build systems.
#if swift(<5.5)
#error("PrivilegedHelperKit doesn't support Swift versions below 5.5.")
#endif

/// Current PrivilegedHelperKit version 0.1.6. Necessary since SPM doesn't use dynamic libraries. Plus this will be more accurate.
let version = "0.1.6"

public enum PrivilegedHelperKit: Sendable {}
