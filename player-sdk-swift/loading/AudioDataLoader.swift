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

class AudioDataLoader: NSObject, URLSessionDataDelegate, NetworkListener, MemoryListener {

    let url: URL
    let pipeline: AudioPipeline
    private let withMetadata: Bool
    private let configuration: URLSessionConfiguration
    
    private var session: URLSession?
    private var taskState:SessionTaskState?
    private var stalled:Bool = false {
        didSet {
            if oldValue != stalled {
                Logger.loading.notice("loading data stalled \(stalled)")
            }
        }
    }
    private var sessionStarted: Date?
    
    var completed:Bool { get {
        guard let state = taskState else {
            return false
        }
        return state.completed
    }}
    
    
    static let replaceSchemes:[String:String] = [
        "icyx"  : "http",
        "icyxs" : "https"
    ]
    static func mapProtocol(_ inUrl:URL) -> URL {
        if let scheme = inUrl.absoluteURL.scheme, replaceSchemes.keys.contains(scheme) {
            var comps = URLComponents(url: inUrl, resolvingAgainstBaseURL: false)!
            comps.scheme = replaceSchemes[scheme]
            if scheme == "icyxs" {
                comps.port = 443
            }
            return comps.url!
        }
        return inUrl
    }
 
    init(mediaUrl: URL, pipeline: AudioPipeline, inclMetadata: Bool = true) {
        self.url = AudioDataLoader.mapProtocol(mediaUrl)
        self.pipeline = pipeline
        self.withMetadata = inclMetadata
        configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.networkServiceType = NSURLRequest.NetworkServiceType.avStreaming
        configuration.timeoutIntervalForRequest = 10.0
        super.init()
    }
    
    deinit {
        Logger.loading.debug()
        stopRequestData()
    }
    
    func requestData(from url: URL) {
        Logger.loading.debug()
        PlayerContext.register(listener: self)
        PlayerContext.registerMemoryListener(listener: self)
        startSession(configuration: configuration)
    }
    
    func stopRequestData() {
        Logger.loading.debug()
        endSession()
        PlayerContext.unregister(listener: self)
        PlayerContext.unregisterMemoryListener(listener: self)
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
        let sessionTask = session?.dataTask(with: request)
        sessionTask?.resume()
    }
    
    fileprivate func endSession() {
        if let session = session {
            session.invalidateAndCancel()
            self.session = nil
        }
    }
    
    // MARK: handling memory
    
    func notifyExceedsMemoryLimit() {
        Logger.loading.notice("stop loading due to memory limit")
        stopRequestData()
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
        pipeline.reset()
        pipeline.pipelineListener.notify(ErrorSeverity.notice, LoadingError( ErrorKind.noError, "resume loading data"))
    }
    
    fileprivate func networkStalled(_ cause:SessionTaskState) {
        guard PlayerContext.networkMonitor.isConnectedToNetwork() == false else {
            resumeRequestData()
            return
        }
        stalled = true
        let error = LoadingError(ErrorKind.networkStall, cause)
        pipeline.pipelineListener.notify(ErrorSeverity.recoverable, error)
    }
    
    // MARK: session begins

    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        Logger.loading.debug("didReceive response for task \(dataTask.taskIdentifier)")
        if let started = sessionStarted {
            DispatchQueue.global().async {
                self.pipeline.playerListener?.durationConnected(Date().timeIntervalSince(started))
            }
        }
        completionHandler(Foundation.URLSession.ResponseDisposition.allow)
        
        do {
            if response is HTTPURLResponse {
                var icyHeader = getHeaders(response as! HTTPURLResponse, fieldsStartingWith: "icy-")
                if icyHeader.count == 0 {
                    let iceMetadata = getHeaders(response as! HTTPURLResponse, fieldsStartingWith: "ice-")
                    iceMetadata.forEach { (key:String,value) in
                        let endIndex = key.index(key.startIndex, offsetBy: 3)
                        var icyKey:String = key
                        icyKey.replaceSubrange(...endIndex, with: "icy-")
                        Logger.loading.notice("changed http field '\(key)' to '\(icyKey)'")
                        icyHeader[icyKey] = value
                    }
                }
                handleMetadata(icyHeader)
            }
            try pipeline.prepareDecoder(response.mimeType, response.suggestedFilename)
            handleMediaLength(response.expectedContentLength)
        } catch {
            if let playerError = error as? AudioPlayerError {
                pipeline.pipelineListener.notify(ErrorSeverity.fatal, playerError)
            } else  {
                pipeline.pipelineListener.notify(ErrorSeverity.fatal, LoadingError( ErrorKind.unknown, "error handling url response", error))
            }
            endSession()
        }

