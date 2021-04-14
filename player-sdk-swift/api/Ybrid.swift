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

import Foundation


struct YbridResponse: Decodable {
    let __responseHeader: YbridInfo
}
struct YbridInfo: Codable {
    let responseVersion: String
    let statusCode: Int
    let success: Bool
    let supportedVersions: [String]
//        let timestamp: Date // TODO
}

struct YbridSessionResponse: Decodable {
    let __responseHeader: YbridInfo
    let __responseObject: YbridSessionObject
}
struct YbridSessionObject: Codable {
    let duration: Int
    let id: String
    let sessionId: String
    let valid: Bool
    let playout: YbridPlayout
}
struct YbridPlayout: Codable {
    let baseURL: URL
    let playbackURI: String //edge01-stagecast.ybrid.io:443/adaptive-demo?session-id\u003d90bb355e-30de-44ae-b521-4ba1544a9753",
    let currentBitRate: Int // -1,
    let host: String // "edge01-stagecast.ybrid.io",
    let maxBitRate: Int // -1,
    let offsetToLive : Int // -504
}
