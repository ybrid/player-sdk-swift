//
// LoadingErrors.swift
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

class LoadingError : AudioPlayerError {
    
    init(_ kind:ErrorKind, _ message:String, _ cause:Error? = nil) {
        super.init(kind, message, cause)
    }
    
    init(_ kind:ErrorKind, _ cause:SessionTaskState) {
        super.init(kind, cause.message, cause)
        super.osstatus = cause.osstatus
    }
}

class SessionTaskState : Equatable, LocalizedError {
    
    static func == (lhs: SessionTaskState, rhs: SessionTaskState) -> Bool {
        return lhs.osstatus == rhs.osstatus
    }
    
    var completed:Bool { get {
        return self == SessionTaskState.completed || self == SessionTaskState.cancelled
    }}
    
    private static let completed = SessionTaskState(0, "completed", .notice) /// loading finished
    private static let cancelled = SessionTaskState(-999, "stopped", .notice) /// stopped regularily
    private static var knownErrorStates: [SessionTaskState] = [
        cancelled,
        SessionTaskState(-1000, "bad url", .fatal),
        SessionTaskState(-1002, "unsupported url", .fatal),
        SessionTaskState(-1004, "could not connect", .fatal),
        SessionTaskState(-1022, "not https", .fatal),
        SessionTaskState(-1100, "url not found", .fatal),
        SessionTaskState(-1101, "no file, is directory", .fatal),
        SessionTaskState(-1200, "cannot connect over ssl",.fatal),
        
        SessionTaskState(-1003, "host not found", .fatal, .recoverable),
        SessionTaskState(-1009, "offline?", .fatal, .recoverable),

        SessionTaskState(-1001, "timed out loading data", .recoverable),
        SessionTaskState(-1005, "connection lost", .recoverable),
        SessionTaskState(-997, "lost connection in background", .recoverable) //  App in den Hingerund  -->  -997 Lost connection to background transfer service
    ]
    
    let osstatus:OSStatus
    let message:String
    let severity:ErrorSeverity
    var severityWhileStalling:ErrorSeverity
    init(_ code:OSStatus, _ message:String, _ severity:ErrorSeverity, _ whileStalling:ErrorSeverity? = nil) {
        self.osstatus = code
        self.message = message
        self.severity = severity
        self.severityWhileStalling = whileStalling ?? severity
    }
    
    public var errorDescription: String? {
        var description = String(format:"%@ OSStatus=%d", "\(type(of: self))", osstatus)
        description += ", " + message
        return description
    }

    static func getSessionTaskState(_ state: URLSessionTask.State ,_ error: Error?) -> SessionTaskState? {

        guard let error = error else {
            switch state {
            case .completed:
                return SessionTaskState.completed
            case .canceling, .running, .suspended:
                return nil
            }
        }
        
        return getSessionState(error)
    }
    
    
    private static func getSessionState(_ error: Error) -> SessionTaskState {
        let nserr = error as NSObject
        let code = nserr.value(forKey: "code") as! NSNumber.IntegerLiteralType
        let message = String(format: "OSStatus=%d %@", code , error.localizedDescription)
        Logger.loading.debug(message)
        guard let networkError = knownErrorStates.first(where: { $0.osstatus == code }) else {
            return SessionTaskState(OSStatus(code), error.localizedDescription, ErrorSeverity.notice)
        }
        return networkError
    }
    
}



