//
// OggContainer.swift
// app-example-ios
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
//#if os(iOS)
import Foundation
import YbridOgg 


class OggContainer {
    
    private static let oggBundleIdentifier = "io.ybrid.ogg-swift"
    private var oggSyncState = ogg_sync_state()
    
    var selectedStream:(Int32,OpusData)?
    var pageNo:Int? = nil {
        didSet {
            if let old = oldValue, let current = pageNo, old + 1 != current {
                // alert gap in page numbers
                Logger.decoding.error("page \(current) not continous, last was \(old)")
            }
        }
    }
    
    var opusListener:OpusDataListener?
    init(delegate: AudioPlayerListener?) throws {
        if let info = Bundle(identifier: OggContainer.oggBundleIdentifier)?.infoDictionary {
            Logger.decoding.debug("bundle \(OggContainer.oggBundleIdentifier) info \(info)")
            let version = info["CFBundleShortVersionString"] ?? "(unknown)"
            let name = info["CFBundleName"] ?? "(unknown)"
            let build = info["CFBundleVersion"]  ?? "(unknown)"
            Logger.decoding.notice("using \(name) version \(version) (build \(build))")
        }
        _ = try oggSyncInit()
    }
    
    deinit {
        Logger.decoding.debug()
    }
       
    func dispose() {
        Logger.decoding.debug("pre deinit")
        selectedStream?.1.dispose()
        selectedStream = nil
        ogg_sync_clear(&oggSyncState)
    }
   
    func parse(data: Data) throws {
        if Logger.verbose { Logger.decoding.debug("parsing ogg data of \(data.count) bytes") }
        
        let size = try oggBuffer(data: data)
        if Logger.verbose { Logger.decoding.debug("written \(data.count) bytes into ogg buffer of \(size) bytes") }
        
        var bufferedPagesCount = 0
        pages: while true {
            guard var page = try oggPageOut() else {
                if Logger.verbose { Logger.decoding.debug("ogg buffer of \(size) bytes contained \(bufferedPagesCount) ogg pages") }
                break pages
            }
            bufferedPagesCount = bufferedPagesCount + 1
            if Logger.verbose { Logger.decoding.debug("\(describe(page: &page))") }
            
            guard 0 == ogg_sync_check(&oggSyncState) else {
                let errMsg = "page \(ogg_page_pageno(&page)) not synced"
                Logger.decoding.error(errMsg)
                throw AudioDataError(.parsingFailed, errMsg)
            }
            
            /// new stream (!= nil), continue or end (== nil)
            guard let selected = try select(&page) else {
                let pageno = ogg_page_pageno(&page)
                let serialno = ogg_page_serialno(&page)
                Logger.decoding.error( "no stream for \(serialno) on page \(pageno) ")
                continue pages
            }

            /// audio page != nil, header page == nil
            guard let pageno = try selected.pageIn(&page) else {
                pageNo = nil
                continue pages
            }
            
            /// keep track of page numbers ...
            pageNo = pageno
        }
    }
    
    fileprivate func select(_ page: inout ogg_page) throws -> OpusData? {
        let serialno = ogg_page_serialno(&page)
        
        if isBeginOfOpusStream(&page) {
            let newStream = try OpusData(serialno, opusListener: opusListener!)
            selectedStream?.1.dispose()
            selectedStream = (serialno,newStream)
            return newStream
        }
        return selectedStream?.1
    }
    
    fileprivate func isBeginOfOpusStream(_ page: inout ogg_page) -> Bool {
        if  ogg_page_bos(&page) > 0 && page.body_len > 8 {
            let bodyStart = String(decoding: Data(bytes: page.body, count: 8), as: UTF8.self)
            return bodyStart.starts(with: "OpusHead")
        }
        return false
    }
    
    private func oggSyncInit() throws -> Int32 {
        ogg_sync_init(&oggSyncState)
        
        Logger.decoding.debug("oggState = \(oggSyncState)")
        let syncStatus = ogg_sync_check(&oggSyncState)
        guard 0 == syncStatus else {
            let errMsg = "initialize ogg state failed"
            Logger.decoding.error(errMsg)
            throw AudioDataError(.cannotOpenStream, errMsg)
        }
        return syncStatus
    }
    
    private func oggBuffer(data:Data) throws -> Int {
        let size = try data.withUnsafeBytes {(body: UnsafeRawBufferPointer) throws -> (Int?) in
            let buffer = ogg_sync_buffer(&oggSyncState, data.count) // returns bufferPtr to data.count + 4096
            _ = memcpy(buffer, body.baseAddress, data.count)
            guard 0 == ogg_sync_check(&oggSyncState) else {
                let errMsg = "ogg_sync_buffer failed"
                Logger.decoding.error(errMsg)
                throw AudioDataError(.parsingFailed, errMsg)
            }
            
            return data.count + 4096
        }
        let syncStatus = ogg_sync_wrote(&oggSyncState, data.count)
        /*
         -1 if the number of bytes written overflows the internal storage of the ogg_sync_state struct or an internal error occurred.
         0 in all other cases.
         */
        guard 0 == syncStatus else {
            let errMsg = "ogg_sync_wrote failed"
            Logger.decoding.error(errMsg)
            throw AudioDataError(.parsingFailed, errMsg)
        }
        guard 0 == ogg_sync_check(&oggSyncState) else {
            let errMsg = "ogg_sync_wrote failed"
            Logger.decoding.error(errMsg)
            throw AudioDataError(.parsingFailed, errMsg)
        }
        guard size != nil else {
            let errMsg = "data.count (= \(data.count)) + 4096 bytes should be buffered, but is nil"
            Logger.decoding.error(errMsg)
            throw AudioDataError(.parsingFailed, errMsg)
        }
        return data.count
    }
    
      
    private func oggPageOut() throws -> ogg_page? {
        var page:ogg_page = ogg_page()
        let result = ogg_sync_pageout(&oggSyncState, &page)
        /* -1 returned if stream has not yet captured sync (bytes were skipped).
         0 returned if more data needed or an internal error occurred.
         1 indicated a page was synced and returned.*/
        if result == 0 {
            if Logger.verbose { Logger.decoding.debug("ogg_sync_pageout: more data needed") }
            return nil
        }
        else if result < 0 {
            Logger.decoding.error("ogg_sync_pageout: stream has not yet captured sync (bytes were skipped)")
            return nil
        }
        
        if Logger.verbose { Logger.decoding.debug("synced ogg page") }
        return page
    }
    
    // MARK: ogg page in
    
    private func describe(page: inout ogg_page) -> String {
        var info:String = "ogg page"
        let pageNo = ogg_page_pageno(&page)
        info.append(" " + String(pageNo))
        let bos = ogg_page_bos(&page)
        if bos > 0 { info.append(" bos")}
        let eos = ogg_page_eos(&page)
        if eos > 0 { info.append(" eos")}
        return info
    }
}
//#endif
