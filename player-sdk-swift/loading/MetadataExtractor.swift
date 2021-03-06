//
// MetadataExtractor.swift
// player-sdk-swift
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
import CommonCrypto

class MetadataExtractor {
    
    let intervalBytes:Int
    fileprivate var nextMetadataAt:Int
    fileprivate var metadata:PayloadCollector? // = PayloadCollector("metadata")
//    var totalBytesTreated:UInt32 = 0
//    var totalBytesExtracted:UInt32 = 0
//    var totalBytesAudio:UInt32 = 0
    weak var listener: MetadataListener?
    var lastMetadataHash: Data?
    
    init(bytesBetweenMetadata:Int, listener: MetadataListener) {
        self.intervalBytes = bytesBetweenMetadata
        self.nextMetadataAt = bytesBetweenMetadata
        self.listener = listener
    }
    
    deinit {
        Logger.loading.debug()
    }
    
    fileprivate class PayloadCollector {
        
        let name:String /// helps debugging / logging
        var data:Data
        var outstanding:Int? /// remaining bytes (of metadata)
        
        init(_ name: String) {
            self.name = name
            self.data = Data()
        }
        
        init(_ name: String, _ length:Int) {
            self.name = name
            self.data = Data()
            self.outstanding = length
        }
        
        func appendUntilEnd(of: Data, idx: Int) -> Int {
            guard idx < of.count else {
                Logger.loading.error("-guard: \(name).appendUntilEnd \(idx) >= \(of.count)!")
                return 0
            }
            self.data.append(of.subdata(in: (idx..<of.count)))
            let appended = of.count - idx
            self.outstanding? -= appended
            return appended
        }
        
        func appendCount(of: Data, index: Int, count: Int) -> Int {
            guard index+count <= of.count else {
                Logger.loading.error("-guard: \(name).appendCount \(index)+\(count) > \(of.count)!")
                return 0
            }
            self.data.append(of.subdata(in: (index..<index+count)))
            self.outstanding? -= count
            return count
        }
    }

    func handle(payload: Data) -> Data {
//        totalBytesTreated += UInt32(payload.count)
        let audio = PayloadCollector("audio")
        
        var index:Int = 0
        iteratePayload: repeat {
            
            if self.metadata == nil {
                
                // audio until end
                if nextMetadataAt >= payload.count {
                    if index < payload.count {
                        index += audio.appendUntilEnd(of: payload, idx: index)
                    }
                    nextMetadataAt -= payload.count
                    break iteratePayload
                }
                
                // audio until metadata
                if index < nextMetadataAt {
                    index += audio.appendCount(of: payload, index: index, count: nextMetadataAt - index)
                    continue iteratePayload
                }
                
                guard index == nextMetadataAt else {
                    Logger.loading.error("-guard: index=\(index) and nMd=\(nextMetadataAt) must be equal")
                    break iteratePayload
                }
                
                // begin with metadata
                let mdLength: Int = Int(payload[index]) * 16
                index += 1
//                totalBytesExtracted += 1
                if mdLength == 0 {
                    // empty metadata
                    nextMetadataAt = index + intervalBytes
                    continue iteratePayload
                }
                
                self.metadata = PayloadCollector("metadata", mdLength)
            }

            guard let metadata = metadata,
                  let outstanding = metadata.outstanding else {
                Logger.loading.error("unexpected state in extracting metadata from payload ")
                break iteratePayload
            }
            
            // metadata until end
            if index+outstanding > payload.count {
                index += metadata.appendUntilEnd(of: payload, idx: index)
                nextMetadataAt = index + intervalBytes - payload.count
                break iteratePayload
            }
            
            // metadata until audio
            index += metadata.appendCount(of: payload, index: index, count: outstanding)
            nextMetadataAt = index + intervalBytes
            extracted(metadata)
            self.metadata = nil

        } while (index <= payload.count)
        
        if let md = metadata?.data, md.count > 0 {
            if Logger.verbose { Logger.loading.debug("finished audio with \(audio.data.count) bytes, metadata has \(md.count) bytes") }
        }
//        totalBytesAudio += UInt32(audio.data.count)
        return audio.data
    }
    
    fileprivate func extracted(_ metadata:PayloadCollector) {
//        totalBytesExtracted += UInt32(metadata.data.count)
        let hashed = hash(data: metadata.data)
        guard hashed != lastMetadataHash else {
            return
        }
        lastMetadataHash = hashed
        let flatMd = String(decoding: metadata.data, as: UTF8.self)
        Logger.loading.debug("changed icy metadata string is \(flatMd)")
        let metaDict = parseMetadata(mdString: flatMd)
        if Logger.verbose { Logger.decoding.debug("extracted icy metadata is \(metaDict)") }
        let icyMetadata = IcyMetadata(icyData: metaDict)
        listener?.metadataReady(icyMetadata)
    }
    
    func hash(data : Data) -> Data {
        var hash = [UInt8](repeating: 0,  count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash)
    }
    
    fileprivate func parseMetadata(mdString:String) -> [String:String] {
        let entries = mdString.components(separatedBy: ";")
        var result:[String:String] = [:]
        for entry in entries {
            let property:[String] = entry.split(separator: "=", maxSplits: 1).map(String.init)
            guard property.count == 2 else {
                var value = entry
                if let until = value.firstIndex(of: "\0") {
                    value = String(value[..<until])
                }
                if !value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                    Logger.loading.error("cannot parse metadata entry '\(value)'")
                }
                continue
            }
            let key = property[0]
            var value = property[1]
            if let until = value.firstIndex(of: "\0") {
                value = String(value[..<until])
            }
            switch (key) {
            case "StreamUrl", "StreamTitle":
                result.updateValue(value, forKey: key)
            default:
                Logger.loading.debug("unused metadata key ’\(property[0])' with value '\(property[1])'")
            }
        }
        return result
    }
    
}
