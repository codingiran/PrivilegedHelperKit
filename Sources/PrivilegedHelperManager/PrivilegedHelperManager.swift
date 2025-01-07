import AppleExtension
import Foundation
import PrivilegedHelperKit
import ScriptRunner
import Security
import ServiceManagement

open class PrivilegedHelperManager: NSObject {
    public var delegate: PrivilegedHelperManager.HelperDelegate?
    private var auth: AuthorizationRef?
    private let machServiceName: String
    private let mainAppBundleIdentifier: String
    private var cancelInstallCheck = false
    private var connection: NSXPCConnection? {
        willSet {
            if newValue == nil {
                connection?.invalidate()
            }
        }
    }

    public func getPrivilegedHelperProxy(completion: @escaping (Result<AnyObject, Error>) -> Void) {
        Task {
            let proxy = try await self.helperProxy
            completion(.success(proxy))
        } catch: { error in
            completion(.failure(error))
        }
    }

    /// Initialize PrivilegedHelperManager
    /// - Parameters:
    ///   - machServiceName: XPC Service Name
    ///   - mainAppBundleIdentifier: Main App Bundle Identifier
    public required init(machServiceName: String, mainAppBundleIdentifier: String) {
        self.machServiceName = machServiceName
        self.mainAppBundleIdentifier = mainAppBundleIdentifier
        super.init()
        do {
            try initAuthorizationRef()
        } catch {
            log(.error, "initAuthorizationRef failed: \(error.localizedDescription)")
        }
    }

    deinit {
        auth = nil
        connection = nil
    }

    /// Initialize AuthorizationRef
    private func initAuthorizationRef() throws {
        let status = AuthorizationCreate(nil, nil, AuthorizationFlags(), &auth)
        guard status == errAuthorizationSuccess else {
            throw PrivilegedHelperManager.HelperError.authorizationFailed(status)
        }
    }

    /// Check helper status
    public func getHelperStatus() async -> HelperStatus {
        if #available(macOS 13.0, *),
           let url = URL(string: "/Library/LaunchDaemons/\(machServiceName).plist")
        {
            let status = SMAppService.statusForLegacyPlist(at: url)
            if status == .requiresApproval {
                log(.warning, "Check helper status failed: requiresApproval")
                return .requiresApproval
            }
        }
        let helperURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchServices/" + machServiceName)
        guard
            let helperBundleInfo = CFBundleCopyInfoDictionaryForURL(helperURL as CFURL) as? [String: Any],
            let bundleIdentifier = helperBundleInfo["CFBundleIdentifier"] as? String,
            let bundleShortVersion = helperBundleInfo["CFBundleShortVersionString"] as? String,
            let bundleVersion = helperBundleInfo["CFBundleVersion"] as? String
        else {
            log(.error, "Check helper status failed: notFound")
            return .notFound
        }
        let helperBundleVersion = PrivilegedHelperVersion(bundleIdentifier: bundleIdentifier, bundleVersion: bundleVersion, bundleShortVersion: bundleShortVersion)
        let helperFileExists = FileManager.default.fileExists(atPath: "/Library/PrivilegedHelperTools/\(machServiceName)")
        if !helperFileExists {
            log(.error, "Check helper status failed: notFound")
            return .notFound
        }

        let timeout: TimeInterval = 2
        let time = Date()
        do {
            let task = Task.detached(timeout: timeout) {
                let version = try await self.getHelperVersion()
                return version
            }
            let helperFileVersion = try await task.value
            log(.info, "current helper file version is \(helperFileVersion.description), require version \(helperBundleVersion.description)")
            let versionMatch = helperFileVersion.isEqual(helperBundleVersion)
            let interval = Date().timeIntervalSince(time)
            let supportUnInstallHelperVersion = delegate?.supportUnInstallHelperVersion(of: self)
            let supportUnInstall: Bool = {
                guard let supportUnInstallHelperVersion else {
                    return false
                }
                return helperFileVersion.isGreaterThanOrEqualTo(supportUnInstallHelperVersion)
            }()
            log(.info, "check helper using time: \(interval)")
            return versionMatch ? .installed : .needUpdate(supportUnInstall)
        } catch {
            // 超时
            log(.info, "check helper using time: \(timeout)")
            return .notFound
        }
    }

    /// Get helper version from xpc endpoint
    public func getHelperVersion() async throws -> PrivilegedHelperVersion {
        let proxy = try await helperProxy
        guard let sharedDirectory = delegate?.sharedDirectory(of: self) else {
            throw PrivilegedHelperManager.HelperError.workingDirectoryNotProvided
        }
        return try await withCheckedThrowingContinuation { cont in
            proxy.getHelperVersion(sharedDirectory: sharedDirectory) { version in
                guard let version else {
                    cont.resume(throwing: PrivilegedHelperManager.HelperError.runnerBundleVersionEmpty)
                    return
                }
                cont.resume(returning: version)
            }
        }
    }

    /// Check helper install
    public func checkHelperInstall() async -> Bool {
        log(.debug, "checking helper install")
        return await isHelperInstalled()
    }

