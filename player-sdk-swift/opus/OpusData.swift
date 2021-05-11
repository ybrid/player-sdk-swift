//
// OpusData.swift
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

import AVFoundation
import YbridOgg 

protocol OpusDataListener : AudioDataListener {
    func preskip(preskip:Int) -> ()
    func convert(package:AudioData.Package, granularPos:Int64?) throws
    func metadataReady(_ metadata: AbstractMetadata)
}

class OpusData : AudioData {
    
    private var oggStreamState = ogg_stream_state()
    
    var serial:Int32 = -1
    var packetNo:Int64? = nil {
        didSet {
            if let old = oldValue, let current = packetNo, old + 1 != current {
                // notify gaps in packet numbers
                Logger.decoding.error("packet \(current) not continous, last was \(old)")
            }
        }
    }
    var aborted = false
    weak var opusListener:OpusDataListener?
    
    init(_ serial: Int32, opusListener: OpusDataListener) throws {
        self.opusListener = opusListener
        try super.init(audioContentType: kAudioFormatOpus, listener: opusListener)
        self.serial = try bos(serial)
    }
    
    deinit {
        Logger.decoding.debug(serial.description)
    }
    
    func dispose() {
        Logger.decoding.debug("pre deinit eos stream serial \(serial)")
        aborted = true
        ogg_stream_clear(&oggStreamState)
    }
    
    private func bos(_ serialno: Int32) throws  -> Int32 {
        Logger.decoding.debug("bos stream serial \(serialno)")
        
        guard serial == -1 else {
            let errMsg = "bos stream serial \(serialno) not selected, \(serial) not deselected"
            Logger.decoding.notice(errMsg)
            throw AudioDataError(.cannotOpenStream, errMsg)
        }
        
        guard 0 == ogg_stream_init(&oggStreamState, serialno) else {
            let errMsg = "ogg_stream_init failed"
            Logger.decoding.error(errMsg)
            throw AudioDataError(.cannotOpenStream, errMsg)
        }
        guard 0 == ogg_stream_check(&oggStreamState) else {
            let errMsg = "ogg_stream_init failed"
            Logger.decoding.error(errMsg)
            throw AudioDataError(.cannotOpenStream, errMsg)
        }
        return serialno
    }

     func pageIn(_ page: inout ogg_page ) throws  -> Int? {
        
        let pageno = ogg_page_pageno(&page)
        if Logger.verbose { Logger .decoding.debug("page \(pageno) in") }
        let state = ogg_stream_pagein(&oggStreamState, &page)
        guard state == 0 else {
            //  -1 indicates failure. This means that the serial number of the page did not match the serial number of the bitstream, the page version was incorrect, or an internal error accurred.
            let errMsg = "ogg_stream_pagein: Error reading page \(pageno) of ogg bitstream data"
            Logger.decoding.error(errMsg)
            throw AudioDataError(.parsingFailed, errMsg)
        }
        // page was successfully submitted to the bitstream.
        
        guard 0 == ogg_stream_check(&oggStreamState) else {
            let errMsg = "ogg_stream_pagein for page \(pageno) failed"
            Logger.decoding.error(errMsg)
            throw AudioDataError(.parsingFailed, errMsg)
        }
        
        let packets = try oggPacketsOut(&page)
        return try handlePackets(packets, pageno)
    }
    
    fileprivate func handlePackets(_ packets: [ogg_packet], _ pageno: Int) throws -> Int? {
        var i = 0
        while i < packets.count, !aborted {
            let packet = packets[i]
            i += 1
            
            let package = Data(bytes: packet.packet, count: packet.bytes)
            
            let opus = try mapOpusPacket(packet)
            if opus.bos {
                try onOpusHead(package: package, packetno: Int32(packet.packetno))
                alertIfRemainingPackagesOnPage(i, packets, pageno, packet)
                return nil
            }
            if opus.eos {
                packetNo = packet.packetno
                try opusListener?.convert(package: (package,nil), granularPos: packet.granulepos)
                continue
            }
            if onOpusTags(package: package) {
                alertIfRemainingPackagesOnPage(i, packets, pageno, packet)
                return nil
            }
            
            if Logger.verbose { Logger.decoding.debug("opus packet \(packet.packetno) with \(packet.bytes) bytes has gpos=\(packet.granulepos)") }
            
            /// keep track of packet numbers
            packetNo = packet.packetno
            try opusListener?.convert(package: (package,nil), granularPos: nil)
        }
        return pageno
    }
    
