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
public typealias AudioCompleteCallback = ((_ didChange:Bool) -> ())

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
        session.ybridListener = listener as? YbridControlListener
        do {
            try session.connect()
        } catch {
            if let audioDataError = error as? AudioPlayerError {
                DispatchQueue.global().async {
                    listener?.error(ErrorSeverity.fatal, audioDataError)
                }
                throw audioDataError
            } else {
                let sessionError = SessionError(ErrorKind.unknown, "cannot connect to endpoint", error)
                DispatchQueue.global().async {
                    listener?.error(ErrorSeverity.fatal, sessionError )
                }
                throw sessionError
            }
        }
        
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
//        if let ybridListener = session.ybridListener {
//            DispatchQueue.global().async {
//                ybridListener.servicesChanged(self.services)
//                ybridListener.swapsChanged(self.swapsLeft)
//            }
//        }
    }

    func refresh() {
        if let ybridListener = super.playerListener as? YbridControlListener {
            DispatchQueue.global().async {
//                ybridListener.offsetToLiveChanged(self.offsetToLiveS)
                if let metadata = self.session.fetchMetadataSync() {
                    ybridListener.metadataChanged(metadata)
                }
                ybridListener.servicesChanged(self.services)
                ybridListener.swapsChanged(self.swapsLeft)
            }
        }
    }
    
    private var offsetToLiveS: TimeInterval { get {
        return session.offsetToLiveS ?? 0.0
    }}

    private var swapsLeft: Int { get {
        return session.swapsLeft ?? -1
    }}

    private var services: [Service] { get {
        return session.services ?? []
    }}
    
    func wind(by:TimeInterval, _ audioComplete: AudioCompleteCallback?) {
        playerQueue.async {
            let changeover = self.newChangeOver(audioComplete)
            changeover.takePlace(self.session.wind(by:by))
        }
    }
    
    func windToLive( _ audioComplete: AudioCompleteCallback?) {
        playerQueue.async {
            let changeover = self.newChangeOver(audioComplete)
            changeover.takePlace(self.session.windToLive())
        }
    }
    
    func wind(to:Date, _ audioComplete: AudioCompleteCallback?) {
        playerQueue.async {
            let changeover = self.newChangeOver(audioComplete)
            changeover.takePlace(self.session.wind(to:to))
        }
    }

    func skipForward(_ type:ItemType?, _ audioComplete: AudioCompleteCallback?) {
        playerQueue.async {
            let changeover = self.newChangeOver(audioComplete)
            changeover.takePlace(self.session.skipForward(type))
        }
    }

    func skipBackward(_ type:ItemType?, _ audioComplete: AudioCompleteCallback?) {
        playerQueue.async {
            let changeover = self.newChangeOver(audioComplete)
            changeover.takePlace(self.session.skipBackward(type))
        }
    }
    
    public func swapItem(_ audioComplete: AudioCompleteCallback?) {
        playerQueue.async {
            let changeover = self.newChangeOver(audioComplete)
            changeover.takePlace(self.session.swapItem())
        }
    }
    public func swapService(to id:String, _ audioComplete: AudioCompleteCallback?) {
        playerQueue.async {
            let changeover = self.newChangeOver(audioComplete)
            changeover.takePlace(self.session.swapService(id:id))
        }
    }
    
    private func newChangeOver(_ audioComplete: AudioCompleteCallback?) -> ChangeOver {
        return ChangeOver(audioComplete, player: self)
    }
    
    
    class ChangeOver {
        var audioComplete: AudioCompleteCallback?
        let player:AudioPlayer
        init(_ audioComplete: AudioCompleteCallback?, player:AudioPlayer) {
            self.audioComplete = audioComplete
            self.player = player
        }
        
        func takePlace(_ inProgress:Bool) {
            if !inProgress {
                DispatchQueue.global().async {
                    self.audioComplete?(false)
                }
                return
            }
            
            if player.state == .buffering || player.state == .playing {
                player.pipeline?.changeOver = audioComplete
            } else {
                DispatchQueue.global().async {
                    self.audioComplete?(true)
                }
            }
        }
    }
}



