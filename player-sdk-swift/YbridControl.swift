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
    
    /// limit bit rate of audio content
    func maxBitRate(to:Int32)
    
    /// refresh all states, all methods of the YbridControlListener are called
    func select()
}
public typealias AudioCompleteCallback = ((_ success:Bool) -> ())

// supported range of bit-rates in bits per second
//public let bitRatesRange:ClosedRange<Int32> = 8_000...448_000
public let bitRatesRange:ClosedRange<Int32> = 32_000...192_000

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
    func bitRateChanged(currentBitsPerSecond:Int32?,  maxBitsPerSecond:Int32?)
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
    // listener - object to be called back from the player process
    static func open(for endpoint:MediaEndpoint, listener: AudioPlayerListener?,
            playbackControl: PlaybackControlCallback? = nil,
              ybridControl: YbridControlCallback? = nil ) throws {
        
        let session = MediaSession(on: endpoint, playerListener: listener)
        try session.connect()
        controllerQueue.async {
            switch session.mediaProtocol {
            case .ybridV2:
                let player = YbridAudioPlayer(session: session)
                ybridControl?(player)
            case .plain, .icy:
                let player = AudioPlayer(session: session)
                playbackControl?(player)
            default:
                return
            }
        }
    }

    // This is a convenience method for tests. It provides a playback control
    // for all endpoints, regardless of the media protocol.
    //
    // You recieve a PlaybackContol in all cases. You cannot use ybrid specific actions.
    //
    // listener - object to be called back from the player process
    static func open(for endpoint:MediaEndpoint, listener: AudioPlayerListener?,
            control: PlaybackControlCallback? = nil ) throws {
        try AudioPlayer.open(for: endpoint, listener: listener, playbackControl: control, ybridControl: control)
    }
}

// MARK: YbridAudioPlayer

class YbridAudioPlayer : AudioPlayer, YbridControl {

    override init(session:MediaSession) {
         super.init(session: session)
         session.notifyChanged( SubInfo.bouquet )
         session.notifyChanged( SubInfo.timeshift )
         session.notifyChanged( SubInfo.playout )
     }

     func select() {
         DispatchQueue.global().async {
             if let metadata = self.session.mediaState?.metadata {
                 super.playerListener?.metadataChanged(metadata)
             }
             if let ybridListener = super.playerListener as? YbridControlListener,
                let state = self.session.mediaState {
                 ybridListener.offsetToLiveChanged(state.offset)
                 ybridListener.servicesChanged(state.bouquet?.services ?? [])
                 ybridListener.swapsChanged(state.swaps ?? -1)
                 ybridListener.bitRateChanged(currentBitsPerSecond: state.currentBitRate, maxBitsPerSecond: state.maxBitRate)
             }
         }
     }
     
     func maxBitRate(to maxRate:Int32) {
         playerQueue.async { [self] in
             session.maxBitRate(to: maxRate)
             session.notifyChanged( SubInfo.playout )
         }
     }

     func wind(by:TimeInterval, _ audioComplete: AudioCompleteCallback?) {
         playerQueue.async { [self] in
             if session.change ( running,
                     { return session.wind(by:by) }, SubInfo.timeshift, audioComplete ) {
                 self.pipeline?.changeOverInProgress()
             }
         }
     }
     
     func windToLive( _ audioComplete: AudioCompleteCallback?) {
         playerQueue.async { [self] in
             if session.change ( running,
                     { return session.windToLive() }, SubInfo.timeshift, audioComplete ) {
                 pipeline?.changeOverInProgress()
             }
         }
     }
     
     func wind(to:Date, _ audioComplete: AudioCompleteCallback?) {
         playerQueue.async { [self] in
             if session.change ( running,
                     { return session.wind(to:to) }, SubInfo.timeshift, audioComplete ) {
                 pipeline?.changeOverInProgress()
             }
         }
     }

     func skipForward(_ type:ItemType?, _ audioComplete: AudioCompleteCallback?) {
         playerQueue.async { [self] in
             if session.change ( running,
                     { return session.skipForward(type) }, SubInfo.timeshift, audioComplete ) {
                 pipeline?.changeOverInProgress()
             }
         }
     }

     func skipBackward(_ type:ItemType?, _ audioComplete: AudioCompleteCallback?) {
         playerQueue.async { [self] in
             if session.change ( running,
                     { return session.skipBackward(type) }, SubInfo.timeshift, audioComplete ) {
                 pipeline?.changeOverInProgress()
             }
         }
     }
     
     public func swapItem(_ audioComplete: AudioCompleteCallback?) {
         playerQueue.async { [self] in
             if session.change ( running,
                     { return session.swapItem() }, SubInfo.metadata, audioComplete ) {
                 pipeline?.changeOverInProgress()
             }
         }
         
     }
     public func swapService(to id:String, _ audioComplete: AudioCompleteCallback?) {
         playerQueue.async { [self] in
             if session.change ( running,
                     { return session.swapService(id:id) }, SubInfo.bouquet, audioComplete ) {
                 pipeline?.changeOverInProgress()
             }
         }
     }

}


public extension SimpleControl {
    var running:Bool { get {
        return self.state == .buffering || self.state == .playing
    }}
}

