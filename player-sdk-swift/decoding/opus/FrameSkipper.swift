//
// FrameSkipper.swift
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

import AVFoundation

class FrameSkipper {
    
    private let bytesPerSample:Int
    private let audioBufferFactory: (Int) throws -> AVAudioPCMBuffer
    private var framesExamined:Int64 = 0
    private var framesToSkip:Int = 0
    
    init( bytesPerSample:Int, audioBufferFactory: @escaping (Int) throws -> AVAudioPCMBuffer ) {
        self.bytesPerSample = bytesPerSample
        self.audioBufferFactory = audioBufferFactory
    }
    
    deinit {
        Logger.decoding.debug()
    }
    
    func skip(frames newFrames:Int)  {
        framesToSkip += newFrames
    }
    
    func execute(on pcmBuffer:inout AVAudioPCMBuffer, endOfPacketFramePosition:Int64?) throws {
        
        framesExamined += Int64(pcmBuffer.frameLength)
        
        if let granule = endOfPacketFramePosition, granule != -1 && granule < framesExamined {
                Logger.decoding.notice("trimming \(framesExamined-granule) frames")
                let replacingBuffer = try cloneBuffer(&pcmBuffer, cutEndingFrames: Int(framesExamined-granule))
                pcmBuffer = replacingBuffer
        }
        
        guard framesToSkip > 0 else {
            return
        }
        
        let length = pcmBuffer.frameLength
        
        if framesToSkip >= length {
            return try skipWholeBuffer(&pcmBuffer, length)
        }
        
        let replacingBuffer = try cloneBuffer(&pcmBuffer, cutBeginningFrames: framesToSkip)
        pcmBuffer = replacingBuffer
        framesToSkip = 0
    }
    
    fileprivate func skipWholeBuffer(_ pcmBuffer: inout AVAudioPCMBuffer, _ length: AVAudioFrameCount) throws {
        let bytes = pcmBuffer.audioBufferList.pointee.mBuffers.mDataByteSize
        Logger.decoding.debug("skipping audio buffer of \(length) audio frames (\(bytes) bytes)")
        
        let emptyBuffer = try audioBufferFactory(0)
        pcmBuffer = emptyBuffer
        
        let notYetSkipped = framesToSkip - Int(length)
        if notYetSkipped <= 0 {
            framesToSkip = 0
            return
        }
        framesToSkip = notYetSkipped
        Logger.decoding.debug("still \(notYetSkipped) audio frames to skip")
        return
    }

    fileprivate func cloneBuffer(_ pcmBuffer: inout AVAudioPCMBuffer, cutBeginningFrames frameOffset: Int) throws -> AVAudioPCMBuffer {
        
        let bytesOffset = frameOffset * bytesPerSample
        let cloneLength = Int(pcmBuffer.frameLength) - frameOffset
        let cloneBytes = Int(cloneLength) * bytesPerSample

        let bufferList = pcmBuffer.mutableAudioBufferList
        let nBuffers = Int(bufferList.pointee.mNumberBuffers)
        let audioBuffers = UnsafeBufferPointer<AudioBuffer>(start: &bufferList.pointee.mBuffers, count: nBuffers)
        
        let newBuffer = try audioBufferFactory(cloneLength)
        let newBufferList = newBuffer.mutableAudioBufferList
        let newAudioBuffers = UnsafeBufferPointer<AudioBuffer>(start: &newBufferList.pointee.mBuffers, count: nBuffers)
        
        for ch in 0..<nBuffers {
            if let sourceData = audioBuffers[ch].mData {
                newAudioBuffers[ch].mData?.copyMemory(from: sourceData + bytesOffset, byteCount: cloneBytes)
            }
        }
        return newBuffer
    }
    
    fileprivate func cloneBuffer(_ pcmBuffer: inout AVAudioPCMBuffer, cutEndingFrames trimmFrames: Int) throws -> AVAudioPCMBuffer {

        let cloneLength = Int(pcmBuffer.frameLength) - trimmFrames
        guard cloneLength >= 0 else {
            throw DecoderError(.invalidData)
        }
        let cloneBytes = Int(cloneLength) * bytesPerSample

        let bufferList = pcmBuffer.mutableAudioBufferList
        let nBuffers = Int(bufferList.pointee.mNumberBuffers)
        let audioBuffers = UnsafeBufferPointer<AudioBuffer>(start: &bufferList.pointee.mBuffers, count: nBuffers)
        
        let newBuffer = try audioBufferFactory(cloneLength)
        let newBufferList = newBuffer.mutableAudioBufferList
        let newAudioBuffers = UnsafeBufferPointer<AudioBuffer>(start: &newBufferList.pointee.mBuffers, count: nBuffers)
        
        for ch in 0..<nBuffers {
            if let sourceData = audioBuffers[ch].mData {
                newAudioBuffers[ch].mData?.copyMemory(from: sourceData, byteCount: cloneBytes)
            }
        }
        return newBuffer
    }
    
}


