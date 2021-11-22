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
    
    var changeOverFactory:ChangeOverFactory?
    var running:(() -> (Bool))?
    
    init(on endpoint:MediaEndpoint, playerListener:AudioPlayerListener?) {
        self.endpoint = endpoint
        self.playerListener = playerListener
        self.changeOverFactory = ChangeOverFactory(self.notifyChanged(_:clear:) )
    }
    
    func allow( _ running:@escaping ()->(Bool) ) {
        self.running = running
    }
    
    func connect() throws {
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
    
    
    // MARK: actions
       
    func maxBitRate(to bps:Int32) {
        driver?.maxBitRate(to: bps)
        notifyChanged( SubInfo.playout )
    }
    
    func wind(by:TimeInterval, _ audioComplete: AudioCompleteCallback?) -> Bool {
        guard let changeOver = changeOverFactory?.create( { self.driver?.wind(by:by) ?? false }, type: SubInfo.timeshift, userAudioComplete: audioComplete) else {
            Logger.session.error("could not establish wind by \(by.S)")
            return false
        }
        return execute(changeOver)
    }
    
    func windToLive(_ audioComplete: AudioCompleteCallback?) -> Bool {
        guard let changeOver = changeOverFactory?.create( { self.driver?.windToLive() ?? false }, type: SubInfo.timeshift, userAudioComplete: audioComplete) else {
            Logger.session.error("could not establish wind to live")
            return false
        }
        return execute(changeOver)
    }
    
    func wind(to:Date, _ audioComplete: AudioCompleteCallback?) -> Bool {
        guard let changeOver = changeOverFactory?.create( { self.driver?.wind(to:to) ?? false }, type: SubInfo.timeshift, userAudioComplete: audioComplete) else {
            Logger.session.error("could not establish wind to \(to)")
            return false
        }
        return execute(changeOver)
    }
    
    func skipForward(_ type:ItemType?, _ audioComplete: AudioCompleteCallback?) -> Bool {
        guard let changeOver = changeOverFactory?.create( { self.driver?.skipForward(type) ?? false }, type: SubInfo.timeshift, userAudioComplete: audioComplete) else {
            let msgTo = (type != nil) ? type!.rawValue : "item"
            Logger.session.error("could not establish skip forward to \(msgTo)")
            return false
        }
        return execute(changeOver)
    }
    
    func skipBackward(_ type:ItemType?, _ audioComplete: AudioCompleteCallback?) -> Bool {
        guard let changeOver = changeOverFactory?.create( { self.driver?.skipBackward(type) ?? false }, type: SubInfo.timeshift, userAudioComplete: audioComplete) else {
            let msgTo = (type != nil) ? type!.rawValue : "item"
            Logger.session.error("could not establish skip back to \(msgTo)")
            return false
        }
        return execute(changeOver)
    }
    
    func swapItem(_ audioComplete: AudioCompleteCallback?) -> Bool {
        guard let changeOver = changeOverFactory?.create( { self.driver?.swapItem() ?? false }, type: SubInfo.metadata, userAudioComplete: audioComplete) else {
            Logger.session.error("could not establish swap item")
            return false
        }
        return execute(changeOver)
    }

    func swapService(id:String, audioComplete: AudioCompleteCallback?) -> Bool {
        guard let changeOver = changeOverFactory?.create( { self.driver?.swapService(id: id) ?? false }, type: SubInfo.bouquet, userAudioComplete: audioComplete) else {
            Logger.session.error("could not establish swap to service \(id)")
            return false
        }
        return execute(changeOver)
    }
    
    private func execute(_ change:ChangeOver ) -> Bool {

        let success = change.action()
        change.ctrlComplete?()

        if (running?() ?? false) == false {
            change.audioComplete(success)
            return false
        }
        
        if !success {
            change.audioComplete(false)
            return false
        }
        
        changingOver = change // waiting for trigger
        return true
    }
    
    // MARK: metadata handling
    
    func setMetadata(metadata: AbstractMetadata, direct:Bool,
                     lineUp: (LineUp) -> () ) {
        
        driver?.setMetadata(metadata: metadata)
        
        let changeComplete = triggeredChangeComplete(metadata)
        if direct {
            if let callback = changeComplete?.audioComplete {
                callback(true)
            } else {
                notifyChanged(SubInfo.metadata)
            }
        } else {
            if let changedMetadata = mediaState?.metadata {
                mediaState?.clearChanged(SubInfo.metadata)
                lineUp( LineUp(description: changedMetadata.displayTitle,
                               callback: { (success) in
                                    if success {
                                        self.playerListener?.metadataChanged(changedMetadata)
                                    }
                                } )
                        )
            }
            if let changed = changeComplete {
                lineUp( LineUp(description: "\(changed.subtype) complete",
                               callback: { (success) in changed.audioComplete(success)} )
                )
            }
        }
    }
    
    private func triggeredChangeComplete(_ metadata: AbstractMetadata) -> ChangeOver? {
        
        guard let changeOver = changingOver else {
            // no change over in progress
            return nil
        }
        
        let canTrigger = metadata.streamUrl != nil
        Logger.loading.debug("\(canTrigger ?"could":"can't") trigger audio complete")
        guard canTrigger else {
            return nil
        }
        
        guard let state = mediaState,
              changeOver.matches(to: state) else {
               // no matchng media state change
               return nil
        }
        
        self.changingOver = nil
        // execute callback when according audio is playing
        return changeOver
     }
    

    // MARK: change over
    
    var changingOver:ChangeOver? { didSet {
        if let type = changingOver?.subtype {
            Logger.session.debug("change over \(type) in progress")
        } 
        if .timeshift == changingOver?.subtype {
            driver?.timeshifting = true
        } else {
            driver?.timeshifting = false
        }
    }}
    

    
    // MARK: notify audio player listener
    
    func notifyChanged(_ subInfo:SubInfo? = nil, clear:Bool = true) {
        var subInfos:[SubInfo] = SubInfo.allCases
        if let singleInfo = subInfo {
            subInfos.removeAll()
            subInfos.append(singleInfo)
        }
        subInfos.forEach{
            switch $0 {
            case .metadata: notifyChangedMetadata(clear: clear)
            case .timeshift: notifyChangedOffset(clear: clear)
            case .playout: notifyChangedPlayout(clear: clear)
            case .bouquet: notifyChangedServices(clear: clear)
            }
        }
    }
    

    
    private func notifyChangedMetadata(clear:Bool = true) {
         if mediaState?.hasChanged(SubInfo.metadata) == true,
            let metadata = mediaState?.metadata {
             DispatchQueue.global().async {
                 self.playerListener?.metadataChanged(metadata)
                 if clear { self.mediaState?.clearChanged(SubInfo.metadata) }
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

     private func notifyChangedPlayout(clear:Bool = true) {
         if mediaState?.hasChanged(SubInfo.playout) == true,
            let ybridListener = self.playerListener as? YbridControlListener {
             DispatchQueue.global().async {
                 if let swaps = self.mediaState?.swaps {
                     ybridListener.swapsChanged(swaps)
                 }
                 ybridListener.bitRateChanged(currentBitsPerSecond: self.mediaState?.currentBitRate, maxBitsPerSecond: self.mediaState?.maxBitRate)
                 if clear {self.mediaState?.clearChanged(SubInfo.playout) }
             }
         }
     }

     private func notifyChangedServices(clear:Bool = true) {
         if mediaState?.hasChanged(SubInfo.bouquet) == true,
            let ybridListener = self.playerListener as? YbridControlListener,
            let services = mediaState?.bouquet?.services {
             DispatchQueue.global().async {
                 ybridListener.servicesChanged(services)
                 if clear { self.mediaState?.clearChanged(SubInfo.bouquet) }
             }
         }
     }
    
    func notifyError(_ severity:ErrorSeverity, _ error: SessionError) {
        DispatchQueue.global().async {
            self.playerListener?.error(severity, error)
        }
    }

}

