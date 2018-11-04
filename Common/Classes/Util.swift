//
//  Util.swift
//  Common
//
//  Created by Jiang,Zhenhua on 2018/11/4.
//

import Foundation

extension UInt32 {
    
    public func IPv4String() -> String {
        
        let ip = self
        let byte1 = UInt8(ip & 0xff)
        let byte2 = UInt8((ip>>8) & 0xff)
        let byte3 = UInt8((ip>>16) & 0xff)
        let byte4 = UInt8((ip>>24) & 0xff)
        
        return "\(byte1).\(byte2).\(byte3).\(byte4)"
    }
}

// CRC16
public extension Array where Element == UInt8  {
    
    /// Seed, You should change this seed.
    private static let gPloy = 0x1000
    
    private static var crcTable: [Int] = {
        let getCrcOfByte: (Int) -> Int = { aByte in
            var value = aByte << 8
            for _ in 0 ..< 8 {
                if (value & 0x8000) != 0 {
                    value = (value << 1) ^ gPloy
                } else {
                    value = value << 1
                }
            }
            //get low 16 bit value
            value = value & 0xFFFF
            return value
        }
        // Generate CRC16 Code of 0-255
        return (0..<256).map(getCrcOfByte)
    }()
    
    func getCRC16Result() -> [UInt8] {
        var crc = getCrc()
        var crcArr: [UInt8] = [0,0]
        for i in (0..<2).reversed() {
            crcArr[i] = UInt8(crc % 256)
            crc >>= 8
        }
        return crcArr
    }
    
    private func getCrc() -> UInt16 {
        var crc = 0
        self.map { Int($0) }.forEach { data in
            let rhs = Array<Element>.crcTable[(((crc & 0xFF00) >> 8) ^ data) & 0xFF]
            crc = ((crc & 0xFF) << 8) ^ rhs
        }
        crc &= 0xffff
        return UInt16(crc)
    }
}



extension String {
    
    func toIpAddress(useBigEndian: Bool = true) throws -> UInt32 {
        var addr = in_addr()
        guard inet_pton(AF_INET, self, &addr) == 1 else {
            throw NSError(domain: "com.dabuert.nintendoclients.Common",
                          code: -2001,
                          userInfo: [NSLocalizedDescriptionKey: "invalid address"])
        }
        return useBigEndian ? addr.s_addr.bigEndian : addr.s_addr
    }
    
    func getCrc16(encodeing: String.Encoding = .utf8) -> [UInt8]? {
        guard let data = self.data(using: encodeing) else {
            return nil
        }
        return [UInt8](data).getCRC16Result()
    }
    
    func crc16() -> Int {
        var hash:Int = 0
        for char in self.utf8CString {
            for _ in 0..<8 {
                let flag = hash & 0x8000
                hash = (hash << 1) & 0xFFFF
                if flag != 0 {
                    hash ^= 0x1021
                }
            }
            hash ^= Int(char)
        }
        return hash
    }
    
    func ipToHex() throws -> [Any] {
        let ip = try toIpAddress()
        return try ">I".unpack(data: .init(from: ip))
    }
}

extension Data {
    
    init<T>(from value: T) {
        self = Swift.withUnsafeBytes(of: value) { Data($0) }
    }
    
    func to<T>(type: T.Type) -> T {
        return self.withUnsafeBytes { $0.pointee }
    }
}

extension Array where Element: Equatable {
    func include(_ element: Element) -> Bool {
        for one in self where one == element {
            return true
        }
        return false
    }
}

extension Range where Element: Equatable {
    func include(_ element: Element) -> Bool {
        for one in self where one == element {
            return true
        }
        return false
    }
}

extension ClosedRange where Element: Equatable {
    func include(_ element: Element) -> Bool {
        for one in self where one == element {
            return true
        }
        return false
    }
}
