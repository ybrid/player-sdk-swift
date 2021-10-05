//
// MediaSession.swift
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

// The session establishes the media control protocol with the server.
// It caches meta data and in future will offer media controllers to interact with.

import Foundation

public class MediaSession {

    let factory = MediaControlFactory()
    let endpoint:MediaEndpoint
    
    var mediaState:MediaState?
    var driver: MediaDriver? // visible for unit tests
    
    weak var playerListener:AudioPlayerListener?
    
    public var mediaProtocol:MediaProtocol? { get {
        return driver?.mediaProtocol
    }}

    public var playbackUri:String { get {
        return mediaState?.playbackUri ?? endpoint.uri
    }}
    
    init(on endpoint:MediaEndpoint, playerListener:AudioPlayerListener?) {
        self.endpoint = endpoint
        self.playerListener = playerListener
    }
    
    func connect() throws  {
        do {
            let created = try factory.create(self)
            self.driver = created.0
            self.mediaState = created.1
            try driver?.connect()
        } catch {
            if let playerError = error as? SessionError {
                notifyError(.fatal, playerError)
                throw error
            } else {
                let playerError = SessionError(.unknown, "cannot connect to endpoint \(endpoint)", error)
                notifyError(.fatal, playerError)
                throw playerError
            }
        }
    }
    
    func close() {
        driver?.disconnect()
    }
    
    func refresh() {
        driver?.refresh()
    }
    
    // MARK: changes
       
       func maxBitRate(to bps:Int32) {
           driver?.maxBitRate(to: bps)
       }
       func wind(by:TimeInterval) -> Bool {
           return driver?.wind(by: by) ?? false
       }
       func windToLive() -> Bool {
           return driver?.windToLive() ?? false
       }
       func wind(to:Date) -> Bool {
           return driver?.wind(to:to) ?? false
       }
       func skipForward(_ type:ItemType?) -> Bool {
           return driver?.skipForward(type) ?? false
       }
       func skipBackward(_ type:ItemType?) -> Bool {
           return driver?.skipBackward(type) ?? false
       }
       func swapItem() -> Bool {
           return driver?.swapItem() ?? false
       }
       func swapService(id:String) -> Bool {
           return driver?.swapService(id: id) ?? false
       }
       
    // MARK: metadata
    
    func setMetadata(metadata: AbstractMetadata) {
           driver?.setMetadata(metadata: metadata)
       }
    
    private var metadataDict = ThreadsafeDictionary<UUID,AbstractMetadata>(
        DispatchQueue(label: "io.ybrid.metadata.maintaining", qos: PlayerContext.processingPriority)
    )
    
    func maintainMetadata() -> UUID? {
        guard let metadata = mediaState?.metadata else {
            return nil
        }
        let uuid = UUID()
        metadataDict.put(id: uuid, value: metadata)
        mediaState?.clearChanged(SubInfo.metadata)
        return uuid
    }
    
    func notifyMetadata(uuid:UUID) {
         if let metadata = metadataDict.pop(id:uuid) {
             DispatchQueue.global().async {
                 self.playerListener?.metadataChanged(metadata)
             }
         }
     }

    // MARK: change over
    
    func change(_ running:Bool, _ action:()->(Bool), _ subtype:SubInfo,
                 _ userAudioComplete: AudioCompleteCallback? ) -> Bool {
         
         let success = action()
         let change = newChangeOver(subtype, userAudioComplete)
         change.ctrlComplete?()
         
         if !running {
             change.audioComplete(success)
             return false
         }
         
         if !success {
             change.audioComplete(false)
             return false
         }

         changingOver = change
         return true
     }