        if let textEncoding = response.textEncodingName {
            Logger.loading.debug("textEncodingName \(textEncoding) not used")
        }
        
        return
    }
    
    fileprivate func handleMetadata(_ icyHeader:[String:String]) {
        Logger.loading.debug("icy-fields: \(icyHeader)")
        if let service = IcyMetadata.createService(icyHeader) {
            pipeline.setService(service)
        }
        
        if withMetadata, let metaint = icyHeader["icy-metaint"] {
            guard let metadataEveryBytes = Int(metaint) else {
                Logger.loading.error("invalid icy-metaint value '\(metaint)'")
                return
            }
            Logger.loading.info("icy-metadata every \(metadataEveryBytes) bytes")
            pipeline.prepareMetadata(metadataInverallB: metadataEveryBytes)
        }
    }
        
    fileprivate func handleMediaLength(_ expectedLength: Int64) {
        Logger.loading.debug("expecting to recieve \(expectedLength == -1 ? "infinite" : String(expectedLength)) bytes")
        pipeline.setInfinite(expectedLength == -1)
    }
    
    private func getHeaders(_ httpResp: HTTPURLResponse, fieldsStartingWith:String) -> [String:String]  {
        var result:[String:String] = [:]
        httpResp.allHeaderFields.filter({
            let name = $0.0 as! NSString
            return String(name).starts(with: fieldsStartingWith)
        }).forEach({ result[String($0.0 as! NSString)]=String($0.1 as! NSString) })
        return result
    }
        
    // MARK: session runs
    var firstBytes = true
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        
        if Logger.verbose { Logger.loading.debug("recieved \(data.count) bytes, total \(dataTask.countOfBytesReceived)") }
        
        pipeline.decodingQueue.async {
            self.pipeline.process(data: data)
        }
        
        if dataTask.state == .running {
            stalled = false
        }
    }
    
    // MARK: session ends
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        var logMessage = "task \(task.taskIdentifier) didComplete"
        if let errDesc = task.error?.localizedDescription {
            logMessage += " with \(errDesc)"
        }
        logMessage += ", state is \(describe(task.state))"
        Logger.loading.debug(logMessage)
        
        pipeline.decodingQueue.async {
            self.pipeline.endOfData()
        }
        
        taskState = SessionTaskState.getSessionTaskState(task.state, error)
         
        guard let taskState = taskState else {
            Logger.loading.error(logMessage)
            return
        }
        
        if taskState.completed {
            Logger.loading.debug("task \(task.taskIdentifier) \(taskState.message)")
            return
        }
        
        switch taskState.severity {
        case .recoverable:
            networkStalled(taskState)
        case .fatal:
            let error = LoadingError(ErrorKind.networkFatal, taskState)
            pipeline.pipelineListener.notify( stalled ? taskState.severityWhileStalling : taskState.severity, error)
        case .notice:
            let notice = LoadingError(ErrorKind.noError, taskState)
            pipeline.pipelineListener.notify(taskState.severity,notice)
        }

    }
    
    /// not used but I want to see it
    
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity: URLSessionTask) {
        Logger.loading.notice("session waitingForConnectivity, task \(taskIsWaitingForConnectivity.taskIdentifier) state is \(describe(taskIsWaitingForConnectivity.state))")
    }
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        var logMessage = "session didBecomeInvalid"
        if let errDesc = error?.localizedDescription {
            logMessage += " with \(errDesc)"
        }
        Logger.loading.debug(logMessage)
    }
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Logger.loading.notice("session did finish forBackgroundURLSession")
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
