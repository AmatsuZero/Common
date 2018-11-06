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
    
    enum OpCode: UInt8 {
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
    GET %@ HTTP/1.1
    Host: %d
    Upgrade: websocket
    Connection: upgrade
    Sec-WebSocket-Key: NEX
    Sec-WebSocket-Version: 13
    Sec-WebSocket-Protocol: NEX

    """
    
    private var state = ConnectionState.disconnect
    private var socket: SocketWrapper?
    private var buffer = Data()
    private var fragments = Data()
    private var packets = [UInt8]()
    
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
        
        let socket = try SocketWrapper(type: scheme == "wss" ? .ssl : .tcp)
        self.socket = socket
        
        print("Connecting websocket: (\(host), \(String(describing: port)))")
        
        try socket.connect(host: host, port: port, timeout: timeout)
        
        let handShake = String(format: shandShakeTemplate, url.path, host)
        
        guard let data = handShake.data(using: .ascii) else {
            throw WebSocketError.connect("Faile to encode hand shake !!!")
        }
        
        try socket.send(data: data)
        
        SocketEvent.shared.add(socket: socket) { [weak self] wrapper -> Bool in
            guard let self = self else {
                return false
            }
            return self.handle(socket: wrapper)
        }
        
        repeat {
            
        } while state == .connecting
    }
    
    func handle(socket: SocketWrapper) -> Bool {
        guard let code = try? socket.receive(data: &buffer),
            code > 0 else {
                state = .disconnect
                return false
        }
        guard let text = String(data: buffer, encoding: .ascii) else {
            state = .disconnect
            return false
        }
        switch state {
        case .connecting:
            if text.contains("\r\n\r\n") {
                guard text.starts(with: "HTTP/1.1") else {
                    print("Invalid handshake response")
                    state = .disconnect
                    return false
                }
                guard let code = Int(text.slice(from: 9, to: 12)), code == 101 else {
                    state = .disconnect
                    return false
                }
                let part = text.components(separatedBy: "\r\n\r\n")[1]
                guard let newBuffer = part.data(using: .ascii) else {
                    state = .disconnect
                    return false
                }
                buffer = newBuffer
                state = .connected
            }
        case .connected:
            guard buffer.count >= 2 else {
                return true
            }
            let fin = buffer[0] >> 7
            let mask = buffer[1] >> 7
            var size = buffer[1] & 0x7F
            var offset = 2
            
            do {
                if size == 126 {
                    if buffer.count < offset + 2 {
                        return true
                    }
                    size = try ">H".unpack(data: buffer)[..<offset][0] as! UInt8
                    offset += 2
                } else if size == 127 {
                    if buffer.count < offset + 8 {
                        return true
                    }
                    size = try ">Q".unpack(data: buffer)[0..<2][0] as! UInt8
                    offset += 8
                }
            } catch {
                print(error.localizedDescription)
                return false
            }
            var mask_key = "\0\0\0\0".data(using: .ascii)
            if mask != 0, mask_key != nil {
                if buffer.count < offset + 4 {
                    return true
                }
                mask_key = buffer[offset..<offset+4]
                offset += 4
            }
            guard buffer.count >= offset else {
                return true
            }
            
            let payload = buffer[offset..<(offset + Int(size))].applyMask(key: mask_key!)
            fragments += payload
            if fin != 0 {
                packets += fragments
                fragments = "".data(using: .utf8)!
            }
            buffer = buffer[(offset+Int(size))...]
        default:
            break
        }
        return true
    }
    
    func sendPacket(opcode: UInt8, payload: Data = "".data(using: .ascii)!) throws {
        var data = Data(bytes: [0x80 | opcode])
        let length = payload.count
        switch length {
        case 0..<126:
            data += Data(bytes: [0x80 | UInt8(length)])
        case 126...0xfff:
            data += try "BH".pack(values: [0xfe, length])
        default:
            data += try ">BQ".pack(values: [0xff, length])
        }
    }
    
    func send(data: Data) throws {
        guard state == .connected else {
            throw WebSocketError.send("Can't send data on a disconnected websocket")
        }
        try sendPacket(opcode: OpCode.binary.rawValue, payload: data)
    }
    
    func close() throws {
        guard state != .disconnect else {
            return
        }
        try sendPacket(opcode: OpCode.disconnect.rawValue)
        socket?.close()
        state = .disconnect
        SocketEvent.shared.removeEvents()
    }
    
    func recv() -> Data {
        guard state == .connected, !packets.isEmpty else {
            return "".data(using: .ascii)!
        }
        return Data(bytes: [packets.removeFirst()])
    }
}


