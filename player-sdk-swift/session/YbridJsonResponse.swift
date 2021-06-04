//
// Ybrid.swift
// player-sdk-swift
//
// Copyright (c) 2021 nacamar GmbH - Ybrid®, a Hybrid Dynamic Live Audio Technology
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

// Defines the expected structure of ybrid responses

import Foundation

struct YbridResponse: Decodable {
    let __responseHeader: YbridInfo
}
struct YbridInfo: Codable {
    let responseVersion: String
    let statusCode: Int
    let success: Bool
    let supportedVersions: [String]
    let timestamp: Date
}

struct YbridSessionResponse: Decodable {
    let __responseHeader: YbridInfo
    let __responseObject: YbridSessionObject
}

struct YbridSessionObject: Codable {
    let duration: Int
//    let id: String? // deprecated
    let sessionId: String?
    let valid: Bool
    let playout: YbridPlayout?
    let metadata: YbridV2Metadata?
    let startDate: Date?
    let swapInfo: YbridSwapInfo?
    let bouquet: YbridBouquet?
}
struct YbridPlayout: Codable {
    let baseURL: URL
    let playbackURI: String
    let currentBitRate: Int // -1
    let host: String // "edge01-stagecast.ybrid.io"
    let maxBitRate: Int // -1
    let offsetToLive : Int // millis
}

struct YbridV2Metadata : Codable, Equatable {
    static func == (lhs: YbridV2Metadata, rhs: YbridV2Metadata) -> Bool {
        return lhs.currentItem == rhs.currentItem &&
            lhs.nextItem == rhs.nextItem &&
            lhs.station == rhs.station
    }
    
    let currentItem: YbridItem
    let nextItem: YbridItem
    let station: YbridStation
}

struct YbridItem : Codable, Equatable {
    let id: String
    let artist: String
    let title: String
    let description: String
    let durationMillis: Int64
    let type : String
    //         "cuePoints": {}, // in newCurrentItem of YbridWindedObject
    //         "altContent": [], // in newCurrentItem of YbridWindedObject
    var replaceable: Bool? = nil // in newCurrentItem of YbridWindedObject
    var url: String? = nil // in newCurrentItem of YbridWindedObject
    var classifiedType: String? = nil // in newCurrentItem of YbridWindedObject
}

struct YbridStation : Codable, Equatable {
    let genre: String
    let name: String
}

struct YbridWindResponse: Decodable  {
    let __responseHeader: YbridInfo
    let __responseObject: YbridWindedObject
}

struct YbridWindedObject : Codable, Equatable {
    var requestedTimestamp: Int64? = nil // -1, not in windToLive response
    var requestedWindDuration: Int? = nil // -10000, not in windToLive response
    let effectiveWindDuration: Int //-10080,
    let timestampWindedTo: Int64 //1621944665069,
    let totalOffset: Int // millis, -49392
    let newCurrentItem: YbridItem
}

struct YbridSwapItemResponse: Decodable {
    let __responseHeader: YbridInfo
    let __responseObject: YbridSwapInfo
}

struct YbridSwapInfo : Codable, Equatable {
    let nextSwapReturnsToMain: Bool
    let swapsLeft: Int // -1 -> infinet
}

struct YbridBouquet : Codable, Equatable {
    let activeServiceId: String
    let availableServices: [YbridService]
    let bouquetId: String
    let primaryServiceId: String
}

struct YbridService : Codable, Equatable {
    let iconURL: String
    var displayName: String? = nil
    let id: String
}
