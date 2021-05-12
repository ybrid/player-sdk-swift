//
// MpegData.swift
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


import AVFoundation

class MpegData : AudioData {
    
    var id:AudioFileStreamID? 
    
    let packages = ThreadsafeDequeue<Package>(
        DispatchQueue(label: "io.ybrid.decoding.packages", qos: PlayerContext.processingPriority)
    )
    
    override init(audioContentType: AudioFileTypeID, listener: AudioDataListener) throws {
        try super.init(audioContentType: audioContentType, listener: listener)
        let context = unsafeBitCast(self, to: UnsafeMutablePointer<AudioData>.self)
        let result = AudioFileStreamOpen(context, audioPropertyCallback, audioPacketCallback, audioContentType, &id)
        guard result == noErr else {
            throw AudioDataError(.cannotOpenStream, result)
        }
    }
    
    deinit {
        Logger.decoding.debug()
        /// At the end of the stream, this function must be called once with null data pointer and zero data byte size to flush any remaining packets out of the parser.ˆ
        AudioFileStreamParseBytes(id!, UInt32(0), nil, [])
        packages.clear()
    }

    
    func parse(data: Data) throws {
        if Logger.verbose { Logger.decoding.debug("parsing \(data.count) bytes") }
        _ = try data.withUnsafeBytes { (body: UnsafeRawBufferPointer) throws -> UnsafeRawBufferPointer in
            /// parse(property:) and addPackets(_,_,_,_) are called via callback methods
            let result:OSStatus = AudioFileStreamParseBytes(id!, UInt32(data.count), body.baseAddress, [])
            guard result == noErr else {
                throw AudioDataError(.parsingFailed, result)
            }
            return body
        }
    }
    
    /// used by audioPropertyCallback
    fileprivate func parse(property: AudioFileStreamPropertyID) {
        switch property {
        case kAudioFileStreamProperty_DataFormat:
            var formatDescription = AudioStreamBasicDescription()
            readAudioProperty(property, &formatDescription)
            if let format = AVAudioFormat(streamDescription: &formatDescription) {
                self.format = format
                Logger.decoding.debug("kAudioFileStreamProperty_DataFormat used: \(format.debugDescription)")
            }
        case kAudioFileStreamProperty_FileFormat:
            var value:UInt32 = 0
            readAudioProperty(property, &value)
            var byteArray:[UInt8] = [UInt8](repeating: 0, count: 4)
            for i in 0...3 {
                byteArray[i] = UInt8(0x0000FF & value >> UInt32((3 - i) * 8))
            }
            let charCode = String(bytes: byteArray, encoding:  .ascii)
            Logger.decoding.debug("kAudioFileStreamProperty_FileFormat \(charCode ?? "(nothing)") unused")
            
        default:
            Logger.decoding.debug("\(AudioData.describeProperty(property)) unused")
        }
    }
    
    
    /// used by audioPacketCallback
    fileprivate func addPackets(_ data: UnsafeRawPointer, _ byteCount: UInt32, _ packetDescriptions: UnsafePointer<AudioStreamPacketDescription>, _ packetCount: UInt32) {
        
        if Logger.verbose { Logger.decoding.debug("data of \(byteCount) bytes has \(packetCount) new packets") }
        for packetIndex in 0 ..< Int(packetCount) {
            let packetDescription = packetDescriptions[packetIndex]
            let packetStart = Int(packetDescription.mStartOffset)
            let packetSize = Int(packetDescription.mDataByteSize)
            let packetData = Data(bytes: data.advanced(by: packetStart), count: packetSize)
            packages.put((packetData, packetDescription))
        }
    }
    
    /// also used by audioPacketCallback (since iOS 14, XCode version 12)
    fileprivate func addPackets(_ data: UnsafeRawPointer, _ byteCount: UInt32, _ packetCount: UInt32) {
        var startOffset = 0
        let dataByteSize = Int(byteCount / packetCount)
        for _ in 0 ..< Int(packetCount) {
            let packetData = Data(bytes: data.advanced(by: startOffset), count: dataByteSize)
            startOffset += dataByteSize
            packages.put((packetData, nil))
        }
    }
    
    /// read a property
    fileprivate func readAudioProperty<T>(_ property: AudioFileStreamPropertyID, _ value: inout T) {
        var propSize: UInt32 = 0
        guard AudioFileStreamGetPropertyInfo(id!, property, &propSize, nil) == noErr else {
            Logger.decoding.error("failed to get info for property \(AudioData.describeProperty(property))")
            return
        }
        
        guard AudioFileStreamGetProperty(id!, property, &propSize, &value) == noErr else {
            Logger.decoding.error("failed to get value \(AudioData.describeProperty(property))")
            return
        }
    }
}


// MARK: callbacks declared by AudioToolbox

func audioPropertyCallback(_ context: UnsafeMutableRawPointer, _ id: AudioFileStreamID, _ property: AudioFileStreamPropertyID, _ flags: UnsafeMutablePointer<AudioFileStreamPropertyFlags>) {
    let audioData = Unmanaged<MpegData>.fromOpaque(context).takeUnretainedValue()
    audioData.parse(property: property)
}

/// for iOS 14,*
func audioPacketCallback(_ context: UnsafeMutableRawPointer, _ byteCount: UInt32, _ packetCount: UInt32, _ data: UnsafeRawPointer, _ packetDescriptions: UnsafeMutablePointer<AudioStreamPacketDescription>?) {
    let audioData = Unmanaged<MpegData>.fromOpaque(context).takeUnretainedValue()
    if let descriptions = packetDescriptions {
        audioData.addPackets(data, byteCount, descriptions, packetCount)
    } else {
        /// not tested yet
        audioData.addPackets(data, byteCount, packetCount)
    }
}
