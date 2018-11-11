//
//  Util.swift
//  Common
//
//  Created by Jiang,Zhenhua on 2018/11/4.
//

import Foundation
import CommonCrypto

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
extension Array where Element == UInt8  {
    
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
    
    public func getCRC16Result() -> [UInt8] {
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
    
    public func toIpAddress(useBigEndian: Bool = true) throws -> UInt32 {
        var addr = in_addr()
        guard inet_pton(AF_INET, self, &addr) == 1 else {
            throw NSError(domain: "com.dabuert.nintendoclients.Common",
                          code: -2001,
                          userInfo: [NSLocalizedDescriptionKey: "invalid address"])
        }
        return useBigEndian ? addr.s_addr.bigEndian : addr.s_addr
    }
    
    public func getCrc16(encodeing: String.Encoding = .utf8) -> [UInt8]? {
        guard let data = self.data(using: encodeing) else {
            return nil
        }
        return [UInt8](data).getCRC16Result()
    }
    
    public func crc16() -> Int {
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
    
    public func ipToHex() throws -> [Any] {
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

extension String {
    
    func slice(from: Int, to: Int) -> String {
        let start = index(startIndex, offsetBy: from)
        let end = index(startIndex, offsetBy: to)
        return String(self[start..<end])
    }
}

extension Data {
    
    public func applyMask(key: Data) -> Data {
        var bytes = [UInt8]()
        for (i, v) in self.enumerated() {
            bytes.append(v ^ key[i % 4])
        }
        return Data(bytes: bytes)
    }
}

// MARK: - HMAC
extension String {
    public enum HMACAlgorithm {
        case MD5, SHA1, SHA224, SHA256, SHA384, SHA512
        
        func toCCHmacAlgorithm() -> CCHmacAlgorithm {
            var result: Int = 0
            switch self {
            case .MD5:
                result = kCCHmacAlgMD5
            case .SHA1:
                result = kCCHmacAlgSHA1
            case .SHA224:
                result = kCCHmacAlgSHA224
            case .SHA256:
                result = kCCHmacAlgSHA256
            case .SHA384:
                result = kCCHmacAlgSHA384
            case .SHA512:
                result = kCCHmacAlgSHA512
            }
            return CCHmacAlgorithm(result)
        }
        
        var digestLength: Int {
            var result: CInt = 0
            switch self {
            case .MD5:
                result = CC_MD5_DIGEST_LENGTH
            case .SHA1:
                result = CC_SHA1_DIGEST_LENGTH
            case .SHA224:
                result = CC_SHA224_DIGEST_LENGTH
            case .SHA256:
                result = CC_SHA256_DIGEST_LENGTH
            case .SHA384:
                result = CC_SHA384_DIGEST_LENGTH
            case .SHA512:
                result = CC_SHA512_DIGEST_LENGTH
            }
            return Int(result)
        }
    }
    
    public func hmac(algorithm: HMACAlgorithm, key: String) -> String {
        let cKey = key.cString(using: .utf8)
        let cData = cString(using: .utf8)
        var result = [CUnsignedChar](repeating: 0, count: algorithm.digestLength)
        CCHmac(algorithm.toCCHmacAlgorithm(), cKey!,
               strlen(cKey!), cData!, strlen(cData!), &result)
        let hmacData = Data(bytes: result, count: algorithm.digestLength)
        return hmacData.base64EncodedString(options: .lineLength76Characters)
    }
}

extension StringProtocol {
    public var ascii: [UInt32] {
        return unicodeScalars.compactMap { $0.isASCII ? $0.value : nil }
    }
}

public extension Character {
    public var ascii: UInt32? {
        return String(self).ascii.first
    }
    
    public func unicodeScalarCodePoint() -> UInt32 {
        let characterString = String(self)
        let scalars = characterString.unicodeScalars
        return scalars[scalars.startIndex].value
    }
}

