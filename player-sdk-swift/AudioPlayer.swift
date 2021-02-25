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


import AVFoundation

public protocol AudioPlayerListener : class {
    func stateChanged(_ state: PlaybackState)
    func displayTitleChanged(_ title: String?)
    func currentProblem(_ text: String?)
    func durationConnected(_ seconds: TimeInterval?)
    func durationReady(_ seconds: TimeInterval?)
    func durationPlaying(_ seconds: TimeInterval?)
    func durationBuffer(averagedSeconds: TimeInterval?, currentSeconds: TimeInterval?)
}

public enum PlaybackState {
    case buffering
    case playing
    case stopped
}

public class AudioPlayer: BufferListener, PipelineListener {

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

    public var state: PlaybackState = .stopped {
        didSet {
            Logger.shared.notice("\(state)")
            playerListener?.stateChanged(state)
        }
    }
    
    
    let streamUrl: URL
    let icyMetadata: Bool = true
    
    private let playerQueue = DispatchQueue(label: "io.ybrid.player-sdk")
    
    var loader: AudioDataLoader?
    var pipeline: AudioPipeline?
    var playback: Playback?
    
    private weak var playerListener:AudioPlayerListener?
    
    public init(mediaUrl: URL, listener: AudioPlayerListener?) {
        self.playerListener = listener
        self.streamUrl = mediaUrl
        PlayerContext.setupAudioSession()
    }
    
    deinit {
        Logger.shared.debug()
        PlayerContext.deactivate()
    }
    
    // MARK: actions
    
    public func play() {
        guard state == .stopped  else {
            Logger.shared.notice("already running")
            return
        }
        state = .buffering
        playerQueue.async {
            self.playWhenReady()
        }
    }
     
    public func stop() {
        pipeline?.stopProcessing()
        playerQueue.async {
            self.stopPlaying()
            self.state = .stopped
        }
    }
    
    private func playWhenReady() {
        pipeline = AudioPipeline(pipelineListener: self, playerListener:                                     playerListener)
        loader = AudioDataLoader(mediaUrl: streamUrl, pipeline: pipeline!, inclMetadata: icyMetadata)
        loader?.requestData(from: streamUrl)
    }
    
    private func stopPlaying() {
        playback?.stop()
        loader?.stopRequestData()
        pipeline?.dispose()
    }
    
    // MARK: pipeline listener
    
    func ready(playback: Playback) {
        switch state {
        case .stopped:
            Logger.shared.debug("should not begin playing.")
            pipeline?.stopProcessing()
            playback.stop()
            loader?.stopRequestData()
            pipeline?.dispose()
            return
        case .playing:
            Logger.shared.error("should not play already.")
        case .buffering:
            self.playback = playback
            playback.setListener(listener: self)
        }
    }
    
    func problem(_ type: ProblemType, _ message: String) {
        
        playerListener?.currentProblem(message)
        switch type {
        case .solved:
            DispatchQueue.global().async {
                sleep(5) ; self.playerListener?.currentProblem(nil)
            }
        case .notice:
            Logger.shared.notice(message)
        case .stalled:
            Logger.shared.notice(message)
        case .fatal:
            Logger.shared.error(message)
            stop()
        case .unknown:
            Logger.shared.notice(message)
        }
    }
    
    // MARK: BufferListener
    
    func stateChanged(_ bufferState: PlaybackBuffer.BufferState) {
        
        if state == .buffering && bufferState == .ready {
            state = .playing
        }
        
        if state == .playing && bufferState == .empty {
            state = .buffering
        }
    }
}
