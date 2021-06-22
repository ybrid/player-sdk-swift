//
// OpusMapping.swift
// app-example-ios
//
// Copyright (c) 2020 nacamar GmbH - Ybrid®, a Hybrid Dynamic Live Audio Technology
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

/* https://tools.ietf.org/html/rfc7845.html#section-5 */

class OpusHead : NSObject {
    enum OpusHeadError : Error {
        case invalid(_ cause:String)
    }
    let package:Data
    init?(package:Data) {
        self.package = package
        super.init()
        if !valid() { return nil }
    }
    private func valid() -> Bool {
        guard let foundHead:Range<Data.Index> = package.range(of: Data("OpusHead".utf8)) else {
            return false
        }
        return foundHead.startIndex == 0
    }
    var version:Int {
        let versionByte:UInt8 = package[8]
        return Int(versionByte)
    }
    var outChannels:Int {
        let outChannelsByte:UInt8 = package[9]
        return Int(outChannelsByte)
    }
    
    var preSkip:Int {
        let preSkipBytes:[UInt8] = [package[10],package[11]]
        let preSkipValue = UInt16(preSkipBytes[0]) + UInt16(preSkipBytes[1]) * 256 // little endian
        return Int(preSkipValue)
    }
    
    var mappingFamily:Int {
        let familyByte:UInt8 = package[18]
        return Int(familyByte)
    }
    
    override var debugDescription:String {
        return "ver \(version), ch \(outChannels), skip first \(preSkip) audio frames, mapping family \(mappingFamily)"
    }
}

class OpusTags : NSObject {
    let package:Data
    private var tagsStart:Int?
    init?(package:Data) {
        self.package = package
        super.init()
        if !valid() { return nil }
    }
    private func valid() -> Bool {
        guard let foundTag:Range<Data.Index> = package.range(of: Data("OpusTags".utf8)) else {
            return false
        }
        tagsStart = foundTag.startIndex
        return true
    }
    
    override var debugDescription:String {
        return "\(vendorString ?? "(no vendor string)") \(comments.debugDescription)"
    }
    
    var vendorString:String? {
        guard let zero = tagsStart else {
            return nil
        }
        let vendorOffset = zero + 8
        let vendorLength = getLength32(offset: vendorOffset)
        let vendorData:Data = package[(vendorOffset+4..<vendorOffset+4+Int(vendorLength))]
        return String(data: vendorData, encoding: .utf8)
    }
    
    private func getLength32( offset:Int ) -> UInt32 {
        let lengthBytes:[UInt8] = [package[offset],package[offset+1],package[offset+2],package[offset+3]]
        let length = UInt32(lengthBytes[0]) +  UInt32((lengthBytes[1]) << 8)
            + UInt32((lengthBytes[2]) << 16) +  UInt32((lengthBytes[3]) << 24)
        return length
    }
    
    private var commentsOffset:Int? {
        guard let zero = tagsStart else {
            return nil
        }
        let vendorOffset = zero + 8
        return vendorOffset + 4 + Int(getLength32(offset: vendorOffset))
    }
    
    var comments:[String:String] {
        guard let offset = commentsOffset else {
            return [:]
        }
        let nComments = Int(getLength32(offset: offset))
        guard nComments > 0 else {
            return [:]
        }
        var commentOffset:Int = offset + 4
        var commentLength:Int = 0
        var comments:[String:String] = [:]
        for _ in 1...nComments {
            commentLength = Int(getLength32(offset:commentOffset))
            let commentData = package[(commentOffset+4..<commentOffset+4+Int(commentLength))]
            if let comment = String(data: commentData, encoding: .utf8) {
                if let entry = keyVal(entry: comment) {
                    comments[entry.0]=entry.1
                }
            }
            commentOffset = commentOffset + 4 + commentLength
        }
        return comments
    }
    
    
    /*
     2020-11-13 16:12:55.125217+0100 app-example-ios[4767:220430] [decoding] OpusAudioData.handleOpusPacket-279 packet 1  has 57 bytes (granulepos=0)
     title=
     2020-11-13 16:12:55.125477+0100 app-example-ios[4767:220430] [decoding] OpusMapping.keyVal-144 cannot parse entry 'title='
     2020-11-13 16:12:55.125696+0100 app-example-ios[4767:220430] [decoding] OpusAudioData.parse-130 OpusTags ocaml-opus by the Savonet Team. [:]
     title=
     2020-11-13 16:12:55.125955+0100 app-example-ios[4767:220430] [decoding] OpusMapping.keyVal-144 cannot parse entry 'title='
     title=
     2020-11-13 16:12:55.126325+0100 app-example-ios[4767:220430] [decoding] OpusMapping.keyVal-144 cannot parse entry 'title='
     title=
     2020-11-13 16:12:55.126598+0100 app-example-ios[4767:220430] [decoding] OpusMapping.keyVal-144 cannot parse entry 'title='
     2020-11-13 16:13:00.272122+0100 app-example-ios[4767:220301] [decoding] OpusAudioData.parse-75 written 1047 ogg bytes into buffer, state 0
     */
    private func keyVal(entry:String) -> (String,String)? {
        let property:[String] = entry.split(separator: "=", maxSplits: 1).map(String.init)
        guard property.count == 2 else {
            Logger.decoding.error("cannot parse entry '\(entry)'")
            return nil
        }
        let key = property[0]
        var value = property[1]
        if let until = value.firstIndex(of: "\0") {
            value = String(value[..<until])
        }
        return (key.uppercased(),value)
    }
}


