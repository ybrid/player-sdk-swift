//
// EmptyDriver.swift
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


class IcyDriver : MediaDriver {
    
    let icyState: IcyState
    init(icyState: IcyState) {
        self.icyState = icyState
        super.init(version: .icy)
    }
    
    override func connect() throws {
        if connected {
            return
        }
        
        connected = true
    }
    
    override func disconnect() {
        if !connected {
            return
        }
        connected = false
    }
    
    override func refresh() { }
    override func setMetadata(metadata: AbstractMetadata) {
        icyState.accept(metadata:metadata)
    }
    
    override func maxBitRate(to bps:Int32) { Logger.shared.error("should not be called") }
    
    override func wind(by:TimeInterval) -> Bool { Logger.shared.error("should not be called"); return false }
    override func windToLive() -> Bool { Logger.shared.error("should not be called"); return false }
    override func wind(to:Date) -> Bool { Logger.shared.error("should not be called"); return false }
    override func skipForward(_ type:ItemType?) -> Bool { Logger.shared.error("should not be called"); return false }
    override func skipBackward(_ type:ItemType?) -> Bool { Logger.shared.error("should not be called"); return false }
    
    override func swapItem() -> Bool { Logger.shared.error("should not be called"); return false }
    override func swapService(id:String) -> Bool { Logger.shared.error("should not be called"); return false }
    
}
