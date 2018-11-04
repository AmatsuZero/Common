//
//  CStruct.swift
//  Common
//
//  Created by Jiang,Zhenhua on 2018/11/2.
//  Copyright © 2018 Daubert. All rights reserved.
//

import Foundation

//      BYTE ORDER      SIZE            ALIGNMENT
//  @   native          native          native
//  =   native          standard        none
//  <   little-endian   standard        none
//  >   big-endian      standard        none
//  !   network (BE)    standard        none

//      FORMAT  C TYPE                  SWIFT TYPE              SIZE
//      x       pad byte                no value
//      c       char                    String of length 1      1
//      b       signed char             Int                     1
//      B       unsigned char           UInt                    1
//      ?       _Bool                   Bool                    1
//      h       short                   Int                     2
//      H       unsigned short          UInt                    2
//      i       int                     Int                     4
//      I       unsigned int            UInt                    4
//      l       long                    Int                     4
//      L       unsigned long           UInt                    4
//      q       long long               Int                     8
//      Q       unsigned long long      UInt                    8
//      f       float                   Float                   4
//      d       double                  Double                  8
//      s       char[]                  String
//      p       char[]                  String
//      P       void *                  UInt                    4/8
//
//      Floats and doubles are packed with IEEE 754 binary32 or binary64 format.

// Split a large integer into bytes.
extension Int {
    func splitBytes(isBigEndian: Bool, size: Int) -> [UInt8] {
        var bytes = [UInt8]()
        var shift: Int
        var step: Int
        if !isBigEndian {
            shift = 0
            step = 8
        } else {
            shift = (size - 1) * 8
            step = -8
        }
        for _ in 0..<size {
            bytes.append(UInt8((self >> shift) & 0xff))
            shift += step
        }
        return bytes
    }
}

extension UInt {
    func splitBytes(isBigEndian: Bool, size: Int) -> [UInt8] {
        var bytes = [UInt8]()
        var shift: Int
        var step: Int
        if !isBigEndian {
            shift = 0
            step = 8
        } else {
            shift = Int((size - 1) * 8)
            step = -8
        }
        for _ in 0..<size {
            bytes.append(UInt8((self >> UInt(shift)) & 0xff))
            shift = shift + step
        }
        return bytes
    }
}

private let PAD_BYTE: UInt8 = 0

private let pointerSize = MemoryLayout.size(ofValue: UnsafeRawPointer.self)

extension String {
    
    private var platformEndianness: Endianness { return .little }
    
    enum Endianness {
        case little, big
    }
    
    enum CStructError: CustomNSError {
        case parsing(String)
        case packing(String)
        case unpacking(String)
        
        public static var errorDomain: String {
            return "com.dabuert.nintendoclients.Common.CStruct"
        }
        var errorCode: Int {
            switch self {
            case .parsing: return -1
            case .packing: return -2
            case .unpacking: return -3
            }
        }
        
        var errorUserInfo: [String : Any] {
            switch self {
            case .parsing(let msg), .packing(let msg), .unpacking(let msg):
                return [NSLocalizedDescriptionKey: msg]
            }
        }
    }
    
    enum Ops {
        // Stop packing.
        case Stop
        
        // Control endianness.
        case SetNativeEndian
        case SetLittleEndian
        case SetBigEndian
        
        // Control alignment.
        case SetAlign
        case UnsetAlign
        
        // Pad bytes.
        case SkipByte
        
        // Packed values.
        case PackChar
        case PackInt8
        case PackUInt8
        case PackBool
        case PackInt16
        case PackUInt16
        case PackInt32
        case PackUInt32
        case PackInt64
        case PackUInt64
        case PackFloat
        case PackDouble
        case PackCString
        case PackPString
        case PackPointer
        
        var bytesForValue: Int? {
            switch self {
            case .SkipByte, .PackChar, .PackInt8, .PackUInt8, .PackBool:
                return 1
            case .PackInt16, .PackUInt16:
                return 2
            case .PackInt32, .PackUInt32, .PackFloat:
                return 4
            case .PackInt64, .PackUInt64, .PackDouble:
                return 8
            case .PackPointer:
                return pointerSize
            default:
                return nil
            }
        }
    }
    
