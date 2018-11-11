//
//  Scheduler.swift
//  Common
//
//  Created by Jiang,Zhenhua on 2018/11/4.
//

import Foundation
import Socket

open class SocketEvent {
    
    static let shared = SocketEvent()
    
    enum SocketEventError: CustomNSError {
        case receive(String)
        
        public static var errorDomain: String {
            return "com.dabuert.nintendoclients.Common.CStruct"
        }
        var errorCode: Int {
            switch self {
            case .receive: return -4001
            }
        }
        
        var errorUserInfo: [String : Any] {
            switch self {
            case .receive(let msg):
                return [NSLocalizedDescriptionKey: msg]
            }
        }
    }
    
    private lazy var runLoop: RunLoop = {
        let runLoop = RunLoop()
        return runLoop
    }()
    
    var listenSocket: Socket? = nil
    var continueRunning = true
    var connectedSockets = [Int32: SocketWrapper]()
    let socketLockQueue = DispatchQueue(label:"com.dabuert.nintendoclients.Common.SocketEvent")
    
    func add(socket: SocketWrapper,
             handler: @escaping (SocketWrapper) -> Bool) {
        // Add the new socket to the list of connected sockets...
        socketLockQueue.sync { [unowned self, socket] in
            self.connectedSockets[socket.socket.socketfd] = socket
        }
        // Get the global concurrent queue...
        let queue = DispatchQueue.global(qos: .default)
        
        // Create the run loop work item and dispatch to the default priority global queue...
        queue.async {
            var shouldKeepRunning = true
            repeat {
                shouldKeepRunning = handler(socket)
            } while shouldKeepRunning
            self.removeEvents()
        }
        print("Socket: \(socket.socket.remoteHostname):\(socket.socket.remotePort) closed...")
        socket.close()
        
        self.socketLockQueue.sync { [unowned self, socket] in
            self.connectedSockets[socket.socket.socketfd] = nil
        }
    }
    
    func removeEvents() {
        // Close all open sockets...
        for socket in connectedSockets.values {
            socket.close()
        }
        self.listenSocket?.close()
    }
    
    deinit {
        removeEvents()
    }
}
