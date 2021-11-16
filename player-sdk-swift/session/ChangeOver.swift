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




typealias Notification = ((SubInfo,_ clear:Bool) -> ())
typealias CtrlComplete = (()->())

class ChangeOverFactory {
    
    let notify:Notification
    init(_ notify: @escaping Notification) {
        self.notify = notify
    }
    
    func create(with subtype:SubInfo, userAudioComplete: AudioCompleteCallback?) -> ChangeOver {
        let ctrlComplete = createCtrlComplete(subtype, notify)
        let audioComplete = createAudioComplete(subtype, notify, userAudioComplete)
        return ChangeOver(subtype, ctrlComplete, audioComplete: audioComplete)
    }
    
    
    private func createCtrlComplete(_ subtype:SubInfo, _ notify: @escaping Notification) -> (()->())? {
        let ctrlComplete: (()->())?
        switch subtype {
        case .metadata:
            ctrlComplete = nil
        case .timeshift:
            ctrlComplete = { notify(SubInfo.timeshift, false) }
        case .bouquet:
            ctrlComplete = nil
        default:
            ctrlComplete = nil
        }
        return ctrlComplete
    }
    
    private func createAudioComplete(_ subtype:SubInfo, _ notify: @escaping Notification, _ userAudioComplete:AudioCompleteCallback?) -> AudioCompleteCallback {
        let audioComplete:AudioCompleteCallback = { (success) in
            Logger.playing.debug("change over \(subtype) complete (\(success ? "successful":"flopped"))")
            
            switch subtype {
            case .bouquet:
                notify(.metadata, false) /// contains changed active service
                notify(.bouquet, true)
            default:
                notify(subtype, true)
            }
            
            if let userCompleteCallback = userAudioComplete {
                DispatchQueue.global().async {
                    userCompleteCallback(success)
                }
            }
        }
        return audioComplete
  
    }
    
}

class ChangeOver {
    
    let subtype:SubInfo
    let ctrlComplete: (() -> ())?
    let audioComplete: AudioCompleteCallback
    
    init(_ subtype:SubInfo, _ ctrlComplete: CtrlComplete?, audioComplete: @escaping AudioCompleteCallback ) {
        self.subtype = subtype
        self.ctrlComplete = ctrlComplete
        self.audioComplete = audioComplete
    }
    
    func matches(to state:MediaState) -> Bool {
        let changed = state.hasChanged(subtype)
        switch subtype {
        case .metadata:
            Logger.session.notice("change over \(subtype), metadata did \(changed ? "":"not ")change")
        case .timeshift:
             Logger.session.notice("change over \(subtype), offset did \(changed ? "":"not ")change")
        case .bouquet:
            Logger.session.notice("change over \(subtype), active service did \(changed ? "":"not ")change")
        default:
            Logger.session.error("change over \(subtype) doesn't match to media state \(state)")
        }
        
        return changed
    }
}