    /// Check helper is installed or not
    private func isHelperInstalled(didTryCount: Int = 0, afterUpdate: Bool = false, isLegacy: Bool = false) async -> Bool {
        do {
            let status = try await getHelperStatus()
            var isUpdate = false
            switch status {
            case .requiresApproval:
                if #available(macOS 13.0, *) {
                    if let result = await delegate?.showLoginItemAlert() {
                        switch result {
                        case .openSystemSettings:
                            SMAppService.openSystemSettingsLoginItems()
                        case .resetDaemon:
                            await removeInstallHelper()
                        }
                    }
                }
                return false
            case let .needUpdate(needUnInstall):
                isUpdate = true
                if needUnInstall {
                    log(.info, "helper need update, uninstall older")
                    await uninstallHelper()
                } else {
                    log(.info, "helper need update, kill older")
                    await killHelper()
                }
                fallthrough
            case .notFound:
                log(.info, "helper need install")
                if didTryCount > 0 {
                    if await notifyLegacyInstall() {
                        return await isHelperInstalled(didTryCount: didTryCount + 1, afterUpdate: isUpdate, isLegacy: true)
                    }
                } else {
                    if await notifyInstall() {
                        return await isHelperInstalled(didTryCount: didTryCount + 1, afterUpdate: isUpdate, isLegacy: false)
                    }
                }
                return false
            case .installed:
                log(.info, "helper is installed")
                Task { @MainActor in
                    self.delegate?.helperManager(self, didInstalledForUpdate: afterUpdate, isLegacy: isLegacy, didTryCount: didTryCount)
                }
                return true
            }
        } catch {
            log(.error, "check helper status failed: \(error.localizedDescription)")
            return false
        }
    }

    private func notifyInstall() async -> Bool {
        guard await showInstallHelperAlert() else {
            exit(EXIT_SUCCESS)
        }
        if cancelInstallCheck {
            return false
        }
        let result = installHelperDaemon()
        if case .success = result {
            return true
        }
        result.alertAction()
        await delegate?.showTextAlert(result.alertContent)
        return false
    }

    private func installHelperDaemon() -> PrivilegedHelperManager.DaemonInstallResult {
        log(.info, "instating HelperDaemon")

        defer {
            connection = nil
        }

        // Create authorization reference for the user
        var authRef: AuthorizationRef?
        var authStatus = AuthorizationCreate(nil, nil, [.preAuthorize], &authRef)

        // Check if the reference is valid
        guard authStatus == errAuthorizationSuccess else {
            log(.error, "authorization failed: \(authStatus)")
            return .authorizationFail
        }

        // Ask user for the admin privileges to install the
        var authItem = kSMRightBlessPrivilegedHelper.withCString {
            AuthorizationItem(name: $0, valueLength: 0, value: nil, flags: 0)
        }
        var authRights = withUnsafeMutablePointer(to: &authItem) {
            AuthorizationRights(count: 1, items: $0)
        }
        let flags: AuthorizationFlags = [.interactionAllowed, .preAuthorize, .extendRights]
        authStatus = AuthorizationCreate(&authRights, nil, flags, &authRef)
        defer {
            if let ref = authRef {
                AuthorizationFree(ref, [])
            }
        }
        // Check if the authorization went succesfully
        guard authStatus == errAuthorizationSuccess else {
            log(.error, "couldn't obtain admin privileges: \(authStatus)")
            return .getAdminFail
        }

        // Launch the privileged helper using SMJobBless tool
        var error: Unmanaged<CFError>?
        if SMJobBless(kSMDomainSystemLaunchd, machServiceName as CFString, authRef, &error) == false {
            let blessError = error!.takeRetainedValue() as Swift.Error
            log(.error, "bless Error: \(blessError)")
            return .blessError((blessError as NSError).code, machServiceName)
        }

        log(.info, "\(machServiceName) installed successfully")
        return .success
    }

    @MainActor
    private func showInstallHelperAlert() async -> Bool {
        guard let delegate else {
            return false
        }
        let result = await delegate.showInstallHelperAlert()
        switch result {
        case .install:
            cancelInstallCheck = false
            return true
        case .cancel:
            cancelInstallCheck = true
            log(.error, "User refused to install privileges helper")
            return true
        case .quit:
            return false
        }
    }

    /// Uninstall helper
    private func uninstallHelper() async {
        guard let proxy = try? await helperProxy else { return }
        proxy.uninstall()
        try? await Task.sleep(seconds: 0.1)
    }

    /// Kill helper
    private func killHelper() async {
        if let proxy = try? await helperProxy {
            proxy.exitProcess()
        }
        try? await Task.sleep(seconds: 0.1)
    }
}

// MARK: - Legacy

private extension PrivilegedHelperManager {
    func legacyInstallHelper() async throws {
        let script = getInstallScript()
        try ScriptRunner().runScriptWithRootPermission(script: script)
        connection = nil
        try? await Task.sleep(seconds: 0.5)
    }

