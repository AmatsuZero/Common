//
//  Wrapper.swift
//  Common
//
//  Created by Jiang,Zhenhua on 2018/11/1.
//  Copyright © 2018 Daubert. All rights reserved.
//

import Foundation
import Socket
import SSLService

public class SocketWrapper {
    
    let socket: Socket
    enum SocketType: Int {
        case udp = 0, tcp, ssl
    }
    typealias AddressInfo = (host: String, port: Int32)
    private(set) var serverAddressInfo: AddressInfo?
    var clientAddress: AddressInfo {
        return (socket.remoteHostname, socket.listeningPort)
    }
    
    init(type: SocketType) throws {
        switch type {
        case .udp:
            socket = try Socket.create(family: .inet,
                                       type: .datagram,
                                       proto: .udp)
        case .tcp:
            socket = try Socket.create(family: .inet,
                                       type: .stream,
                                       proto: .tcp)
        case .ssl:
            socket = try Socket.create(family: .inet,
                                       type: .stream,
                                       proto: .tcp)
            let sslConfig = SSLService.Configuration()
            socket.delegate = try SSLService(usingConfiguration: sslConfig)
        }
    }
    
    func connect(host: String, port: Int32, timeout: UInt = 3) throws {
        try socket.connect(to: host, port: port, timeout: timeout)
        try socket.setBlocking(mode: false)
        serverAddressInfo = (host, port)
    }
    
    func close() {
        socket.close()
    }
    
    func send(data: Data) throws {
        try socket.write(from: data)
    }
    
    func receive(bufferSize: Int = 4096) throws -> String? {
        var buff = [CChar]()
        _ = try socket.read(into: &buff, bufSize: bufferSize, truncate: true)
        return String(cString: &buff)
    }
}
