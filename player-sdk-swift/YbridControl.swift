//
// YbridControl.swift
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


public protocol SimpleControl {
    var mediaEndpoint:MediaEndpoint { get }
    var mediaProtocol:MediaProtocol? { get }
    
    func play()
    func stop()
    
    var state:PlaybackState { get }
    func close()
}

public protocol PlaybackControl: SimpleControl  {
    var canPause:Bool { get }
    func pause()
}

// MARK: ybrid control

public protocol YbridControl : PlaybackControl {
    
    /// time shifting
    func wind(by:TimeInterval, _ audioComplete: AudioCompleteCallback?)
    func windToLive(_ audioComplete: AudioCompleteCallback?)
    func wind(to:Date, _ audioComplete: AudioCompleteCallback?)
    func skipForward(_ type:ItemType?, _ audioComplete: AudioCompleteCallback?)
    func skipBackward(_ type:ItemType?, _ audioComplete: AudioCompleteCallback?)
    
    /// change content
    func swapItem(_ audioComplete: AudioCompleteCallback?)
    func swapService(to id:String, _ audioComplete: AudioCompleteCallback?)
    
    /// refresh all states, all methods of the YbridControlListener are called
    func refresh()
}
public typealias AudioCompleteCallback = ((_ success:Bool) -> ())

public extension YbridControl {
    /// allow actions without default or audioComplete parameters
    func wind(by:TimeInterval) { wind(by:by, nil) }
    func windToLive() { windToLive(nil) }
    func wind(to:Date) { wind(to:to, nil) }
    func swapItem() { swapItem(nil) }
    func swapService(to id:String) { swapService(to:id, nil) }
    func skipBackward() { skipBackward(nil, nil) }
    func skipBackward(_ type:ItemType) { skipBackward(type, nil) }
    func skipBackward(_ audioComplete: @escaping AudioCompleteCallback) { skipBackward(nil, audioComplete) }
    func skipForward() { skipForward(nil, nil) }
    func skipForward(_ type:ItemType) { skipForward(type, nil) }
    func skipForward(_ audioComplete: @escaping AudioCompleteCallback) { skipForward(nil, audioComplete) }
}

public protocol YbridControlListener : AudioPlayerListener {
    func offsetToLiveChanged(_ offset:TimeInterval?)
    func servicesChanged(_ services:[Service])
    func swapsChanged(_ swapsLeft:Int)
}

// MARK: open

public extension AudioPlayer {
    static private let controllerQueue = DispatchQueue(label: "io.ybrid.audio.controller")

    typealias PlaybackControlCallback = (PlaybackControl) -> ()
    typealias YbridControlCallback = (YbridControl) -> ()
    
    // Create an audio control matching to the MediaEndpoint.
    //
    // First the MediaProtocol is detected and a session is established
    // to handle audio content and metadata of the stream.
    //
    // One of the callback methods provides the specific controller as soon
    // as available.
    //
    static func open(for endpoint:MediaEndpoint, listener: AudioPlayerListener?,
            playbackControl: PlaybackControlCallback? = nil,
              ybridControl: YbridControlCallback? = nil ) throws {
        
        let session = MediaSession(on: endpoint)
        session.playerListener = listener
        try session.connect()
        
        controllerQueue.async {
            switch session.mediaProtocol {
            case .ybridV2:
                let player = YbridAudioPlayer(session: session, listener: listener)
                ybridControl?(player)
            default:
                let player = AudioPlayer(session: session, listener: listener)
                playbackControl?(player)
            }
        }
    }

    /*
     This is a convenience method for tests. It provides a playback control
     for all endpoints, regardless of the media protocol.
     
     You recieve a PlaybackContol in all cases. You cannot use ybrid specific actions.
     */
    static func open(for endpoint:MediaEndpoint, listener: AudioPlayerListener?,
            control: PlaybackControlCallback? = nil ) throws {
        try AudioPlayer.open(for: endpoint, listener: listener, playbackControl: control, ybridControl: control)
    }
}

// MARK: YbridAudioPlayer

class YbridAudioPlayer : AudioPlayer, YbridControl {

    override init(session:MediaSession, listener:AudioPlayerListener?) {
        super.init(session: session, listener: listener)
        if let ybridListener = session.playerListener as? YbridControlListener {
            DispatchQueue.global().async {
                ybridListener.offsetToLiveChanged(session.offset)
            }
        }
    }

