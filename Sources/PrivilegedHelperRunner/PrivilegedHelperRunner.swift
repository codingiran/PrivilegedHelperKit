import Foundation
import os.log
@_exported import PrivilegedHelperKit

open class PrivilegedHelperRunner: NSObject, @unchecked Sendable {
    public var delegate: PrivilegedHelperRunner.RunnerDelegate?
    private let machServiceName: String
    private let bundleIdentifier: String
    private var listener: NSXPCListener
    private var connections = [NSXPCConnection]()
    private var shouldQuit: Bool = false
    private var shouldQuitCheckInterval = 1.0

    public init(machServiceName: String, helperBundleIdentifier: String) {
        os_log("Privileged Helper init")
        self.machServiceName = machServiceName
        self.bundleIdentifier = helperBundleIdentifier
        self.listener = NSXPCListener(machServiceName: machServiceName)
        super.init()
        listener.delegate = self
    }

    deinit {
        os_log("Privileged Helper deinit")
        listener.invalidate()
    }

    public func run() {
        os_log("Privileged Helper has started")
        checkUninstallCommand()
        checkHelperRunning()
        listener.resume()
        while !shouldQuit {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: shouldQuitCheckInterval))
        }
        os_log("Privileged Helper exit runLoop")
        Self.isHelperRunning = false
    }

    @objc func connectionCheckOnLaunch() {
        guard connections.isEmpty else {
            return
        }
        if shoulQuitWhenXPCDisconnect {
            os_log("Privileged Helper XPC connection empty, should quit as burial offering")
            log(.debug, "Privileged Helper XPC connection empty, should quit as burial offering")
            shouldQuit = true
        } else {
            os_log("Privileged Helper XPC connection empty, keep running as Daemon")
            log(.debug, "Privileged Helper XPC connection empty, keep running as Daemon")
        }
    }

    private var shoulQuitWhenXPCDisconnect: Bool {
        guard let delegate else { return false }
        return delegate.shoulQuitWhenXpcDisconnect(of: self)
    }
}

public extension PrivilegedHelperRunner {
    func getPrivilegedHelperProxy<T>() async throws -> T where T: PrivilegedHelperXPCProtocol {
        guard let connection = connections.first else {
            throw PrivilegedHelperKit.XPCError.xpcConnectionCreateFailed
        }
        let proxy: T = try connection.getRemoteObjectProxy { [weak self] error in
            self?.log(.error, "Privileged Helper XPC getRemoteObjectProxy failed: \(error.localizedDescription)")
        }
        return proxy
    }
}

extension PrivilegedHelperRunner: NSXPCListenerDelegate {
    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        if case .failure(let error) = PrivilegedHelperKit.checkConnectionCodesign(newConnection) {
            log(.error, "drop connection for \(error.localizedDescription)")
            return false
        }
        guard let delegate else {
            log(.error, "drop connection for no delegate")
            return false
        }
        newConnection.exportedInterface = NSXPCInterface(with: delegate.xpcInterfaceProtocol())
        newConnection.exportedObject = self
        newConnection.remoteObjectInterface = NSXPCInterface(with: delegate.xpcInterfaceProtocol())
        newConnection.invalidationHandler = { [weak self] in
            self?.handXPCConnectionBehavior(.invalid)
            if let connectionIndex = self?.connections.firstIndex(of: newConnection) {
                self?.connections.remove(at: connectionIndex)
            }
            self?.connectionCheckOnLaunch()
        }
        newConnection.interruptionHandler = { [weak self] in
            self?.handXPCConnectionBehavior(.interrupt)
        }
        connections.append(newConnection)
        handXPCConnectionBehavior(.established)
        newConnection.resume()
        return true
    }

    private func handXPCConnectionBehavior(_ behavior: PrivilegedHelperKit.XPCConnectionBehavior) {
        switch behavior {
        case .established:
            os_log("Privileged Helper XPC connection established")
        case .invalid:
            os_log("Privileged Helper XPC connection invalided")
            log(.debug, "Privileged Helper XPC connection invalided")
        case .interrupt:
            os_log("Privileged Helper XPC connection invalided Interrupted")
            log(.debug, "Privileged Helper XPC connection invalided Interrupted")
        }
        delegate?.helperRunner(self, xpcConnectionActing: behavior)
    }
}

// MARK: - PrivilegedHelperXPCProtocol

extension PrivilegedHelperRunner: PrivilegedHelperXPCProtocol {
    public func getHelperVersion(sharedDirectory: String, resultBack: ((PrivilegedHelperVersion?) -> Void)?) {
        let version = delegate?.helperVersion(of: self, sharedDirectory: sharedDirectory)
        log(.debug, "Privileged Helper's version is \(version?.description ?? "null")")
        resultBack?(version)
    }

    public func exitProcess() {
        log(.debug, "Privileged Helper exitProcess")
        exit(EXIT_SUCCESS)
    }

    public func uninstall() {
        let process = Process()
        process.launchPath = "/Library/PrivilegedHelperTools/\(bundleIdentifier)"
        process.qualityOfService = QualityOfService.utility
        process.arguments = ["uninstall", String(getpid())]
        process.launch()
        exit(EXIT_SUCCESS)
    }
}

// MARK: - Uninstall

private extension PrivilegedHelperRunner {
    private func checkUninstallCommand() {
        let args = CommandLine.arguments.dropFirst()
        guard !args.isEmpty, args.first == "uninstall" else { return }
        os_log("Privileged detected uninstall command")
        if let val = args.last, let pid: pid_t = Int32(val) {
            while kill(pid, 0) == 0 {
                usleep(50000)
            }
        }
        Self.isHelperRunning = false
        uninstallHelper()
        exit(EXIT_SUCCESS)
    }

    private func uninstallHelper() {
        let process = Process()
        process.launchPath = "/bin/launchctl"
        process.qualityOfService = QualityOfService.utility
        process.arguments = ["unload", "/Library/LaunchDaemons/\(bundleIdentifier).plist"]
        process.launch()
        process.waitUntilExit()

        if process.terminationStatus != .zero {
            if #available(macOS 11.0, *) { os_log("Privileged termination code: \(process.terminationStatus)") }
        }
        os_log("Privileged unloaded from launchctl")
        do {
            try FileManager.default.removeItem(at: URL(fileURLWithPath: "/Library/LaunchDaemons/\(bundleIdentifier).plist"))
        } catch {
            if #available(macOS 11.0, *) { os_log("Privileged Helper plist deletion: \(error.localizedDescription)") }
        }
        os_log("Privileged helper property list deleted")
        do {
            try FileManager.default.removeItem(at: URL(fileURLWithPath: "/Library/PrivilegedHelperTools/\(bundleIdentifier)"))
        } catch {
            if #available(macOS 11.0, *) { os_log("Privileged Helper deletion: \(error.localizedDescription)") }
        }
        os_log("Privileged Helper deleted")
    }
}

// MARK: - Record Quit State

private extension PrivilegedHelperRunner {
    static let isHelperRunningKey = "isHelperRunning"

    /// 记录退出状态
    static var isHelperRunning: Bool {
        get {
            UserDefaults.standard.bool(forKey: isHelperRunningKey)
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: isHelperRunningKey)
        }
    }

    /// 检查上次退出状态
    func checkHelperRunning() {
        DispatchQueue.global().async {
            defer {
                Self.isHelperRunning = true
            }
            guard Self.isHelperRunning else {
                os_log("Privileged Helper last quit normally")
                return
            }
            os_log("Privileged Helper last quit abnormally")
        }
    }
}
