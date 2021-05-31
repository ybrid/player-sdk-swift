//
// AudioController.swift
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
    func play()
    func stop()
    
    var state:PlaybackState { get }
    func close()
}

public protocol LiveControl : SimpleControl {

}

public protocol OnDemandControl : LiveControl {
    func pause()
}

public protocol PlaybackControl: SimpleControl  {
    var canPause:Bool { get }
    func pause()
}

public protocol YbridControl : OnDemandControl {
    var listener:YbridControlListener? { get set }
    var offsetToLiveS:TimeInterval { get }
    func wind(by:TimeInterval)
    func windToLive()
    func wind(to:Date)
    func skipForward(_ type:ItemType?)
    func skipBackward(_ type:ItemType?)
}

public protocol ControlListener : class {
}

public protocol YbridControlListener : ControlListener {
    func offsetToLiveChanged()
}


public extension AudioPlayer {
    static private let controllerQueue = DispatchQueue(label: "io.ybrid.audio.controller")

    typealias PlaybackControllerCallback = (PlaybackControl,MediaProtocol) -> ()
    typealias LiveControllerCallback = (LiveControl) -> ()
    typealias OnDemandControllerCallback = (OnDemandControl) -> ()
    typealias YbridControllerCallback = (YbridControl) -> ()
    
    // Create a matching AudioContoller for a MediaEndpoint.
    //
    // The matching MediaProtocol is detected and a session
    // to control content and metadata of the stream is established.
    //
    // One of the callback methods is called when the controller is available
    //
    static func initialize(for endpoint:MediaEndpoint, listener: AudioPlayerListener? = nil,
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
                playbackControl?(player, session.mediaProtocol!)
            }
        }
    }
    

//    static func initialize(for endpoint:MediaEndpoint, listener: AudioPlayerListener? = nil,
//            liveControl: LiveControllerCallback? = nil,
//            onDemandControl: OnDemandControllerCallback? = nil,
//            ybridControl: YbridControllerCallback? = nil ) throws {
//
//        let session = MediaSession(on: endpoint)
//        do {
//            try session.connect()
//        } catch {
//            if let audioDataError = error as? AudioPlayerError {
//                listener?.error(ErrorSeverity.fatal, audioDataError)
//                throw audioDataError
//            } else {
//                let sessionError = SessionError(ErrorKind.unknown, "cannot connect to endpoint", error)
//                listener?.error(ErrorSeverity.fatal, sessionError )
//                throw sessionError
//            }
//        }
//
//        controllerQueue.async {
//            switch session.mediaProtocol {
//            case .ybridV2:
//                let player = YbridAudioPlayer(session: session, listener: listener)
//                ybridControl?(player)
//            default:
//                let player = AudioPlayer(session: session, listener: listener)
//                if player.pipeline?.infinite == true {
//                    liveControl?(player)
//                } else {
//                    onDemandControl?(player)
//                }
//            }
//        }
//    }
    
    
}

