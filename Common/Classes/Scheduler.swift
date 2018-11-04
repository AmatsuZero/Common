//
//  Scheduler.swift
//  Common
//
//  Created by Jiang,Zhenhua on 2018/11/4.
//

import Foundation
import Socket

class SocketEvent {
    
    let port: Int
    var listenSocket: Socket? = nil
    var continueRunning = true
    var connectedSockets = [Int32: SocketWrapper]()
    let socketLockQueue = DispatchQueue(label:"com.dabuert.nintendoclients.Common.SocketEvent")
    
    init(port: Int) {
        self.port = port
    }
    
    
    
    deinit {
        // Close all open sockets...
        for socket in connectedSockets.values {
            socket.close()
        }
        self.listenSocket?.close()
    }
}
