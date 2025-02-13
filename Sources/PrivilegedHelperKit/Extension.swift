//
//  Extension.swift
//  PrivilegedHelperKit
//
//  Created by CodingIran on 2025/2/13.
//

import Foundation

public extension NSXPCConnection {
    func getRemoteObjectProxy<T>(_ handler: @escaping (any Error) -> Void) -> T? {
        guard let proxy = remoteObjectProxyWithErrorHandler({ error in
            handler(error)
        }) as? T else {
            return nil
        }
        return proxy
    }
}
