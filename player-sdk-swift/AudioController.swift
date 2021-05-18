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


public protocol PlaybackControl {
    func play()
    func stop()
    var state:PlaybackState { get }
    var canPause:Bool { get }
    func pause()
    func close()
}

public class AudioController {
    static private let controllerQueue = DispatchQueue(label: "io.ybrid.audio.controller")
    
    // Create an AudioPlayer for a MediaEndpoint.
    //
    // The matching MediaProtocol is detected and a session
    // to control content and metadata of the stream is established.
    public static func create(for endpoint:MediaEndpoint, listener: AudioPlayerListener? = nil, playbackControl: @escaping (PlaybackControl, MediaProtocol) -> () ) throws {
        
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
        
        AudioController.controllerQueue.async {
            let audioPlayer = AudioPlayer(session: session, listener: listener)
            playbackControl(audioPlayer, session.mediaProtocol!)
        }
    }
    
}

