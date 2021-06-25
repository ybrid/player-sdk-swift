//
// AudioPlayer.swift
// player-sdk-swift
//
// Copyright (c) 2020 nacamar GmbH - Ybrid®, a Hybrid Dynamic Live Audio Technology
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

// Playing audio.

import AVFoundation

// called back while processing
public protocol AudioPlayerListener : class {
    // the playback state has changed
    func stateChanged(_ state: PlaybackState)
    // metadata of the content currently playing has changed
    func metadataChanged(_ metadata: Metadata)
    // all exceptions contain code, errorReason and localizedDescription, called when occuring
    func error(_ severity:ErrorSeverity, _ exception: AudioPlayerError)
    // duration of audio presented already, called every 0.2 seconds
    func playingSince(_ seconds: TimeInterval?)
    // duration between triggering play and first audio presented
    func durationReadyToPlay(_ seconds: TimeInterval?)
    // duration between triggering play and first response from the media url
    func durationConnected(_ seconds: TimeInterval?)
    // duration of playback cached, currently and averaged over the last 3 seconds. Called every 0.2 seconds.
    func bufferSize(averagedSeconds: TimeInterval?, currentSeconds: TimeInterval?)
}

public enum PlaybackState {
    case buffering // audio will play (preparing or stalling)
    case playing // audio is playing
    case stopped // no audio will play
    case pausing // no audio will play
}


public class AudioPlayer: PlaybackControl, BufferListener, PipelineListener {

    public static var versionString:String {
        get {
            let bundleId = "io.ybrid.player-sdk-swift"
            guard let info = Bundle(identifier: bundleId)?.infoDictionary else {
                Logger.shared.error("bundle \(bundleId) not found")
                return "bundle \(bundleId) not found"
            }
            Logger.shared.debug("bundle \(bundleId) info \(info)")
            let version = info["CFBundleShortVersionString"] ?? "(unknown)"
            let name = info["CFBundleName"] ?? "(unknown)"
            let build = info["CFBundleVersion"]  ?? "(unknown)"
            return "\(name) version \(version) (build \(build))"
        }
    }
    
    // Create an AudioPlayer for a MediaEndpoint.
    //
    // The matching MediaProtocol is detected and a session
    // to control content and metadata of the stream is established.
    @available(*, deprecated, message: "use asynchronous AudioPlayer.open instead")
    public static func openSync(for endpoint:MediaEndpoint, listener: AudioPlayerListener?) -> AudioPlayer? {
        
        let session = MediaSession(on: endpoint)
        do {
            try session.connect()
        } catch {
            if let audioDataError = error as? AudioPlayerError {
                listener?.error(ErrorSeverity.fatal, audioDataError)
            } else {
                listener?.error(ErrorSeverity.fatal, SessionError(ErrorKind.unknown, "cannot connect to endpoint", error))
            }
            return nil
        }

        switch session.mediaProtocol {
        case .plain, .icy:
            return AudioPlayer(session: session, listener: listener)
        case .ybridV2:
            return YbridAudioPlayer(session: session, listener: listener)
        default:
            return nil
        }
    }

    public var state: PlaybackState { get {
        return playbackState
    }}
    
    public var mediaProtocol:MediaProtocol? { get {
        return session.mediaControl?.mediaProtocol
    }}
    
    public var mediaEndpoint: MediaEndpoint { get {
        return session.endpoint
    }}
    
    var session:MediaSession
    public var canPause:Bool = false
    
    var loader: AudioDataLoader?
    var pipeline: AudioPipeline?
    var playback: Playback?
    
    weak var playerListener:AudioPlayerListener?
    let playerQueue = DispatchQueue(label: "io.ybrid.playing")
    
    private var playbackState: PlaybackState = .stopped {
        didSet {
            if oldValue != playbackState {
                Logger.shared.notice("\(playbackState)")
                DispatchQueue.global().async {
                    self.playerListener?.stateChanged(self.state)
                }
            }
        }
    }
    
