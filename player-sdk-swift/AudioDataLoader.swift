//
// AudioDataLoader.swift
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


import Foundation
import AVFoundation
import Network

class AudioDataLoader: NSObject, URLSessionDataDelegate, NetworkListener {
    
    let url: URL
    let pipeline: AudioPipeline
    private let withMetadata: Bool
    private let configuration: URLSessionConfiguration
    
    private var session: URLSession?
    private var sessionData: URLSessionDataTask?
    private var stalled:Bool = false {
        didSet {
            if oldValue != stalled {
                Logger.loading.debug("loading data stalled \(stalled)")
            }
        }
    }
    private var sessionStarted: Date?

    
    init(mediaUrl: URL, pipeline: AudioPipeline, inclMetadata: Bool = true) {
        self.url = mediaUrl
        self.pipeline = pipeline
        self.withMetadata = inclMetadata
        configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.networkServiceType = NSURLRequest.NetworkServiceType.avStreaming
        configuration.timeoutIntervalForRequest = 10.0
        super.init()
        PlayerContext.register(listener: self)
    }
    
    deinit {
        Logger.loading.debug()
        stopRequestData()
    }
    
    func requestData(from url: URL) {
        Logger.loading.debug()
        startSession(configuration: configuration)
    }
    
    func stopRequestData() {
        Logger.loading.debug()
        endSession()
        PlayerContext.unregister(listener: self)
        stalled = false
    }

    fileprivate func startSession(configuration: URLSessionConfiguration) {
        Logger.loading.debug()
        sessionStarted = Date()
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        var request: URLRequest = URLRequest(url: url)
        if withMetadata {
            request.setValue("1", forHTTPHeaderField: "Icy-MetaData")
        }
        sessionData = session?.dataTask(with: request)
        sessionData?.resume()
    }

    private func endSession() {
        if let session = session {
            session.invalidateAndCancel()
        }
    }
    
    // MARK: handling network
    
    func notifyNetworkChanged(_ connected: Bool) {
        Logger.loading.notice("connected=\(connected), stalled=\(stalled)")
        if !connected {
            return
        }
        if stalled {
            resumeRequestData()
        }
    }
    
    fileprivate func resumeRequestData() {
        Logger.loading.debug()
        endSession()
        startSession(configuration: configuration)
        pipeline.resume()
        pipeline.pipelineListener.error(ErrorLevel.notice, ErrorComponent.loading, "resume loading data")
    }
    
    fileprivate func networkStalled(_ problemText:String) {
        guard PlayerContext.networkMonitor.isConnectedToNetwork() == false else {
            resumeRequestData()
            return
        }
        stalled = true
        pipeline.decodingQueue.async {
            self.pipeline.flushAudio()
        }
        pipeline.pipelineListener.error(ErrorLevel.recoverable, ErrorComponent.loading, problemText)
    }

    
    // MARK: session begins
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {        Logger.loading.debug("didReceive response for task \(dataTask.taskIdentifier) called")
        if let started = sessionStarted {
            pipeline.playerListener?.durationConnected(Date().timeIntervalSince(started))
        }
        completionHandler(Foundation.URLSession.ResponseDisposition.allow)
        if response is HTTPURLResponse {
            handleMetadata(response as! HTTPURLResponse)
        }
        handleMediaType(response, session)
    }
    
    private func handleMetadata(_ httpResp: HTTPURLResponse) {

        let metaint:NSString?
        if #available(iOS 13, macOS 10.15,  *) {
            metaint = httpResp.value(forHTTPHeaderField: "icy-metaint") as NSString?
        } else {
            let fieldValue = httpResp.allHeaderFields.filter({ $0.0 as! NSString == "icy-metaint" }).first
            metaint = fieldValue?.1 as! NSString?
        }
        if withMetadata, let metadataEveryBytes = metaint?.integerValue {
            pipeline.prepareMetadata(metadataInverallB: metadataEveryBytes)
            Logger.loading.notice("icy-metadata every \(metadataEveryBytes) bytes")
        } else {
            Logger.loading.notice("without icy-metadata")
        }
    }
    
    private func handleMediaType(_ response: URLResponse, _ session: URLSession) {
        guard let mimeType = response.mimeType else {
            endSession()
            pipeline.pipelineListener.error(ErrorLevel.fatal, ErrorComponent.loading, "missing mimeType")
            return
        }
        let expectedLength = response.expectedContentLength
        guard let type = getAudioFileType(mimeType) else {
            endSession()
            pipeline.pipelineListener.error(ErrorLevel.fatal, ErrorComponent.loading, "cannot process \(mimeType)")
            return
        }
        
        Logger.loading.debug("will recieve \(expectedLength) bytes of \(mimeType)")
        pipeline.prepareAudio(audioContentType: type)
    }
    
    private func getAudioFileType(_ mimeType:String) -> AudioFileTypeID? {

        switch mimeType {
        case "audio/mpeg":
            return kAudioFileMP3Type
        case "audio/aac", "audio/aacp":
            return kAudioFileAAC_ADTSType
        case "application/ogg", "audio/ogg", "application/octet-stream":
            return kAudioFormatOpus
        default:
            return nil
        }
    }

    // MARK: session runs
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        
        if Logger.verbose { Logger.loading.debug("recieved \(data.count) bytes, total \(dataTask.countOfBytesReceived)") }
        
        if dataTask.state == .running {
            stalled = false
            pipeline.decodingQueue.async {
                self.pipeline.process(data: data)
            }
        }
    }
    
    // MARK: session ends
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Logger.loading.debug("session didComplete task \(task.taskIdentifier), state is \(describe(sessionData?.state))")
        if let errDesc = task.error?.localizedDescription {
            Logger.loading.debug("task \(task.taskIdentifier) completed with \(errDesc)")
        }
        
        if let error = error {
            guard let handling = LoadingError.mapCFNetworkErrors(error, stalling: stalled) else {
                Logger.loading.info("loading stopped")
                return
            }
            
            Logger.loading.debug("error is \(error.self)")
            switch handling.type {
            case .recoverable:
                networkStalled(handling.msg)
            case .fatal:
                pipeline.pipelineListener.error(ErrorLevel.fatal, ErrorComponent.loading, handling.msg)
            default:
                pipeline.pipelineListener.error(ErrorLevel.notice, ErrorComponent.loading, handling.msg)
            }
        }
    }
    
    /// not used but I want to see it
    
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity: URLSessionTask) {
        Logger.loading.notice("session waitingForConnectivity, task \(taskIsWaitingForConnectivity.taskIdentifier) state is \(describe(sessionData?.state))")
    }
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        Logger.loading.debug("session didBecomeInvalidWithError state is \(describe(sessionData?.state)) \(error?.localizedDescription ?? "")")
    }
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Logger.loading.notice("session did finish forBackgroundURLSession, data state is \(describe(sessionData?.state))")
    }
}

fileprivate func describe(_ state: URLSessionTask.State? ) -> String {
    guard let state = state else {
        return "(nil)"
    }
    switch state {
    case .suspended: return "suspended"
    case .running : return "running"
    case .canceling: return "canceling"
    case .completed: return "completed"
    default: return "(unknown)"
    }
}
