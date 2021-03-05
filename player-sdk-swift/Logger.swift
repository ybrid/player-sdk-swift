//
// Logger.swift
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

//
// All logging of the player uses the unified logging system.
//
// The logger subsystem is 'io.ybrid.player-sdk-swift'.
// The player uses the internal categories 'loading', 'decoding', 'playing'.
//
// Messages not corresponding only to one of this internal components are logged on the
// public shared instance.
//

import Foundation
import os.log

public class Logger {
    
    /// enable or disable frequent or continous debug level logging
    public static var verbose:Bool = false
    
    public static let shared: Logger = Logger()
    static let loading: Logger = Logger(category: "loading")
    static let decoding: Logger = Logger(category: "decoding")
    static let playing: Logger = Logger(category: "playing")
    
    private var log:OSLog?
    
    private var df = DateFormatter()
    private var baseInfo:String?

    private static let subsystem = "io.ybrid.player-sdk-swift"
    private let loggerQueue = DispatchQueue(label: "io.ybrid.logger")
    
    
    public init(category: String = "") {
        if #available(iOS 10, macOS 10.12, *) {
            log = OSLog(subsystem: Logger.subsystem, category: category)
        } else { /// Fallback on earlier versions
            baseInfo = "\(Logger.subsystem) [\(category)]"
            df.locale = Locale(identifier: "de_DE")
            df.dateStyle = DateFormatter.Style.short
            df.timeStyle = DateFormatter.Style.long
        }
    }
    
    public func info(_ message: String = "", fullSourcePath: String = #file, functionWithParameters: String = #function, line: Int = #line) {
        if #available(iOS 10, macOS 10.12, *) {
            logit(OSLogType.info, message, fullSourcePath, functionWithParameters, line)
        } else {
            printit("INFO", message, fullSourcePath, functionWithParameters, line)
        }
    }
    
    public func notice(_ message: String = "", fullSourcePath: String = #file, functionWithParameters: String = #function, line: Int = #line) {
        if #available(iOS 10, macOS 10.12, *) {
            logit(OSLogType.default, message, fullSourcePath, functionWithParameters, line)
        } else {
            printit("NOTICE", message, fullSourcePath, functionWithParameters, line)
        }
    }
    
    public func debug(_ message: String = "", fullSourcePath: String = #file, functionWithParameters: String = #function, line: Int = #line) {
        if #available(iOS 10, macOS 10.12, *) {
            logit(OSLogType.debug, message, fullSourcePath, functionWithParameters, line)
        } else {
//            printit("DEBUG", message, fullSourcePath, functionWithParameters, line)
        }
    }
    
    public func error(_ message: String = "", fullSourcePath: String = #file, functionWithParameters: String = #function, line: Int = #line) {
        if #available(iOS 10, macOS 10.12, *) {
            logit(OSLogType.error, message, fullSourcePath, functionWithParameters, line)
        } else {
            printit("ERROR", message, fullSourcePath, functionWithParameters, line)
        }
    }
    
    @available(iOS 10, macOS 10.12, *)
    fileprivate func logit(_ type: OSLogType, _ message: String, _ fullSourcePath: String, _ functionWithParameters: String, _ line: Int) {
        loggerQueue.async {
            os_log("%{public}@.%{public}@-%d %{public}@", log: self.log!, type: type, self.getFileName(fullSourcePath), self.getFunctionName(functionWithParameters), line, "\(message)")
        }
    }
    
    /// in ios 9
    fileprivate func printit(_ type: String, _ message: String, _ fullSourcePath: String, _ functionWithParameters: String, _ line: Int) {
        let fullLine = String(format: "%@ %@ %@ %@.%@-%d %@", df.string(from: Date()), baseInfo!, type, getFileName(fullSourcePath), getFunctionName(functionWithParameters), line, message)
        loggerQueue.async {
            print(fullLine)
        }
    }
    
    fileprivate func getFileName(_ classPath: String ) -> String {
        if let full = URL(string: classPath)?.deletingPathExtension() {
            return full.lastPathComponent
        }
        return classPath
    }
    
    fileprivate func getFunctionName(_ functionWithParameters: String ) -> String {
        if let beginBracketIndex = functionWithParameters.lastIndex(of: "(") {
            return String(functionWithParameters[..<beginBracketIndex])
        }
        return functionWithParameters
    }
    
}
