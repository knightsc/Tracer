//
//  IPCConnection.swift
//  tracerd
//
//  Created by Scott Knight on 7/4/19.
//  Copyright © 2019 Scott Knight. All rights reserved.
//

import Foundation
import os.log

let tracerdIPCLog = OSLog.init(subsystem: "sc.knight.Tracer.tracerd", category: "IPC")

@objc protocol ProviderCommunication {
    
    func register(_ completionHandler: @escaping (Bool) -> Void)
}

/// Provider --> App IPC
@objc protocol AppCommunication {
    
    func exec(file: String)
}

class IPCConnection: NSObject {
    
    // MARK: Properties
    
    var listener: NSXPCListener?
    var currentConnection: NSXPCConnection?
    weak var delegate: AppCommunication?
    static let shared = IPCConnection()
    
    // MARK: Methods
    
    private func extensionMachServiceName(from bundle: Bundle) -> String {
        
        guard let identifier = bundle.bundleIdentifier else {
            fatalError("Bundle identifier is missing from the Info.plist")
        }
        
        return "<TEAMID>." + identifier + ".xpc"
    }
    
    func startListener() {
        
        let machServiceName = extensionMachServiceName(from: Bundle.main)
        os_log("Starting XPC listener for mach service %@", log: tracerdIPCLog, type: .info, machServiceName)
        
        let newListener = NSXPCListener(machServiceName: machServiceName)
        newListener.delegate = self
        newListener.resume()
        listener = newListener
    }
    
    /// This method is called by the app to register with the provider running in the system extension.
    func register(withExtension bundle: Bundle, delegate: AppCommunication, completionHandler: @escaping (Bool) -> Void) {
        
        self.delegate = delegate
        
        guard currentConnection == nil else {
            os_log("Already registered with the provider", log: tracerdIPCLog, type: .error)
            completionHandler(true)
            return
        }
        
        let machServiceName = extensionMachServiceName(from: bundle)
        let newConnection = NSXPCConnection(machServiceName: machServiceName, options: [])
        
        // The exported object is the delegate.
        newConnection.exportedInterface = NSXPCInterface(with: AppCommunication.self)
        newConnection.exportedObject = delegate
        
        // The remote object is the provider's IPCConnection instance.
        newConnection.remoteObjectInterface = NSXPCInterface(with: ProviderCommunication.self)
        
        currentConnection = newConnection
        newConnection.resume()
        
        guard let providerProxy = newConnection.remoteObjectProxyWithErrorHandler({ registerError in
            os_log("Failed to register with the provider: %@", log: tracerdIPCLog, type: .error, registerError.localizedDescription)
            self.currentConnection?.invalidate()
            self.currentConnection = nil
            completionHandler(false)
        }) as? ProviderCommunication else {
            fatalError("Failed to create a remote object proxy for the provider")
        }
        
        providerProxy.register(completionHandler)
    }
    
    func exec(file : String) {
        guard let connection = currentConnection else {
            os_log("Cannot send log because the app isn't registered", log: tracerdIPCLog, type: .error)
            return
        }
        
        guard let appProxy = connection.remoteObjectProxyWithErrorHandler({ promptError in
            os_log("Failed to send log: %@", log: tracerdIPCLog, type: .error, promptError.localizedDescription)
            self.currentConnection = nil
            return
        }) as? AppCommunication else {
            fatalError("Failed to create a remote object proxy for the app")
        }
        
        appProxy.exec(file: file)
    }
}

extension IPCConnection: NSXPCListenerDelegate {
    
    // MARK: NSXPCListenerDelegate
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        
        // The exported object is this IPCConnection instance.
        newConnection.exportedInterface = NSXPCInterface(with: ProviderCommunication.self)
        newConnection.exportedObject = self
        
        // The remote object is the delegate of the app's IPCConnection instance.
        newConnection.remoteObjectInterface = NSXPCInterface(with: AppCommunication.self)
        
        newConnection.invalidationHandler = {
            self.currentConnection = nil
        }
        
        newConnection.interruptionHandler = {
            self.currentConnection = nil
        }
        
        currentConnection = newConnection
        newConnection.resume()
        
        return true
    }
}

extension IPCConnection: ProviderCommunication {
    
    // MARK: ProviderCommunication
    
    func register(_ completionHandler: @escaping (Bool) -> Void) {
        
        os_log("App registered", log: tracerdIPCLog, type: .info)
        completionHandler(true)
    }
}
