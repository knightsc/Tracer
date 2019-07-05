//
//  ESClient.swift
//  tracerd
//
//  Created by Scott Knight on 7/4/19.
//  Copyright © 2019 Scott Knight. All rights reserved.
//

//import Foundation
import EndpointSecurity
import os.log

let tracerdESLog = OSLog.init(subsystem: "sc.knight.Tracer.tracerd", category: "EndpointSecurity")

class ESClient {
    var client: OpaquePointer?

    static let shared = ESClient()

    func connect() {        
        let res = es_new_client(&client) { (client, message) in
            if message.pointee.event_type == ES_EVENT_TYPE_NOTIFY_EXEC {
                IPCConnection.shared.exec(file: String(cString: message.pointee.event.exec.proc.file.path.data))
            }
            
            if message.pointee.action_type == ES_ACTION_TYPE_AUTH {
                let res = es_respond_auth_result(client, message, ES_AUTH_RESULT_ALLOW, false)
                if res != ES_RESPOND_RESULT_SUCCESS {
                    os_log("es_respond_auth_result failed", log: tracerdESLog, type: .error)
                }
            }
        }
        
        guard res == ES_NEW_CLIENT_RESULT_SUCCESS else {
            fatalError("Could not connect to endpoint security subsystem.")
        }
        
        if let client = client {
            os_log("Connected to endpoint security subsystem.", log: tracerdESLog, type: .info)
        
            var events = [ ES_EVENT_TYPE_NOTIFY_EXEC ]
            let ret = es_subscribe(client, &events, UInt32(events.count))
            if ret != ES_RETURN_SUCCESS {
                os_log("Failed to subscribe", log: tracerdESLog, type: .error)
            } else {
                os_log("Subscribed", log: tracerdESLog, type: .info)
            }
        }
    }
    
    func disconnect() {
        if let client = client {
            es_delete_client(client)
        }
    }
}
