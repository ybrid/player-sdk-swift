//
// AudioDecoderFactory.swift
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

import AVFoundation

class AudioDecoderFactory {
    
    func createDecoder(_ mimeType: String?, _ filename: String?, listener: DecoderListener, notify: @escaping DecoderNotification) throws -> AudioDecoder {

        guard let mimeType = mimeType else {
            throw AudioDataError(.cannotResolveDecoder, "missing mimeType")
        }
    
        if isOpusAudioFileType( mimeType, filename: filename )  {
            Logger.loading.debug("mimeType \(mimeType) with filename \(String(describing: filename)) resolved to opus decoder")
            return try createOpusDecoder(listener: listener)
        }
        
        if let ext = (filename as NSString?)?.pathExtension {
    
            if let typeHint = getAudioFileTypeHint(mimeType: mimeType, ext: ext) {
                Logger.loading.debug("mimeType \(mimeType) resolved to system audio decoder with hint \(AudioData.describeFileTypeId(typeHint))")
                return try createSystemDecoder(listener: listener, fileTypeHint: typeHint, notify: notify)
            }
            
            if "txt" == ext { // todo throw excp in SystemDecoder
                throw AudioDataError(.cannotResolveDecoder, "cannot resolve audio decoder for \(mimeType) with filename \(String(describing: filename))")
            }
        }
        
        Logger.loading.debug("mimeType \(mimeType) resolved to system audio decoder")
        return try createSystemDecoder(listener: listener, notify: notify)
    }
    
    private func createOpusDecoder(listener: DecoderListener) throws -> AudioDecoder {
        let ogg = try OggContainer()
        return try OpusDecoder(container: ogg, decodingListener: listener)
    }

    private func createSystemDecoder(listener: DecoderListener, fileTypeHint: AudioFileTypeID? = nil, notify: @escaping DecoderNotification) throws -> AudioDecoder {
        return try SystemDecoder(decodingListener: listener, fileTypeHint: fileTypeHint, notify: notify)
    }

    private func isOpusAudioFileType(_ mimeType:String, filename:String?) -> Bool {
        if isOpusAudioFileType(mimeType) {
            return true
        }
        if let name = filename {
            return isOpusAudioFileType(filename:name)
        }
        return false
    }

    private func getAudioFileTypeHint(mimeType:String, ext:String) -> AudioFileTypeID? {
        getAudioFileTypeHint(mimeType: mimeType) ?? getAudioFileTypeHint(ext: ext)
    }

    
    private func getAudioFileTypeHint(ext:String) -> AudioFileTypeID? {
        switch ext {
        case "mp3":
            return kAudioFileMP3Type
        case "mp4", "m4a", "m4b", "m4p", "m4r", "m4v", "aac":
            return kAudioFileMPEG4Type
        default:
            return nil
        }
    }
    
    private func getAudioFileTypeHint(mimeType:String) -> AudioFileTypeID? {
        switch mimeType {
        case "audio/mpeg" :
            return kAudioFileMP3Type
        case "audio/aac", "audio/aacp":
            return kAudioFileAAC_ADTSType
        case "video/mp4", "audio/mp4":
            return kAudioFileMPEG4Type
        case "audio/x-wav":
            return kAudioFileWAVEType
        default:
           return nil
        }
    }
    
    private func isOpusAudioFileType(_ mimeType:String) -> Bool {
        switch mimeType {
        case "application/ogg", "audio/ogg":
            return true
        default:
            return false
        }
    }
    
    private func isOpusAudioFileType(filename:String) -> Bool {
        let ext = (filename as NSString).pathExtension
        return "opus" == ext
    }
}
