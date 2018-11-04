//
//  Signal.swift
//  Common
//
//  Created by Jiang,Zhenhua on 2018/11/4.
//

import Foundation
import Socket

public class WebSocket {
    
    enum ConnectionState: Int {
        case disconnect = 0, connecting, connected
    }
    
    enum OpCode: Int {
        case `continue` = 0, text, binary
        case disconnect = 8, ping, pong
    }
    
    enum WebSocketError: CustomNSError {
        case connect(String)
        case handleRecV(String)
        case send(String)
        
        public static var errorDomain: String {
            return "com.dabuert.nintendoclients.Common.WebSocket"
        }
        
        var errorCode: Int {
            switch self {
            case .connect: return -3001
            case .handleRecV: return -3002
            case .send: return -3003
            }
        }
        
        
    }
    
    private let shandShakeTemplate = """
    GET %s HTTP/1.1
    Host: %s
    Upgrade: websocket
    Connection: upgrade
    Sec-WebSocket-Key: NEX
    Sec-WebSocket-Version: 13
    Sec-WebSocket-Protocol: NEX

    """
    
    private var state = ConnectionState.disconnect
    private var socket: SocketWrapper?
    
    func connect(host: String, port p: Int32? = nil, timeout: UInt = 3) throws {
        guard state == .disconnect else {
            throw WebSocketError.connect("Socket was not disconnected")
        }
        
        guard let url = URL(string: host) else {
            throw WebSocketError.connect("Invalid host address: \(host)")
        }
        var port: Int32! = p
        var scheme: String! = url.scheme
        if scheme == nil {
            if let p = port {
                if !(80...443).include(p) {
                    throw WebSocketError.connect("Couldn't derive scheme from port")
                }
                scheme = port == 443 ? "wss" : "ws"
            } else {
                throw WebSocketError.connect("Neither scheme nor port specified")
            }
        }
        
        guard ["wss", "ws"].include(scheme) else {
            throw WebSocketError.connect("Invalid scheme")
        }
        
        if port == nil {
            port = scheme == "wss" ? 443: 80
        }
        
        socket = try SocketWrapper(type: scheme == "wss" ? .ssl : .tcp)
        
        print("Connecting websocket: (\(host), \(String(describing: port)))")
        
        try socket?.connect(host: host, port: port, timeout: timeout)
        
        let handShake = String(format: shandShakeTemplate, url.path, host)
        
        guard let data = handShake.data(using: .ascii) else {
            throw WebSocketError.connect("Faile to encode hand shake !!!")
        }
        
        try socket?.send(data: data)
    }
}


