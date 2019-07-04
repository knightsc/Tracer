//
//  AppDelegate.swift
//  Tracer
//
//  Created by Scott Knight on 7/4/19.
//  Copyright © 2019 Scott Knight. All rights reserved.
//

import Cocoa
import SystemExtensions
import os

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        let activationRequest = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: "sc.knight.Tracer.tracerd", queue: .main)
        activationRequest.delegate = self
        OSSystemExtensionManager.shared.submitRequest(activationRequest)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}

extension AppDelegate: OSSystemExtensionRequestDelegate {
    func extensionBundle() -> Bundle {
        
        let extensionsDirectoryURL = URL(fileURLWithPath: "Contents/Library/SystemExtensions", relativeTo: Bundle.main.bundleURL)
        let extensionURLs: [URL]
        do {
            extensionURLs = try FileManager.default.contentsOfDirectory(at: extensionsDirectoryURL,
                                                                        includingPropertiesForKeys: nil,
                                                                        options: .skipsHiddenFiles)
        } catch let error {
            fatalError("Failed to get the contents of \(extensionsDirectoryURL.absoluteString): \(error.localizedDescription)")
        }
        
        guard let extensionURL = extensionURLs.first else {
            fatalError("Failed to find any system extensions")
        }
        
        guard let extensionBundle = Bundle(url: extensionURL) else {
            fatalError("Failed to create a bundle with URL \(extensionURL.absoluteString)")
        }
        
        return extensionBundle
    }
    
    func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        os_log("sysex actionForReplacingExtension %@ %@", existing, ext)
        
        return .replace
    }
    
    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        os_log("sysex needsUserApproval")
        
    }
    
    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        os_log("sysex didFinishWithResult %@", result.rawValue)
        
        guard result == .completed else {
            os_log("Unexpected result %d for system extension request", result.rawValue)
            return
        }
        
        registerWithProvider()
    }
    
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        os_log("sysex didFailWithError %@", error.localizedDescription)
    }
    
    func registerWithProvider() {
        
        IPCConnection.shared.register(withExtension: extensionBundle(), delegate: self) { success in
            DispatchQueue.main.async {
                if success {
                    os_log("registered")
                } else {
                    os_log("failed register")
                }
            }
        }
    }
}

extension AppDelegate: AppCommunication {
    
    // MARK: AppCommunication
    
    func promptUser(responseHandler: @escaping (Bool) -> Void) {
        os_log("promptuser")
        responseHandler(true)
    }
}
