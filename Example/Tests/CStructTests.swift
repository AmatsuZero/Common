//
//  CStructTests.swift
//  CommonTests
//
//  Created by Jiang,Zhenhua on 2018/11/3.
//  Copyright © 2018 Daubert. All rights reserved.
//

import XCTest
@testable import Common

class PackTests: XCTestCase {

    func testHello() {
        let facit = "Hello".data(using: .utf8, allowLossyConversion: false)!
        
        do {
            let data1 = try "ccccc".pack(values: ["H", "e", "l", "l", "o"])
            XCTAssertEqual(data1, facit)
            
            let data2 = try "5c".pack(values: ["H", "e", "l", "l", "o"])
            XCTAssertEqual(data2, facit)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testInts() {
        let array: [UInt8] = [0xff, 0xfe, 0xff, 0xfd, 0xff, 0xff, 0xff, 0xfc, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
        let signedFacit = Data(bytes: array, count: array.count)
        do {
            let result1 = try "<bhiq".pack(values: [-1, -2, -3, -4])
            XCTAssertEqual(result1, signedFacit)
            
            let unsignedArray: [UInt8] = [0x01, 0x02, 0x00, 0x03, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
            let unsignedFacit = Data(bytes: unsignedArray, count: unsignedArray.count)
            let result2 = try "<BHIQ".pack(values: [1, 2, 3, 4])
            XCTAssertEqual(result2, unsignedFacit)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testAlignment() {
        let array1: [UInt8] = [0x01, 0x00, 0x02, 0x00]
        let signedFacit16 = Data(bytes: array1, count: array1.count)
        do {
            let data1 = try "@BH".pack(values: [1, 2])
            XCTAssertEqual(signedFacit16, data1)
            
            let array2: [UInt8] = [0x01, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00]
            let signedFacit32 = Data(bytes: array2, count: array2.count)
            let data2 = try "@BI".pack(values: [1,2])
            XCTAssertEqual(signedFacit32, data2)
            
            let array3: [UInt8] = [0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
            let signedFacit64 = Data(bytes: array3, count: array3.count)
            let data3 = try "@BQ".pack(values: [1,2])
            XCTAssertEqual(signedFacit64, data3)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testBigEndian() {
        let data: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e]
        let facit = Data(bytes: data, count: data.count)
        do {
            let result = try ">HIQ".pack(values: [0x0102, 0x03040506, 0x0708090a0b0c0d0e])
            XCTAssertEqual(result, facit)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testBadFormat() {
        XCTAssertNil(try? "4@".pack(values: []),"bad format should return nil")
        XCTAssertNil(try? "1 i".pack(values: [1]), "bad format should return nil")
        XCTAssertNil(try? "i".pack(values: []), "bad format should return nil")
        XCTAssertNil(try? "i".pack(values: [1,2]), "bad format should return nil")
    }
}

class UnpackTests: XCTestCase {
    
    func testHello() {
        let helloData = "Hello".data(using: .utf8, allowLossyConversion: false)!
        let facit = ["H", "e", "l", "l", "o"]
        do {
            guard let result = try "ccccc".unpack(data: helloData) as? [String] else {
                XCTFail("Unpack Failed")
                return
            }
            XCTAssertEqual(result, facit)
            
            guard let ret = try "5c".unpack(data: helloData) as? [String] else {
                XCTFail("Unpack Failed")
                return
            }
            XCTAssertEqual(ret, facit)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testBigEndian() {
        let array: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e]
        let facit: [UInt] = [0x0102, 0x03040506, 0x0708090a0b0c0d0e]
        let data = Data(bytes: array, count: array.count)
        do {
            guard let result = try ">HIQ".unpack(data: data) as? [UInt] else {
                XCTFail("Unpack Failed")
                return
            }
            XCTAssertEqual(result, facit)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
}
