# PrivilegedHelperKit

A Swift framework for managing privileged helpers on macOS, providing a comprehensive set of APIs for installation, management, and communication with privileged helpers.

## Features

- Easy-to-use API interface
- Support for privileged helper installation and uninstallation
- Version checking and updates
- Secure XPC-based communication
- Support for both legacy and modern installation methods
- Complete error handling and logging
- Type-safe API design

## Requirements

- macOS 10.15 +
- Swift 5.10 +
- Xcode 15.4 +

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/codingiran/PrivilegedHelperKit.git", from: "0.0.8")
]
```

## Usage

### 1. Initialize the Manager

```swift
let manager = PrivilegedHelperManager(
machServiceName: "com.example.helper",
mainAppBundleIdentifier: "com.example.app"
)
manager.delegate = self
```

### 2. Check Installation Status

```swift
let status = await manager.getHelperStatus()
switch status {
case .installed:
    print("Helper is installed")
case .notFound:
    print("Helper not found")
case .needUpdate(let supportUnInstall):
    print("Helper needs update")
case .requiresApproval:
    print("Helper requires approval")
}
```

### 3. Install the Privileged Helper

```swift
let isInstalled = await manager.checkHelperInstall()
if isInstalled {
    print("Helper installed successfully")
}
```

### 4. Communicate with the Helper

```swift
let proxy = try await manager.getPrivilegedHelperProxy()
let version = try await manager.getHelperVersion()
```

## Implementation Details

### PrivilegedHelperManager
- Manages the lifecycle of the privileged helper
- Handles installation, updates, and communication
- Provides version checking and status monitoring
- Manages XPC connections securely

### PrivilegedHelperRunner
- Implements the helper process functionality
- Manages XPC listener and connections
- Handles helper termination and cleanup
- Provides uninstallation capabilities

## Security Considerations

- Proper code signing and authorization requirements must be configured
- User authorization is required for installation
- Review Apple's security guidelines before implementation
- Ensure proper entitlements are configured

## Best Practices

1. Always check helper status before operations
2. Handle installation errors appropriately
3. Implement proper logging for debugging
4. Follow Apple's security guidelines
5. Maintain version compatibility

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## Author

CodingIran@gmail.com 

## Acknowledgments

Free free to use and modify.