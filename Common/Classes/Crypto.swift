//
//  Crypto.swift
//  Common
//
//  Created by Jiang,Zhenhua on 2018/11/1.
//  Copyright © 2018 Daubert. All rights reserved.
//

import Foundation

public struct RC4 {
    private var State : [UInt8]
    private var I: UInt8 = 0
    private var J: UInt8 = 0
    
    init() {
        State = [UInt8](repeating: 0, count: 256)
    }
    
    mutating
    func initialize(_ Key: [UInt8]) {
        for i in 0..<256 {
            State[i] = UInt8(i)
        }
        
        var j: UInt8 = 0
        for i in 0..<256 {
            let K : UInt8 = Key[i % Key.count]
            let S : UInt8 = State[i]
            j = j &+ S &+ K
            swapByIndex(i, y: Int(j))
        }
    }
    
    mutating
    private func swapByIndex(_ x: Int, y: Int) {
        let T1 : UInt8 = State[x]
        let T2 : UInt8 = State[y]
        State[x] = T2
        State[y] = T1
    }
    
    mutating
    private func next() -> UInt8 {
        I = I &+ 1
        J = J &+ State[Int(I)]
        swapByIndex(Int(I), y: Int(J))
        return State[Int(State[Int(I)] &+ State[Int(J)]) & 0xFF]
    }
    
    mutating
    func encrypt(_ Data: inout [UInt8]) {
        let cnt = Data.count
        for i in 0..<cnt {
            Data[i] = Data[i] ^ next()
        }
    }
}