    func refresh() {
        DispatchQueue.global().async {
            if let metadata = self.session.metadata {
                super.playerListener?.metadataChanged(metadata)
            }
            if let ybridListener = super.playerListener as? YbridControlListener {
                ybridListener.offsetToLiveChanged(self.session.offset)
                ybridListener.servicesChanged(self.session.services ?? [])
                ybridListener.swapsChanged(self.session.swaps ?? -1)
            }
        }
    }
    
    
    func wind(by:TimeInterval, _ audioComplete: AudioCompleteCallback?) {
        playerQueue.async {
            let changeover = self.newChangeOver(audioComplete, SubInfo.timeshift)
            changeover.inProgress(self.session.wind(by:by))
        }
    }
    
    func windToLive( _ audioComplete: AudioCompleteCallback?) {
        playerQueue.async {
            let changeover = self.newChangeOver(audioComplete, SubInfo.timeshift)
            changeover.inProgress(self.session.windToLive())
        }
    }
    
    func wind(to:Date, _ audioComplete: AudioCompleteCallback?) {
        playerQueue.async {
            let changeover = self.newChangeOver(audioComplete, SubInfo.timeshift)
            changeover.inProgress(self.session.wind(to:to))
        }
    }

    func skipForward(_ type:ItemType?, _ audioComplete: AudioCompleteCallback?) {
        playerQueue.async {
            let changeover = self.newChangeOver(audioComplete, SubInfo.timeshift)
            changeover.inProgress(self.session.skipForward(type))
        }
    }

    func skipBackward(_ type:ItemType?, _ audioComplete: AudioCompleteCallback?) {
        playerQueue.async {
            let changeover = self.newChangeOver(audioComplete, SubInfo.timeshift)
            changeover.inProgress(self.session.skipBackward(type))
        }
    }
    
    public func swapItem(_ audioComplete: AudioCompleteCallback?) {
        playerQueue.async {
            let changeover = self.newChangeOver(audioComplete, SubInfo.metadata)
            changeover.inProgress(self.session.swapItem())
        }
    }
    public func swapService(to id:String, _ audioComplete: AudioCompleteCallback?) {
        playerQueue.async {
            let changeover = self.newChangeOver(audioComplete, SubInfo.metadata)
            changeover.inProgress(self.session.swapService(id:id))
        }
    }
        
    
    
    private func newChangeOver(_ userAudioComplete: AudioCompleteCallback?, _ subtype:SubInfo ) -> ChangeOver {
        switch subtype {
        case .timeshift:
            let wrappedComplete:AudioCompleteCallback = { (success) in
                Logger.playing.debug("timeshift complete (success:\(success))")
                DispatchQueue.global().async {
                    userAudioComplete?(success)
                }
                self.session.notifyOffset(complete:true)
            }
            return ChangeOver(player: self, subtype,
                              ctrlComplete: { self.session.notifyOffset(complete:false) },
                              audioComplete: wrappedComplete )
        case .metadata:
            let wrappedComplete:AudioCompleteCallback = { (success) in
                Logger.playing.debug("swap complete (success:\(success))")
                DispatchQueue.global().async {
                    userAudioComplete?(success)
                }
            }
            return ChangeOver(player: self, subtype, audioComplete: wrappedComplete)
        default:
            let wrappedComplete:AudioCompleteCallback = { (success) in
                Logger.playing.debug("calling audio complete (success:\(success))")
                DispatchQueue.global().async {
                    userAudioComplete?(success)
                }
            }
            return ChangeOver(player: self, subtype, audioComplete: wrappedComplete)
        }
    }

    
    
    class ChangeOver {
        
        private let player:AudioPlayer
        let subInfo:SubInfo
        var ctrlComplete: (() -> ())?
        var audioComplete: AudioCompleteCallback?
        
        init(player:YbridAudioPlayer,_ subInfo:SubInfo, ctrlComplete: (()->())? = nil, audioComplete: AudioCompleteCallback? ) {
            self.player = player
            self.subInfo = subInfo
            self.ctrlComplete = ctrlComplete
            self.audioComplete = audioComplete
        }
        
        fileprivate func inProgress(_ inProgress:Bool) {
            guard let audioComplete = audioComplete else {
                return
            }
            
            if !inProgress {
                audioComplete(false)
                return
            }
            
            if player.state == .buffering || player.state == .playing {
                ctrlComplete?()
                player.pipeline?.changingOver( audioComplete, subInfo )
            } else {
                audioComplete(true)
            }
        }
    }

}



