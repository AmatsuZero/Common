//
//  Streams.swift
//  Common
//
//  Created by Jiang,Zhenhua on 2018/11/2.
//  Copyright © 2018 Daubert. All rights reserved.
//

import Foundation

public class StreamOut {
    
    let endian: String
    fileprivate var data = Data()
    fileprivate var pos = 0
    fileprivate var stack = [Any]()
    
    var size: Int { return data.count }
    var isEof: Bool {
        return pos >= data.count
    }
    
    init(endian: String = "<") {
        self.endian = endian
    }
    
    func push() {
        stack.append(pos)
    }
    
    func pop() {
        if let last = stack.popLast() as? Int {
            pos = last
        }
    }
    
    func write(_ data: Data) {
        self.data[Int(pos)..<(Int(pos) + data.count)] = data
        pos += data.count
    }
    
    func seek(pos: Int) {
        if pos > data.count {
            pad(num: data.count - pos)
        }
        self.pos = pos
    }
    
    func pad(num: Int, char:String = "\0") {
        if let append = String(repeating: char, count: num).data(using: .ascii) {
            data += append
        }
    }
    
    func ascii(_ data: String) {
        if let append = data.data(using: .ascii) {
            self.data += append
        }
    }
    
    func tell() -> Int {
        return pos
    }
    
    func get() -> Data {
        return data
    }
    
    func skip(num: Int) {
        seek(pos: Int(pos) + num)
    }
    
    func align(num: Int) {
        skip(num: (num - Int(pos) % num) % num)
    }
    
    func u8(_ value: UInt8) {
        write(.init(repeating: value, count: 1))
    }
    
    func u16(_ value: Any) {
        pack(format: "\(endian)H", value: [value])
    }
    
    func u32(_ value: Any) {
        pack(format: "\(endian)I", value: [value])
    }
    
    func u64(_ value: Any) {
        pack(format: "\(endian)Q", value: [value])
    }
    
    func s8(_ value: Any) {
        pack(format: "b", value: [value])
    }
    
    func s16(_ value: Any) {
        pack(format: "\(endian)h", value: [value])
    }
    
    func s32(_ value: Any) {
        pack(format: "\(endian)i", value: [value])
    }
    
    func s64(_ value: Any) {
        pack(format: "\(endian)q", value: [value])
    }
    
    func float(_ value: Any) {
        pack(format: "\(endian)f", value: [value])
    }
    
    func double(_ value: Any) {
        pack(format: "\(endian)d", value: [value])
    }
    
    func bool(_ value: Any) {
        if value is Bool {
            u8(1)
        } else {
            u8(0)
        }
    }
    
    func char(_ value: Character) {
        u8(UInt8(value.unicodeScalarCodePoint()))
    }
    
    func wchar(_ value: Character) {
        u16(value.unicodeScalarCodePoint())
    }
    
    func chars(_ value: String) {
        value.forEach { self.char($0) }
    }
    
    func wchars(_ value: String) {
        value.forEach { self.wchar($0) }
    }
    
    private func pack(format: String, value: [Any]) {
        if let data = try? format.pack(values: value) {
            write(data)
        }
    }
}

public class StreamIn {
    
    let endian: String
    fileprivate var data = Data()
    fileprivate var pos = 0
    fileprivate var stack = [Any]()
    
    init(endian: String = "<") {
        self.endian = endian
    }
    
    var isEof: Bool {
        return pos >= data.count
    }
    
    var available: Int {
        return data.count - pos
    }
    
    func seek(pos: Int) {
        self.pos = pos
    }
    
    func skip(num: Int) {
        pos += num
    }
    
    func align(num: Int) {
        pos += ((num - pos % num) % num)
    }
    
    func tell() -> Int {
        return pos
    }
    
    func pad(num: Int, char: String = "\0") throws {
        if let value = String(repeating: char, count: num).data(using: .ascii),
            value != read(num: num) {
            throw NSError(domain: "com.dabuert.nintendoclients.Common.CStruct",
                          code: -6001,
                          userInfo: [NSLocalizedDescriptionKey : "Incorrect padding"])
        }
    }
    
    func ascii(_ num: Int) -> String? {
        return String(data: read(num: num), encoding: .ascii)
    }
    
    @discardableResult func read(num: Int) -> Data {
        data = data[pos..<(pos + num)]
        pos += num
        return data
    }
    
    func u8() -> UInt8 {
        return read(num: 1)[0]
    }
    
