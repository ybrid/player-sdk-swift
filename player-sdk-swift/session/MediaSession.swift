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
    
    var session:AbstractSession?
    var state:MediaState? { get {
        return session?.state
    }}
    
    weak var playerListener:AudioPlayerListener?
    
    public var mediaProtocol:MediaProtocol? { get {
        return session?.driver.mediaProtocol
    }}

    public var playbackUri:String { get {
        return state?.playbackUri ?? endpoint.uri
    }}
    
    init(on endpoint:MediaEndpoint, playerListener:AudioPlayerListener?) {
        self.endpoint = endpoint
        self.playerListener = playerListener
    }
    
    func connect() throws  {

        do {
            self.session = try factory.createSession(self)
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
        session?.disconnect()
    }
    
    func refresh() {
        session?.refresh()
    }
    
    var changingOver:YbridAudioPlayer.ChangeOver? { didSet {
        Logger.session.debug("change over type \(changingOver?.subInfo.rawValue ?? "(nil)")")
        if let ybrid = session as? YbridSession {
          if .timeshift == changingOver?.subInfo {
              ybrid.timeshifting = true
          } else {
              ybrid.timeshifting = false
          }
        }
    }}
    
    func notifyMetadata(metadataIn: AbstractMetadata) {
        session?.fetchMetadataSync(metadataIn: metadataIn)
    }
    
    private var metadataDict = ThreadsafeDictionary<UUID,AbstractMetadata>(
        DispatchQueue(label: "io.ybrid.metadata.maintaining", qos: PlayerContext.processingPriority)
    )
    
    func maintainMetadata() -> UUID? {
        guard let metadata = state?.metadata else {
            return nil
        }
        let uuid = UUID()
        metadataDict.put(id: uuid, value: metadata)
        session?.clearChanged(SubInfo.metadata)
        return uuid
    }

    func notifyMetadata(uuid:UUID) {
        if let metadata = metadataDict.pop(id:uuid) {
            DispatchQueue.global().async {
                self.playerListener?.metadataChanged(metadata)
            }
        }
    }
    
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
        if session?.hasChanged(SubInfo.metadata) == true,
           let metadata = state?.metadata {
            DispatchQueue.global().async {
                self.playerListener?.metadataChanged(metadata)
                self.session?.clearChanged(SubInfo.metadata)
            }
        }
    }
    
    private func notifyChangedOffset(clear:Bool = true) {
        if session?.hasChanged(SubInfo.timeshift) == true,
           let ybridListener = self.playerListener as? YbridControlListener,
           let offset = state?.offset {
            DispatchQueue.global().async {
                ybridListener.offsetToLiveChanged(offset)
                if clear { self.session?.clearChanged(SubInfo.timeshift) }
            }
        }
    }
    
    private func notifyChangedPlayout() {
        if session?.hasChanged(SubInfo.playout) == true,
           let ybridListener = self.playerListener as? YbridControlListener {
            DispatchQueue.global().async {
                if let swaps = self.state?.swaps {
                    ybridListener.swapsChanged(swaps)
                }
                ybridListener.bitRateChanged(currentBitsPerSecond: self.state?.currentBitRate, maxBitsPerSecond: self.state?.maxBitRate)
                self.session?.clearChanged(SubInfo.playout)
            }
        }
    }
    
    private func notifyChangedServices() {
        if session?.hasChanged(SubInfo.bouquet) == true,
           let ybridListener = self.playerListener as? YbridControlListener,
           let services = state?.bouquet?.services {
            DispatchQueue.global().async {
                ybridListener.servicesChanged(services)
                self.session?.clearChanged(SubInfo.bouquet) }
        }
    }
    
    
    func notifyError(_ severity:ErrorSeverity, _ error: SessionError) {
        DispatchQueue.global().async {
            self.playerListener?.error(severity, error)
        }
    }

}