    private func newChangeOver(_ subtype: SubInfo, _ userAudioComplete: AudioCompleteCallback?)  ->  ChangeOver {
        
        let audioComplete:AudioCompleteCallback = { (success) in
            Logger.playing.debug("change over \(subtype) complete (\(success ? "with":"no") success)")
            if let userCompleteCallback = userAudioComplete {
                DispatchQueue.global().async {
                    userCompleteCallback(success)
                }
            }
        }
        
        switch subtype {
        case .timeshift:
            return ChangeOver(subtype,
                              ctrlComplete: { self.notifyChanged(SubInfo.timeshift, clear: false) },
                              audioComplete: audioComplete )
        case .metadata:
            return ChangeOver(subtype, audioComplete: audioComplete)
        case .bouquet:
            return ChangeOver(subtype, audioComplete: audioComplete)
        default:
            return ChangeOver(subtype, audioComplete: audioComplete)
        }
    }
    
    var changingOver:ChangeOver? { didSet {
        Logger.session.debug("change over type \(changingOver?.subInfo.rawValue ?? "(nil)")")
        if .timeshift == changingOver?.subInfo {
            driver?.timeshifting = true
        } else {
            driver?.timeshifting = false
        }
    }}
    
    func triggeredAudioComplete(_ metadata: AbstractMetadata) -> AudioCompleteCallback? {
        
        guard let changeOver = changingOver else {
            return nil
        }
        
        let canTrigger = (metadata as? IcyMetadata)?.streamUrl != nil
        Logger.loading.debug("\(canTrigger ?"could":"can't") trigger audio complete")
        guard canTrigger else {
            return nil
        }
        
        guard let state = mediaState,
           let completeCallback = changeOver.matches(to: state) else {
               // no change over in progress or no media state change that matches
               return nil
        }
        
        // change over is completed
        self.changingOver = nil
        return completeCallback
     }
    
    
    // MARK: notify audio player listener
    
    func notifyChanged(_ subInfo:SubInfo? = nil, clear:Bool = true) {
        var subInfos:[SubInfo] = SubInfo.allCases
        if let singleInfo = subInfo {
            subInfos.removeAll()
            subInfos.append(singleInfo)
        }
        subInfos.forEach{
            switch $0 {
            case .metadata: notifyChangedMetadata()
            case .timeshift: notifyChangedOffset(clear: clear)
            case .playout: notifyChangedPlayout()
            case .bouquet: notifyChangedServices()
            }
        }
    }
    
    private func notifyChangedMetadata() {
         if mediaState?.hasChanged(SubInfo.metadata) == true,
            let metadata = mediaState?.metadata {
             DispatchQueue.global().async {
                 self.playerListener?.metadataChanged(metadata)
                 self.mediaState?.clearChanged(SubInfo.metadata)
             }
         }
     }
     
     private func notifyChangedOffset(clear:Bool = true) {
         if mediaState?.hasChanged(SubInfo.timeshift) == true,
            let ybridListener = self.playerListener as? YbridControlListener,
            let offset = mediaState?.offset {
             DispatchQueue.global().async {
                 ybridListener.offsetToLiveChanged(offset)
                 if clear { self.mediaState?.clearChanged(SubInfo.timeshift) }
             }
         }
     }
     
     private func notifyChangedPlayout() {
         if mediaState?.hasChanged(SubInfo.playout) == true,
            let ybridListener = self.playerListener as? YbridControlListener {
             DispatchQueue.global().async {
                 if let swaps = self.mediaState?.swaps {
                     ybridListener.swapsChanged(swaps)
                 }
                 ybridListener.bitRateChanged(currentBitsPerSecond: self.mediaState?.currentBitRate, maxBitsPerSecond: self.mediaState?.maxBitRate)
                 self.mediaState?.clearChanged(SubInfo.playout)
             }
         }
     }
     
     private func notifyChangedServices() {
         if mediaState?.hasChanged(SubInfo.bouquet) == true,
            let ybridListener = self.playerListener as? YbridControlListener,
            let services = mediaState?.bouquet?.services {
             DispatchQueue.global().async {
                 ybridListener.servicesChanged(services)
                 self.mediaState?.clearChanged(SubInfo.bouquet) }
         }
     }
    
    func notifyError(_ severity:ErrorSeverity, _ error: SessionError) {
        DispatchQueue.global().async {
            self.playerListener?.error(severity, error)
        }
    }

}