    func u16() -> UInt16? {
        return try! "\(endian)H".unpack(data: read(num: 2))[0] as? UInt16
    }
    
    func u32() -> UInt32? {
        return try! "\(endian)I".unpack(data: read(num: 4))[0] as? UInt32
    }
    
    func u64() -> UInt64? {
        return try! "\(endian)Q".unpack(data: read(num: 8))[0] as? UInt64
    }
    
    func float() -> Float? {
        return try! "\(endian)f".unpack(data: read(num: 4))[0] as? Float
    }
    
    func double() -> Double? {
        return try! "\(endian)d".unpack(data: read(num: 8))[0] as? Double
    }
    
    func bool() -> Bool? {
        return NSNumber(value: u8()).boolValue
    }
    
    func char() -> Character {
        return Character(.init(u8()))
    }
    
    func wchar() -> Character? {
        if let value = u16() {
            return Character(.init(value))
        }
        return nil
    }
    
    func chars(_ num: Int) -> String {
        return (0..<num)
            .map { _ in String(self.char()) }
            .reduce("", { $0 + $1 })
    }
    
    func wchar(_ num: Int) -> String {
        return (0..<num)
            .map { _ in self.wchar() }
            .compactMap { $0 }
            .map { String($0) }
            .reduce("", { $0 + $1 })
    }
}

public class BitStreamOut: StreamOut {
    var bitPos = 0
    
    override func push() {
        stack.append((bitPos, pos))
    }
    
    override func pop() {
        if let (pos, bitOps) = self.stack.popLast() as? (Int, Int) {
            self.pos = pos
            self.bitPos = bitOps
        }
    }
    
    func seek(pos: Int, bitPos: Int = 0) {
        super.seek(pos: pos)
        if bitPos > 0, self.pos == data.count, let appendix = "\0".data(using: .ascii) {
            self.data += appendix
        }
        self.bitPos = bitPos
    }
    
    fileprivate func byteAlign() {
        guard bitPos != 0 else {
            return
        }
        skip(num: 1)
        self.bitPos = 0
    }
    
    override func align(num: Int) {
        byteAlign()
        super.align(num: num)
    }
    
    fileprivate func bit(_ value: Int) {
        if self.pos == data.count, let appendix = "\0".data(using: .ascii) {
            self.data += appendix
        }
        var byte = data[pos]
        let mask: UInt8 = 1 << UInt8(7 - bitPos)
        if value != 0 {
            byte |= mask
        } else {
            byte &= mask
        }
        data[pos] = byte
        bitPos += 1
        if bitPos == 8 {
            bitPos = 0
            pos += 1
        }
    }
    
    fileprivate func bits(_ value: UInt8, _ num: Int) {
        for i in 0..<num {
            bit((Int(value) >> (num - i - 1)) & 1)
        }
    }
    
    override func write(_ data: Data) {
        if bitPos == 0 {
            super.write(data)
        } else {
            data.forEach { self.bits($0, 8) }
        }
    }
}

public class BitStreamIn: StreamIn {
    
    fileprivate var bitPos = 0
    
    func push() {
        stack.append((self.pos, self.bitPos))
    }
    
    func pop() {
        if let (pos, bitpos) = self.stack.popLast() as? (Int, Int) {
            self.pos = pos
            self.bitPos = bitpos
        }
    }
    
    func seek(pos: Int, bitpos: Int = 0) {
        self.pos = pos
        self.bitPos = bitpos
    }
    
    func bytealign() {
        if bitPos != 0 {
            pos += 1
            bitPos = 0
        }
    }
    
    override func align(num: Int) {
        bytealign()
        super.align(num: num)
    }
    
    fileprivate func bit() -> UInt8 {
        let byte = data[pos]
        let value = (Int(byte) >> (7 - bitPos)) & 1
        bitPos += 1
        if bitPos == 8 {
            bitPos = 0
            pos += 1
        }
        return UInt8(value)
    }
    
    fileprivate func bits(_ num: Int) -> UInt8 {
        var value: UInt8 = 0
        (0..<num).forEach { _ in
            value = (value << 1) | self.bit()
        }
        return value
    }
    
    override func read(num: Int) -> Data {
        if bitPos == 0 {
            return super.read(num: num)
        } else {
            var newData = Data()
            for _ in 0..<num {
                newData.append(bits(8))
            }
            return newData
        }
    }
}
