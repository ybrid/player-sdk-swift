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
    
    func select()
    
    var offsetToLiveS:TimeInterval { get }
    func wind(by:TimeInterval)
    func windToLive()
    func wind(to:Date)
    func skipForward(_ type:ItemType?)
    func skipBackward(_ type:ItemType?)
    
    func swapItem(_ callback: (()->())?)
    var services:[Service] { get }
    func swapService(to id:String, _ callback: (()->())?)
}

public protocol YbridControlListener : AudioPlayerListener {
    func offsetToLiveChanged(_ offset:TimeInterval?)
    func servicesChanged(_ services:[Service])
}

// MARK: open

public extension AudioPlayer {
    static private let controllerQueue = DispatchQueue(label: "io.ybrid.audio.controller")

    typealias PlaybackControllerCallback = (PlaybackControl) -> ()
    typealias YbridControllerCallback = (YbridControl) -> ()
    
    // Create an audio control matching to the MediaEndpoint.
    //
    // First the MediaProtocol is detected and a session is established
    // to handle audio content and metadata of the stream.
    //
    // One of the callback methods provides the specific controller as soon
    // as available.
    //
    static func open(for endpoint:MediaEndpoint, listener: AudioPlayerListener?,
            playbackControl: PlaybackControllerCallback? = nil,
              ybridControl: YbridControllerCallback? = nil ) throws {
        
        let session = MediaSession(on: endpoint)
        do {
            try session.connect()
        } catch {
            if let audioDataError = error as? AudioPlayerError {
                listener?.error(ErrorSeverity.fatal, audioDataError)
                throw audioDataError
            } else {
                let sessionError = SessionError(ErrorKind.unknown, "cannot connect to endpoint", error)
                listener?.error(ErrorSeverity.fatal, sessionError )
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
            control: PlaybackControllerCallback? = nil ) throws {
        try AudioPlayer.open(for: endpoint, listener: listener, playbackControl: control, ybridControl: control)
    }
}

// MARK: YbridAudioPlayer

class YbridAudioPlayer : AudioPlayer, YbridControl {
    
    override init(session:MediaSession, listener:AudioPlayerListener?) {
        if let ybridListener = listener as? YbridControlListener {
            session.ybridListener = ybridListener
        }
        super.init(session: session, listener: listener)
        session.ybridListener?.servicesChanged(services)
    }
    
    func select() {
        session.ybridListener?.servicesChanged(services)
        session.ybridListener?.offsetToLiveChanged(offsetToLiveS)
        if let metadata = session.fetchMetadataSync() {
            super.playerListener?.metadataChanged(metadata)
        }
    }
    
    var offsetToLiveS: TimeInterval { get {
        playerQueue.sync {
            return (session.mediaControl as? YbridV2Driver)?.offsetToLiveS ?? 0.0
        }
    }}
 
    var services: [Service] { get {
        playerQueue.sync {
            return session.services ?? []
        }
    }}
    
    
    func wind(by:TimeInterval) {
        playerQueue.async {
            self.session.wind(by:by)
        }
    }
    
    func windToLive() {
        playerQueue.async {
            self.session.windToLive()
        }
    }
    
    func wind(to:Date) {
        playerQueue.async {
            self.session.wind(to:to)
        }
    }
    
    func skipForward(_ type:ItemType?) {
        playerQueue.async {
            self.session.skipForward(type)
        }
    }

    func skipBackward(_ type:ItemType?) {
        playerQueue.async {
            self.session.skipBackward(type)
        }
    }
    
    func swapItem(_ carriedOut: (()->())? = nil) {
        playerQueue.async {
            if self.session.swapItem() == true,
               let swappedContentIn = self.pipeline?.bufferSize {
                self.playerQueue.asyncAfter(deadline: .now() + swappedContentIn ) {
                    carriedOut?()
                }
            } else {
                carriedOut?()
            }
        }
    }
    public func swapService(to id:String, _ carriedOut: (()->())? = nil) {
        playerQueue.async {
            if self.session.swapService(id:id) == true,
               let swappedContentIn = self.pipeline?.bufferSize {
                self.playerQueue.asyncAfter(deadline: .now() + swappedContentIn ) {
                    carriedOut?()
                }
            } else {
                carriedOut?()
            }
        }
    }
}
