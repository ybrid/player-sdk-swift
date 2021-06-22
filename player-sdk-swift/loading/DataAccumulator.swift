//
// DataAccumulator.swift
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

/*
 Accumulate data chunks until minBlockBytes is reached.
 Exception: First block is passed as is because it should not slow down start up
 
 It improves the performance for streams with small chunks.
 
 Example:
 cpu usage of mp3 chunks of mostly 1152 bytes (72 ms) is reduces by ~0.5%
 by accumulating to 5184 bytes (324 ms)
 
 Important:
 When supply stops, then reset() needs to be called to use remaining chunks.
 */

class DataAccumulator {
    
    let minBlockBytes:Int
    var accBlock:Data? = nil
    
    init(type:AudioFileTypeID) {
        switch type {
        case kAudioFileMP3Type: minBlockBytes = 2304 // 8 * 288
        default: minBlockBytes = 0
        }
        if minBlockBytes > 0 {
            Logger.loading.notice("data chunks will be accumulated until \(minBlockBytes) reached")
        }
    }
    
    init(minBlockBytes:Int) {
        self.minBlockBytes = minBlockBytes
        if minBlockBytes > 0 {
            Logger.loading.notice("data chunks will be accumulated until \(minBlockBytes) reached")
        }
    }
    
    func chunk(_ data:Data) -> Data? {
        guard let tmpAcc = accBlock else {
            accBlock = Data()
            return data
        }
        
        if tmpAcc.count <= minBlockBytes {
            accBlock?.append(data)
            return nil
        }
        
        accBlock = data
        return tmpAcc
    }
    
    func reset() -> Data? {
        let tmpAcc = accBlock
        accBlock = nil
        return tmpAcc
    }
}

