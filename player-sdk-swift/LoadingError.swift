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


class LoadingError : LocalizedError {
    
    enum ErrorKind : ErrorCode {
        case missingMimeType = 300
        case cannotProcessMimeType = 301
        
        case timedOutLoadingData = -1001 // "timed out loading data", .recoverable),
        case unsuportedUrl = -1002 //, "unsupported URL", .fatal),
        case hostNotFound = -1003 //, "host not found", .fatal, .recoverable),
        case connectionLost = -1005 //, "connection lost", .recoverable),
        case offline = -1009 //, "offline?", .fatal, .recoverable),
        case noHttps = -1022 //, "not https", .fatal),
        case cannotConnectOverSsl = -1200 //, "cannot connect over SSL",.fatal),
        case lostConnectionToBackgroudTransferService = -997 //, nil, .notice)
    }
    
    let component:ErrorComponent = ErrorComponent.loading
    let kind:ErrorKind
    var message:String
    init(_ kind:ErrorKind, _ message:String) {
        self.kind = kind; self.message = message
    }
    var errorDescription: String? {
        return String(format:"%@.%@ %@",String(describing: Self.self), String(describing: kind), message)
    }

    
    class Behaviour {
        let cause:ErrorKind
        let message:String
        let errorLevel:ErrorLevel
        var errorLevelWhileStalling:ErrorLevel
        init(_ cause:ErrorKind, _ message:String, _ level:ErrorLevel, _ whileStalling:ErrorLevel? = nil) {
            self.cause = cause
            self.message = message
            self.errorLevel = level
            self.errorLevelWhileStalling = whileStalling ?? level
        }
    }
    
    static var networkBahviourMap: [Behaviour] = [
        Behaviour(ErrorKind.timedOutLoadingData, "timed out loading data", .recoverable),
        Behaviour(ErrorKind.unsuportedUrl, "unsupported URL", .fatal),
        Behaviour(ErrorKind.hostNotFound, "host not found", .fatal, .recoverable),
        Behaviour(ErrorKind.connectionLost, "connection lost", .recoverable),
        Behaviour(ErrorKind.offline, "offline?", .fatal, .recoverable),
        Behaviour(ErrorKind.noHttps, "not https", .fatal),
        Behaviour(ErrorKind.cannotConnectOverSsl, "cannot connect over SSL",.fatal),
        Behaviour(ErrorKind.lostConnectionToBackgroudTransferService, "lost connection in background", .recoverable) //  App in den Hingerund  -->  -997 Lost connection to background transfer service

    ]
    
    
    static func getNetworkErrorBehaviour(_ error: Error) -> Behaviour? {
        let nserr = error as NSObject
        let code = nserr.value(forKey: "code") as! NSNumber.IntegerLiteralType
        if code == -999 {
            return nil /// stopped regularily
        }
        
        let pattern = "task completed with code=%d %@"
        Logger.loading.info(String(format: pattern, code , error.localizedDescription))
        
        return networkBahviourMap.first(where: { $0.cause.rawValue == code })
    }
    
}

