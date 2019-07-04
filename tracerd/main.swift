//
//  main.swift
//  tracerd
//
//  Created by Scott Knight on 7/4/19.
//  Copyright © 2019 Scott Knight. All rights reserved.
//

import Foundation

autoreleasepool {
    IPCConnection.shared.startListener()
}

dispatchMain()