    func unpack(data: Data) throws -> [Any] {
        let opStream = try parse()
        var values = [Any]()
        var index = 0
        var endianness = platformEndianness
        
        // Read UInt8 values from data.
        let readBytes: (Int) -> [UInt8]? = { count in
            guard index + count <= data.count else {
                return nil
            }
            let start = index
            index += count
            return data.withUnsafeBytes {
                [UInt8](UnsafeBufferPointer(start: $0 + start, count: count))
            }
        }
        
        // Create integer from bytes.
        let intFromBytes: ([UInt8]) -> Int = { bytes in
            var i = 0
            for byte in (endianness == .little ? bytes.reversed() : bytes) {
                i <<= 8
                i |= Int(byte)
            }
            return i
        }
        
        let uintFromBytes: ([UInt8]) -> UInt = { bytes in
            var i: UInt = 0
            for byte in (endianness == .little ? bytes.reversed() : bytes) {
                i <<= 8
                i |= UInt(byte)
            }
            return i
        }
        
        for op in opStream {
            switch op {
            case .Stop:
                return values
            case .SetNativeEndian:
                endianness = platformEndianness
            case .SetLittleEndian:
                endianness = .little
            case .SetBigEndian:
                endianness = .big
            case .SetAlign, .UnsetAlign:
                continue
            case .PackCString, .PackPString:
                throw CStructError.unpacking("cstring/pstring unimplemented")
            case .SkipByte:
                guard readBytes(1) != nil else {
                    throw CStructError.unpacking("not enough data for format")
                }
            default:
                guard let bytesToUnpack = op.bytesForValue,
                    let bytes = readBytes(bytesToUnpack) else {
                        throw CStructError.unpacking("not enough data for format")
                }
                switch op {
                case .SkipByte:
                    break
                case .PackChar:
                    values.append(String(format: "%c", bytes[0]))
                case .PackInt8:
                    values.append(Int(bytes[0]))
                case .PackUInt8:
                    values.append(UInt(bytes[0]))
                case .PackBool:
                    values.append(bytes[0] != UInt8(0))
                case .PackInt16, .PackInt32, .PackInt64:
                    values.append(intFromBytes(bytes))
                case .PackUInt16, .PackUInt32, .PackUInt64, .PackPointer:
                    values.append(uintFromBytes(bytes))
                case .PackCString, .PackPString:
                    throw CStructError.unpacking("cstring/pstring unimplemented")
                case .PackFloat, .PackDouble:
                    throw CStructError.unpacking("float/double unimplemented")
                default:
                    throw CStructError.unpacking("not enough data for format")
                }
            }
        }
        return values
    }
    
    func pack(values: [Any]) throws -> Data {
        let ops = try parse()
        var bytes = [UInt8]()
        var index = 0
        var alignment = true
        var endianness = platformEndianness
        
        // If alignment is requested, emit pad bytes until alignment is satisfied.
        let padAlignment: (Int) -> Void = { size in
            guard alignment else {
                return
            }
            let mask = size - 1
            while (bytes.count & mask) != 0 {
                bytes.append(PAD_BYTE)
            }
        }
        
        for op in ops {
            switch op {
            case .Stop:
                guard index == values.count else {
                    throw CStructError.packing("expected \(index) items for packing, got \(values.count)")
                }
                return Data(bytes: bytes, count: bytes.count)
            case .SetNativeEndian:
                endianness = platformEndianness
            case .SetBigEndian:
                endianness = .big
            case .SetLittleEndian:
                endianness = .little
            case .SetAlign:
                alignment = true
            case .UnsetAlign:
                alignment = false
            case .SkipByte:
                bytes.append(PAD_BYTE)
            default:
                guard index < values.count else {
                    throw CStructError.packing("expected at least \(index) items for packing, got \(values.count)")
                }
                // No control op found so pop the next value.
                let rawValue = values[index]
                index += 1
                switch op {
                case .PackChar:
                    guard let str = rawValue as? String else {
                        throw CStructError.packing("cannot convert argument to Char: \(rawValue)")
                    }
                    guard let codePoint = str.utf16.first, codePoint < 128 else {
                        throw CStructError.packing("char format requires String of length 1: \(rawValue)")
                    }
                    bytes.append(UInt8(codePoint))
                case .PackInt8:
                    guard let value = rawValue as? Int else {
                        throw CStructError.packing("cannot convert argument to Int: \(rawValue)")
                    }
                    guard value >= -0x80, value <= 0x7f else {
                        throw CStructError.packing("value outside valid range of Int8: \(rawValue)")
                    }
                    bytes.append(UInt8(value & 0xff))
                case .PackUInt8:
                    guard let value = rawValue as? Int else {
                        throw CStructError.packing("cannot convert argument to Int: \(rawValue)")
                    }
                    guard value <= 0xff else {
                        throw CStructError.packing("value outside valid range of UInt8: \(rawValue)")
                    }
                    bytes.append(UInt8(value))
                case .PackBool:
                    guard let value = rawValue as? Bool else {
                        throw CStructError.packing("cannot convert argument to Bool: \(rawValue)")
                    }
                    bytes.append(value ? 1 : 0)
                case .PackInt16:
                    guard let value = rawValue as? Int else {
                        throw CStructError.packing("cannot convert argument to Int: \(rawValue)")
                    }
                    guard value >= -0x8000, value <= 0x7fff else {
                        throw CStructError.packing("value outside valid range of Int16: \(rawValue)")
                    }
                    padAlignment(2)
                    bytes += value.splitBytes(isBigEndian: endianness == .big, size: 2)
                case .PackUInt16:
                    guard let value = rawValue as? Int else {
                        throw CStructError.packing("cannot convert argument to Int: \(rawValue)")
                    }
                    guard value <= 0xfff else {
                        throw CStructError.packing("value outside valid range of UInt16: \(rawValue)")
                    }
                    padAlignment(2)
                    bytes += value.splitBytes(isBigEndian: endianness == .big, size: 2)
                case .PackInt32:
                    guard let value = rawValue as? Int else {
                        throw CStructError.packing("cannot convert argument to Int: \(rawValue)")
                    }
                    guard value >= -0x80000000, value <= 0x7fffffff else {
                        throw CStructError.packing("value outside valid range of Int32: \(rawValue)")
                    }
                    padAlignment(4)
                    bytes += value.splitBytes(isBigEndian: endianness == .big, size: 4)
                case .PackUInt32:
                    guard let value = rawValue as? Int else {
                        throw CStructError.packing("cannot convert argument to Int: \(rawValue)")
                    }
                    guard value <= 0xffffffff else {
                        throw CStructError.packing("value outside valid range of UInt32: \(rawValue)")
                    }
                    padAlignment(4)
                    bytes += value.splitBytes(isBigEndian: endianness == .big, size: 4)
                case .PackInt64:
                    guard let value = rawValue as? Int else {
                        throw CStructError.packing("cannot convert argument to Int: \(rawValue)")
                    }
                    padAlignment(8)
                    bytes += value.splitBytes(isBigEndian: endianness == .big, size: 8)
                case .PackUInt64:
                    guard let oValue = rawValue as? Int else {
                        throw CStructError.packing("cannot convert argument to Int: \(rawValue)")
                    }
                    let value = UInt(oValue)
                    padAlignment(8)
                    bytes += value.splitBytes(isBigEndian: endianness == .big, size: 8)
                case .PackPointer:
                    guard let oValue = rawValue as? Int else {
                        throw CStructError.packing("cannot convert argument to Int: \(rawValue)")
                    }
                    let value = UInt(oValue)
                    padAlignment(pointerSize)
                    bytes += value.splitBytes(isBigEndian: endianness == .big, size: pointerSize)
                case .PackFloat, .PackDouble:
                    throw CStructError.packing("float/double unimplemented")
                case .PackCString, .PackPString:
                    throw CStructError.packing("cstring/pstring unimplemented")
                default:
                    throw CStructError.packing("bad op in stream")
                }
            }
        }
        return Data(bytes: &bytes, count: bytes.count)
    }
    
