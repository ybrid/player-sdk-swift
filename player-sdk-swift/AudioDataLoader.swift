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
                Logger.loading.debug("network stalled \(stalled)")
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
        pipeline.pipelineListener.problem(.solved, "resume loading data")
    }
    
    fileprivate func networkStalled(_ problemText:String) {
        guard PlayerContext.networkMonitor.isConnectedToNetwork() == false else {
            resumeRequestData()
            return
        }
        stalled = true
        pipeline.pipelineListener.problem(.stalled, problemText)
        pipeline.decodingQueue.async {
            self.pipeline.flushAudio()
        }
    }

    
    // MARK: session begins
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {        Logger.loading.notice("didReceive response called")
        if let started = sessionStarted {
            pipeline.playerListener?.durationConnected(Date().timeIntervalSince(started))
        }
        completionHandler(Foundation.URLSession.ResponseDisposition.allow)
        if response is HTTPURLResponse {
            handleMetadata(response as! HTTPURLResponse)
        }
        handleMimeType(response, session)
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
    
    private func handleMimeType(_ response: URLResponse, _ session: URLSession) {
        let mimeType = response.mimeType
        let expectedLength = response.expectedContentLength
        let type:AudioFileTypeID
        do {
            type = try getAudioFileType(mimeType)
        } catch {
            Logger.loading.error(error.localizedDescription)
            session.invalidateAndCancel()
            pipeline.pipelineListener.problem(ProblemType.fatal, "cannot process \(mimeType ?? "no mimeType")")
            return
        }
        
        Logger.loading.debug("will recieve \(expectedLength) bytes of \(mimeType!)")
        pipeline.prepareAudio(audioContentType: type)
    }
    
    private func getAudioFileType(_ mimeType:String?) throws -> AudioFileTypeID {
        guard let mimeType = mimeType else {
            throw PipelineError(.cannotProcess,"missing mimeType")
        }
        switch mimeType {
        case "audio/mpeg":
            return kAudioFileMP3Type
        case "audio/aac", "audio/aacp":
            return kAudioFileAAC_ADTSType
        case "application/ogg", "audio/ogg", "application/octet-stream":
            return kAudioFormatOpus
        default:
            throw PipelineError(.cannotProcess,"mimeType \(mimeType)")
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
        Logger.loading.debug("session didComplete data state is \(describe(sessionData?.state))")
        if let errDesc = task.error?.localizedDescription {
            Logger.loading.debug("task completed with \(errDesc)")
        }
        
        if let error = error {
            guard let handling = mapCFNetworkErrors(error) else {
                Logger.loading.info("loading stopped")
                return
            }
            
            Logger.loading.debug("error is \(error.self)")
            switch handling.type {
            case .stalled:
                networkStalled(handling.msg)
            default:
                pipeline.pipelineListener.problem(handling.type, handling.msg)
                pipeline.decodingQueue.async {
                    self.pipeline.flushAudio()
                }
            }
        }

    }

    fileprivate func mapCFNetworkErrors(_ error: Error) -> (type:ProblemType,msg: String)? {
        let nserr = error as NSObject
        let code = nserr.value(forKey: "code") as! NSNumber.IntegerLiteralType
        if code == -999 {
            return nil /// stopped regularily
        }
        
        let pattern = "task completed with code=%d %@"
        Logger.loading.info(String(format: pattern, code , error.localizedDescription))
        switch code {
        case -1001:
            return (.stalled, "timed out loading data")
        case -1002:
            return (.fatal, "unsupported URL")
        case -1003: // A server with the specified hostname could not be found.
            if stalled {
                return (.stalled, "still stalling")
            }
            return (.fatal, "host not found")
        case -1005:
            return (.stalled, "connection lost") // TODO can happen in the first attempt as well
        case -1009:
            if stalled {
                return (.stalled, "still stalling")
            }
            return (.fatal, "offline?")
        case -1022: // The resource could not be loaded because the App Transport Security policy requires the use of a secure connection.
            /* this should not happen anymore, because http is enabled in
             Info.plist / Property Editor -> Info -> Custom iOS Target Properties
             <key>NSAppTransportSecurity</key>
             <dict>
                 <key>NSAllowsArbitraryLoads</key>
                 <true/>
             </dict>
             */
            return (.fatal, "not https")
        case -1200: // An SSL error has occurred and a secure connection to the server cannot be made.
            return (.fatal, "cannot connect over SSL")
        case -997: // App in den Hingerund  -->  -997 Lost connection to background transfer service
            return (.notice, error.localizedDescription)
        default:
            return( .unknown, error.localizedDescription)
        }
    }

    
    
    /// not used but I want to see it
    
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity: URLSessionTask) {
        Logger.loading.notice("session waitsForConnectivity, data state is \(describe(sessionData?.state))")
    }
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        Logger.loading.debug("session didBecomeInvalidWithError, data state is \(describe(sessionData?.state))")
    }
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Logger.loading.notice("session forBackgroundURLSession, data state is \(describe(sessionData?.state))")
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
