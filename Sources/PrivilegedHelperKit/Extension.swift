//
//  Extension.swift
//  PrivilegedHelperKit
//
//  Created by CodingIran on 2025/2/13.
//

import Foundation

public extension NSXPCConnection {
    func getRemoteObjectProxy<T>(_ handler: @escaping (any Error) -> Void) throws -> T {
        guard let proxy = remoteObjectProxyWithErrorHandler({ error in
            handler(error)
        }) as? T else {
            throw PrivilegedHelperKit.XPCError.helperProxyCastTypeFailed("\(T.self)")
        }
        return proxy
    }
}
