//
//  PacketTests.swift
//  Halo-iOS
//
//  Created for Halo-iOS
//

@testable import Halo_iOS
import XCTest

final class PacketTests: XCTestCase {
    func testChecksumCalculation() {
        // [1, 2, 3] -> 1+2+3 = 6
        let packet: [UInt8] = [1, 2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        let result = checksum(packet: packet)
        XCTAssertEqual(result, 6)
    }

    func testChecksumWithOverflow() {
        // 200 + 100 = 300 -> 300 % 255 = 45
        let packet: [UInt8] = [200, 100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        let result = checksum(packet: packet)
        XCTAssertEqual(result, 45)
    }

    func testMakePacketValid() throws {
        let command: UInt8 = 10
        let subData: [UInt8] = [1, 2, 3]

        // Expected: [10, 1, 2, 3, 0...0, checksum]
        // Checksum: 10 + 1 + 2 + 3 = 16

        let packet = try makePacket(command: command, subData: subData)

        XCTAssertEqual(packet.count, 16)
        XCTAssertEqual(packet[0], 10)
        XCTAssertEqual(packet[1], 1)
        XCTAssertEqual(packet[2], 2)
        XCTAssertEqual(packet[3], 3)
        XCTAssertEqual(packet[15], 16)
    }

    func testMakePacketWithoutSubData() throws {
        let command: UInt8 = 5
        let packet = try makePacket(command: command)

        XCTAssertEqual(packet[0], 5)
        XCTAssertEqual(packet[1], 0) // Should be zero filled
        XCTAssertEqual(packet[15], 5) // Checksum is just command
    }

    func testMakePacketInvalidSubDataLength() {
        let command: UInt8 = 10
        let invalidSubData = [UInt8](repeating: 1, count: 15) // Limit is 14

        XCTAssertThrowsError(try makePacket(command: command, subData: invalidSubData)) { error in
            XCTAssertEqual(error as? PacketError, PacketError.invalidSubDataLength)
        }
    }
}
