//
// ChangeOver.swift
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

class ChangeOver {
    
    let subInfo:SubInfo
    var ctrlComplete: (() -> ())?
    var audioComplete: AudioCompleteCallback
    
    
    init(_ subInfo:SubInfo, ctrlComplete: (()->())? = nil, audioComplete: @escaping AudioCompleteCallback ) {
        self.subInfo = subInfo
        self.ctrlComplete = ctrlComplete
        self.audioComplete = audioComplete
    }
    
    func matches(to state:MediaState) -> AudioCompleteCallback? {
        let changed = state.hasChanged(subInfo)
        switch subInfo {
        case .metadata:
            Logger.session.notice("change over \(subInfo), metadata did \(changed ? "":"not ")change")
        case .timeshift:
             Logger.session.notice("change over \(subInfo), offset did \(changed ? "":"not ")change")
        case .bouquet:
            Logger.session.notice("change over \(subInfo), active service did \(changed ? "":"not ")change")
        default:
            Logger.session.error("change over \(subInfo) doesn't match to media state \(state)")
        }
        
        if changed {
            return self.audioComplete
        }
        return nil
    }
}