    // get ready for playing audio. Supports codecs mp3, aac and opus.
    // session - the MediaSession connected to the MediaEndpoint. Supports icecast, plain http and ybrid
    // listener - object to be called back from the player process
    init(session: MediaSession, listener: AudioPlayerListener?) {
        self.playerListener = listener
        self.session = session
        PlayerContext.setupAudioSession()
    }

    deinit {
        Logger.shared.debug()
        PlayerContext.deactivate()
    }
    
    // MARK: actions
    
    // Asynchronously start playback of audio of the given media url as soon as possible.
    public func play() {
        guard playbackState == .stopped || playbackState == .pausing else {
            Logger.shared.notice("already running")
            return
        }
        if playbackState == .stopped {
            playbackState = .buffering
            self.pipeline = AudioPipeline(pipelineListener: self, playerListener:                                     playerListener, session: session)
            let playbackUrl = URL(string: session.playbackUri)!
            playerQueue.async {
                self.playWhenReady(playbackUrl)
            }
        }
        if playbackState == .pausing {
            playerQueue.async {
                self.playback?.resume()
            }
        }
    }
    
      // Stop, notify immediatly, stop playback and clean up asychronously.
    public func stop() {
        guard playbackState != .stopped  else {
            Logger.shared.debug("already stopped")
            return
        }
        pipeline?.stopProcessing()
        playerQueue.async {
            self.stopPlaying()
            self.playbackState = .stopped
        }
    }
    
    // Pause playback immediatly. Next play resumes.
    // For on demand contents only. Loading continues in backgroud.
    public func pause() {
        guard canPause else {
            Logger.shared.error("cannot pause")
            return
        }
        guard playbackState != .stopped  else {
            Logger.shared.debug("is stopped")
            return
        }
        playerQueue.async {
            self.playback?.pause()
        }
    }
   
    // Stopping and releasing all ressources
    public func close() {
        if playbackState != .stopped {
            pipeline?.stopProcessing()
            playerQueue.async {
                self.stopPlaying()
                self.playbackState = .stopped
            }
        }
        session.close()
    }
    
    private func playWhenReady(_ playbackUrl: URL) {
        loader = AudioDataLoader(mediaUrl: playbackUrl, pipeline: pipeline!, inclMetadata: true)
        loader?.requestData(from: playbackUrl)
    }
    
    private func stopPlaying() {
        playback?.stop()
        loader?.stopRequestData()
        pipeline?.dispose()
    }
    
    // MARK: pipeline listener
    
    func ready(playback: Playback) {
        
        if playback.canPause {
            canPause = true
        }
        
        switch playbackState {
        case .buffering:
            self.playback = playback
            playback.setListener(listener: self)
        case .playing:
            Logger.shared.error("should not play already.")
        case .stopped, .pausing:
            Logger.shared.error("is \(playbackState), should not begin playing.")
            pipeline?.stopProcessing()
            playback.stop()
            loader?.stopRequestData()
            pipeline?.dispose()
            return
        }
    }
    
    func error(_ severity: ErrorSeverity, _ error: AudioPlayerError) {
        let logMessage = "\(severity) \(error.localizedDescription)"
        DispatchQueue.global().async {
            self.playerListener?.error(severity, error)
        }
        switch severity {
        case .notice:
            Logger.shared.info(logMessage)
        case .recoverable:
            Logger.shared.notice(logMessage)
        case .fatal:
            Logger.shared.error(logMessage)
            stop()
        }
    }
    
    // MARK: BufferListener
    
    func stateChanged(_ bufferState: PlaybackBuffer.BufferState) {
        
        switch playbackState {
        case .stopped, .pausing, .buffering:
            if bufferState == .ready {
                playbackState = .playing
            }
        case .playing:
            if bufferState == .empty {
                if loader?.completed == true {
                    playback?.stop()
                    playbackState = .stopped
                } else {
                    playbackState = .buffering
                }
            }
            if bufferState == .wait {
                playbackState = .pausing
            }
        }
    }
}