    fileprivate func oggPacketsOut(_ page: inout ogg_page) throws -> [ogg_packet]  {
        
        let pageNo = ogg_page_pageno(&page)
        let nPackets = ogg_page_packets(&page)
        let continued = ogg_page_continued(&page)
        if Logger.verbose { Logger.decoding.debug("page \(pageNo) nPackets \(nPackets) continued \(continued)") }
        
        var packets:[ogg_packet] = []
        for _ in 1...nPackets { // TODO nPackets can be 0!!
            
            var packet:ogg_packet = ogg_packet()
            let packetStatus = ogg_stream_packetout(&oggStreamState, &packet)
            let packetno = packet.packetno
            /*
             -1 if we are out of sync and there is a gap in the data. This is usually a recoverable error and subsequent calls to ogg_stream_packetout are likely to succeed. op has not been updated.
             0 if there is insufficient data available to complete a packet, or on unrecoverable internal error occurred. op has not been updated.
             1 if a packet was assembled normally. op contains the next packet from the stream.
             */
            guard 0 == ogg_stream_check(&oggStreamState) else {
                let errMsg = "ogg_stream_packetout failed"
                Logger.decoding.error(errMsg)
                throw AudioDataError(.parsingFailed, errMsg)
            }
            guard packetStatus == 1 || packetStatus == -1 else {
                Logger.decoding.debug("ogg_stream_packetout: insufficient data")
                return packets
            }
            if packetStatus == -1 {
                Logger.decoding.notice("packet \(packetno) of page \(pageNo) out of sync")
                continue
            }
            
            // 1 if a packet was assembled normally. op contains the next packet from the stream.
            if Logger.verbose { Logger.decoding.debug("packet \(packetno) of page \(pageNo) synced") }
            packets.append(packet)
        }
        return packets
    }
    
    fileprivate func alertIfRemainingPackagesOnPage(_ i: Int, _ packets: [ogg_packet], _ pageno: Int, _ packet: ogg_packet) {
        if i < packets.count {
            let errMsg = "skipping \(packets.count-i) packets on page \(pageno) \(packet.packetno) until \(packets[packets.count-1].packetno). Not allowed here."
            Logger.decoding.error(errMsg)
        }
    }
    
    fileprivate func mapOpusPacket(_ packet: ogg_packet ) throws  -> (bos:Bool, eos:Bool) {
        if Logger.verbose { Logger.decoding.debug("packet \(packet.packetno)\(packet.b_o_s > 0 ? " bos" : "")\(packet.e_o_s > 0 ? " eos" : "") has \(packet.bytes) bytes, granulepos is \(packet.granulepos)") }
        
        if packet.e_o_s > 0 {
            Logger.decoding.debug("eos opus packet \(packet.packetno)")
            return (bos:false, eos:true)
        }
        
        if packet.b_o_s > 0 {
            Logger.decoding.debug("bos opus packet \(packet.packetno)")
            
            return (bos:true, eos:false)
        }
        return (bos:false, eos:false)
    }
    
    private func onOpusHead(package: Data, packetno: Int32) throws  {
        
        guard let opusHead = OpusHead(package:package) else {
            let errMsg = "OpusHead in packet \(packetno) expected"
            Logger.decoding.error(errMsg)
            throw AudioDataError(.parsingFailed, errMsg)
        }
        Logger.decoding.notice("OpusHead \(opusHead.debugDescription)")
        guard opusHead.mappingFamily == 0 else {
            let errMsg = "opus mapping family \(opusHead.mappingFamily) not supported, currently only 0"
            Logger.decoding.error(errMsg)
            throw AudioDataError(.notSupported, errMsg)
        }
        
        super.format = AVAudioFormat(commonFormat: AVAudioCommonFormat.otherFormat, sampleRate: 48000, channels: UInt32(opusHead.outChannels), interleaved: true)
        if opusHead.preSkip > 0 {
            opusListener?.preskip(preskip: opusHead.preSkip)
        }
    }
    
    private func onOpusTags(package:Data) -> Bool {
        guard let opusTags = OpusTags(package:package) else {
            return false
        }
        Logger.decoding.notice("OpusTags \(opusTags.debugDescription)")
        let metadata = OpusMetadata(vorbisComments: opusTags.comments)
        opusListener?.metadataReady(metadata)
        return true
    }
    
}