    func removeInstallHelper(waitInterval: TimeInterval = 3) async {
        let machServiceName = machServiceName
        let script = """
        launchctl remove \(machServiceName) || true
        rm -rf /Library/LaunchDaemons/\(machServiceName).plist
        rm -rf /Library/PrivilegedHelperTools/\(machServiceName)
        """
        do {
            try ScriptRunner().runScriptWithRootPermission(script: script)
            connection = nil
            try await Task.sleep(seconds: waitInterval)
        } catch {
            log(.error, "remove InstallHelper failed: \(error.localizedDescription)")
        }
    }

    func notifyLegacyInstall() async -> Bool {
        await showInstallLegacyHelperAlert()
        if cancelInstallCheck {
            return false
        }
        do {
            try await legacyInstallHelper()
            return true
        } catch {
            await delegate?.showTextAlert(error.localizedDescription)
            return false
        }
    }

    @MainActor
    func showInstallLegacyHelperAlert() async {
        guard let delegate else { return }
        let result = await delegate.showInstallLegacyHelperAlert()
        switch result {
        case .confirm:
            cancelInstallCheck = false
        case .cancel:
            cancelInstallCheck = true
        }
    }

    func getInstallScript() -> String {
        let mainAppBundleId = mainAppBundleIdentifier
        let machServiceName = self.machServiceName
        let appPath = Bundle.main.bundlePath
        let bash = """
        #!/bin/bash
        set -e

        plistPath=/Library/LaunchDaemons/\(machServiceName).plist
        rm -rf /Library/PrivilegedHelperTools/\(machServiceName)
        if [ -e ${plistPath} ]; then
        launchctl unload -w ${plistPath}
        rm ${plistPath}
        fi
        launchctl remove \(machServiceName) || true

        mkdir -p /Library/PrivilegedHelperTools/
        rm -f /Library/PrivilegedHelperTools/\(machServiceName)

        cp "\(appPath)/Contents/Library/LaunchServices/\(machServiceName)" "/Library/PrivilegedHelperTools/\(machServiceName)"

        echo '
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>AssociatedBundleIdentifiers</key>
            <string>\(mainAppBundleId)</string>
            <key>KeepAlive</key>
            <dict>
                <key>SuccessfulExit</key>
                <false/>
            </dict>
            <key>Label</key>
            <string>\(machServiceName)</string>
            <key>MachServices</key>
            <dict>
                <key>\(machServiceName)</key>
                <true/>
            </dict>
            <key>Program</key>
            <string>/Library/PrivilegedHelperTools/\(machServiceName)</string>
            <key>ProgramArguments</key>
            <array>
                <string>/Library/PrivilegedHelperTools/\(machServiceName)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
        </dict>
        </plist>
        ' > ${plistPath}

        launchctl load -w ${plistPath}
        """
        return bash
    }
}

// MARK: - XPC

private extension PrivilegedHelperManager {
    var helperProxy: PrivilegedHelperXPCProtocol {
        get async throws {
            return try await withCheckedThrowingContinuation { [weak self] cont in
                guard let self else {
                    cont.resume(throwing: PrivilegedHelperManager.HelperError.helperProxyCreateFailed)
                    return
                }
                getHelperProxy { proxy in
                    guard let proxy else {
                        cont.resume(throwing: PrivilegedHelperManager.HelperError.helperProxyCreateFailed)
                        return
                    }
                    cont.resume(returning: proxy)
                }
            }
        }
    }

    func getHelperProxy(result: @escaping ((PrivilegedHelperXPCProtocol?) -> Void)) {
        guard let connection = createConnection() else {
            result(nil)
            return
        }
        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ [weak self] error in
            self?.connection = nil
            self?.log(.error, "failed to get proxy: \(error.localizedDescription)")
        }) as? PrivilegedHelperXPCProtocol else {
            log(.error, "failed to get proxy: can not convert to PrivilegedHelperXPCProtocol")
            result(nil)
            return
        }
        result(proxy)
    }

    func createConnection() -> NSXPCConnection? {
        if let connection = connection {
            return connection
        }
        guard let delegate else {
            return nil
        }
        let newConnection = NSXPCConnection(machServiceName: machServiceName, options: .privileged)
        newConnection.exportedObject = self
        newConnection.remoteObjectInterface = NSXPCInterface(with: delegate.xpcInterfaceProtocol())
        newConnection.invalidationHandler = { [weak self] in
            self?.connection?.invalidationHandler = nil
            OperationQueue.main.addOperation {
                self?.connection = nil
                self?.log(.error, "XPC Connection Invalidated")
            }
            self?.handXPCDisconnect(reason: .connectInvalid)
        }
        newConnection.interruptionHandler = { [weak self] in
            self?.log(.error, "XPC Connection Interrupted - the Helper probably exits or crashes. (If crash, You might find a crash report at /Library/Logs/DiagnosticReports)")
            self?.handXPCDisconnect(reason: .connectInterrupt)
        }
        connection = newConnection
        newConnection.resume()
        return newConnection
    }

    func handXPCDisconnect(reason: XPCDisconnectReason) {
        delegate?.helperManager(self, xpcDisconnect: reason)
    }
}
