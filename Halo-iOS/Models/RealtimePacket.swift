//
//  RealtimePacket.swift
//  Halo-iOS
//
//  Created by Cyril Zakka on 3/18/25.
//

import Foundation

enum RealTimeReading: UInt8 {
    case heartRate = 1
}

enum Action: UInt8 {
    case start = 1
    case pause = 2
    case `continue` = 3
    case stop = 4
}