    private func parse() throws -> [Ops] {
        var opStream = [Ops]()
        // First test if the format string contains an integer. In that case
        // we feed it into the repeat counter and go to the next character.
        var repeatCount = 0
        for c in self {
            if let value = Int(String(c)) {
                repeatCount = repeatCount * 10 + value
                continue
            }
            if repeatCount == 0 {// The next step depends on if we've accumulated a repeat count.
                // With a repeat count of 0 we check for control characters.
                switch c {
                // Control endianness.
                case "@":
                    opStream.append(.SetNativeEndian)
                    opStream.append(.SetAlign)
                case "=":
                    opStream.append(.SetNativeEndian)
                    opStream.append(.UnsetAlign)
                case "<":
                    opStream.append(.SetLittleEndian)
                    opStream.append(.UnsetAlign)
                case ">", "!":
                    opStream.append(.SetBigEndian)
                    opStream.append(.UnsetAlign)
                case " ":
                    break
                default:
                    repeatCount = 1
                }
            }
            if repeatCount > 0 {// If we have a repeat count we expect a format character.
                for _ in 0..<repeatCount {
                    switch c {
                    case "x": opStream.append(.SkipByte)
                    case "c": opStream.append(.PackChar)
                    case "?": opStream.append(.PackBool)
                    case "b": opStream.append(.PackInt8)
                    case "B": opStream.append(.PackUInt8)
                    case "h": opStream.append(.PackInt16)
                    case "H": opStream.append(.PackUInt16)
                    case "i", "l": opStream.append(.PackInt32)
                    case "I", "L": opStream.append(.PackUInt32)
                    case "q": opStream.append(.PackInt64)
                    case "Q": opStream.append(.PackUInt64)
                    case "f": opStream.append(.PackFloat)
                    case "d": opStream.append(.PackDouble)
                    case "s": opStream.append(.PackCString)
                    case "p": opStream.append(.PackPString)
                    case "P": opStream.append(.PackPointer)
                    default:
                        throw CStructError.parsing("bad character in format")
                    }
                }
            }
            // Reset the repeat counter.
            repeatCount = 0
        }
        opStream.append(.Stop)
        return opStream
    }
}
