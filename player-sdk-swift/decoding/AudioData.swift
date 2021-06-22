//
// AudioData.swift
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


import AVFoundation


protocol AudioDataListener : class {
    func onFormatChanged(_ srcFormat : AVAudioFormat)
}

class AudioData {
    
    var format: AVAudioFormat? {
        didSet {
            if format != nil {
                listener.onFormatChanged(format!)
            }
        }
    }
    let listener:AudioDataListener
    typealias Package = (data:Data,description:AudioStreamPacketDescription?)
     
    init(audioContentType: AudioFileTypeID, listener: AudioDataListener) throws {
        self.listener = listener
    }
    
    deinit {
        Logger.decoding.debug()
    }
    
    /// delegates for visibility
    static func describeFileTypeId(_ type: AudioFileTypeID) -> String { return describe(type: type ) }
    static func describeFormatId(_ formatId: AudioFormatID) -> String { return describe(formatId: formatId ) }
    static func describeBitdepth(_ bitdepth: AVAudioCommonFormat?) -> String { return describe(bitdepth: bitdepth) }
    static func describeProperty(_ property: AudioFileStreamPropertyID) -> String {
        return describe(property)
    }
}

// MARK: decriptions of constants

fileprivate func describe(type: AudioFileTypeID) -> String {
    switch type {
    case kAudioFileAIFFType: return "kAudioFileAIFFType"
    case kAudioFileAIFCType: return "kAudioFileAIFCType"
    case kAudioFileWAVEType: return "kAudioFileWAVEType"
    case kAudioFileRF64Type: return "kAudioFileRF64Type"
    case kAudioFileBW64Type: return "kAudioFileBW64Type"
    case kAudioFileWave64Type: return "kAudioFileWave64Type"
    case kAudioFileSoundDesigner2Type: return "kAudioFileSoundDesigner2Type"
    case kAudioFileNextType: return "kAudioFileNextType"
    case kAudioFileMP3Type: return "kAudioFileMP3Type" // mpeg layer 3
    case kAudioFileMP2Type: return "kAudioFileMP2Type" // mpeg layer 2
    case kAudioFileMP1Type: return "kAudioFileMP1Type" // mpeg layer 1
    case kAudioFileAC3Type: return "kAudioFileAC3Type"
    case kAudioFileAAC_ADTSType: return "kAudioFileAAC_ADTSType"
    case kAudioFileMPEG4Type: return "kAudioFileMPEG4Type"
    case kAudioFileM4AType: return "kAudioFileM4AType"
    case kAudioFileM4BType: return "kAudioFileM4BType"
    case kAudioFileCAFType: return "kAudioFileCAFType"
    case kAudioFile3GPType: return "kAudioFile3GPType"
    case kAudioFile3GP2Type: return "kAudioFile3GP2Type"
    case kAudioFileAMRType: return "kAudioFileAMRType"
    case kAudioFileFLACType: return "kAudioFileFLACType"
    case kAudioFileLATMInLOASType: return "kAudioFileLATMInLOASType"
    case kAudioFormatOpus: return "kAudioFormatOpus" /// devnote: added for opus in ogg
    default: return String(format: "unknown audio file type with id %i", type)
    }
}

/// all possible properties
fileprivate func describe(_ property: AudioFileStreamPropertyID) -> String {
    switch property {
    case kAudioFileStreamProperty_ReadyToProducePackets:
        return "kAudioFileStreamProperty_ReadyToProducePackets"
    case kAudioFileStreamProperty_FileFormat:
        return "kAudioFileStreamProperty_FileFormat"
    case kAudioFileStreamProperty_DataFormat:
        return "kAudioFileStreamProperty_DataFormat"
    case kAudioFileStreamProperty_FormatList:
        return "kAudioFileStreamProperty_FormatList"
    case kAudioFileStreamProperty_MagicCookieData:
        return "kAudioFileStreamProperty_MagicCookieData"
    case kAudioFileStreamProperty_AudioDataByteCount:
        return "kAudioFileStreamProperty_AudioDataByteCount"
    case kAudioFileStreamProperty_AudioDataPacketCount:
        return "kAudioFileStreamProperty_AudioDataPacketCount"
    case kAudioFileStreamProperty_MaximumPacketSize:
        return "kAudioFileStreamProperty_MaximumPacketSize"
    case kAudioFileStreamProperty_DataOffset:
        return "kAudioFileStreamProperty_DataOffset"
    case kAudioFileStreamProperty_ChannelLayout:
        return "kAudioFileStreamProperty_ChannelLayout"
    case kAudioFileStreamProperty_PacketToFrame:
        return "kAudioFileStreamProperty_PacketToFrame"
    case kAudioFileStreamProperty_FrameToPacket:
        return "kAudioFileStreamProperty_FrameToPacket"
    case kAudioFileStreamProperty_RestrictsRandomAccess:
        return "kAudioFileStreamProperty_RestrictsRandomAccess"
    case kAudioFileStreamProperty_PacketToRollDistance:
        return "kAudioFileStreamProperty_PacketToRollDistance"
    case kAudioFileStreamProperty_PreviousIndependentPacket:
        return "kAudioFileStreamProperty_PreviousIndependentPacket"
    case kAudioFileStreamProperty_NextIndependentPacket:
        return "kAudioFileStreamProperty_NextIndependentPacket"
    case kAudioFileStreamProperty_PacketToDependencyInfo:
        return "kAudioFileStreamProperty_PacketToDependencyInfo"
    case kAudioFileStreamProperty_PacketToByte:
        return "kAudioFileStreamProperty_PacketToByte"
    case kAudioFileStreamProperty_ByteToPacket:
        return "kAudioFileStreamProperty_ByteToPacket"
    case kAudioFileStreamProperty_PacketTableInfo:
        return "kAudioFileStreamProperty_PacketTableInfo"
    case kAudioFileStreamProperty_PacketSizeUpperBound:
        return "kAudioFileStreamProperty_PacketSizeUpperBound"
    case kAudioFileStreamProperty_AverageBytesPerPacket:
        return "kAudioFileStreamProperty_AverageBytesPerPacket"
    case kAudioFileStreamProperty_BitRate:
        return "kAudioFileStreamProperty_BitRate"
    case kAudioFileStreamProperty_InfoDictionary:
        return "kAudioFileStreamProperty_InfoDictionary"
    default:
        return String(format: "unknown property with id %i", property)
    }
}

/// all possible formatIds
fileprivate func describe(formatId: AudioFormatID) -> String {
    switch formatId {
    case kAudioFormatLinearPCM:
        return "kAudioFormatLinearPCM"
    case kAudioFormatAC3:
        return "kAudioFormatAC3"
    case kAudioFormat60958AC3:
        return "kAudioFormat60958AC3"
    case kAudioFormatAppleIMA4:
        return "kAudioFormatAppleIMA4"
    case kAudioFormatMPEG4AAC:
        return "kAudioFormatMPEG4AAC"
    case kAudioFormatMPEG4CELP:
        return "kAudioFormatMPEG4CELP"
    case kAudioFormatMPEG4HVXC:
        return "kAudioFormatMPEG4HVXC"
    case kAudioFormatMPEG4TwinVQ:
        return "kAudioFormatMPEG4TwinVQ"
    case kAudioFormatMACE3:
        return "kAudioFormatMACE3"
    case kAudioFormatMACE6:
        return "kAudioFormatMACE6"
    case kAudioFormatULaw:
        return "kAudioFormatULaw"
    case kAudioFormatALaw:
        return "kAudioFormatALaw"
    case kAudioFormatQDesign:
        return "kAudioFormatQDesign"
    case kAudioFormatQDesign2:
        return "kAudioFormatQDesign2"
    case kAudioFormatQUALCOMM:
        return "kAudioFormatQUALCOMM"
    case kAudioFormatMPEGLayer1:
        return "kAudioFormatMPEGLayer1"
    case kAudioFormatMPEGLayer2:
        return "kAudioFormatMPEGLayer2"
    case kAudioFormatMPEGLayer3:
        return "kAudioFormatMPEGLayer3"
    case kAudioFormatTimeCode:
        return "kAudioFormatTimeCode"
    case kAudioFormatMIDIStream:
        return "kAudioFormatMIDIStream"
    case kAudioFormatParameterValueStream:
        return "kAudioFormatParameterValueStream"
    case kAudioFormatAppleLossless:
        return "kAudioFormatAppleLossless"
    case kAudioFormatMPEG4AAC_HE:
        return "kAudioFormatMPEG4AAC_HE"
    case kAudioFormatMPEG4AAC_LD:
        return "kAudioFormatMPEG4AAC_LD"
    case kAudioFormatMPEG4AAC_ELD:
        return "kAudioFormatMPEG4AAC_ELD"
    case kAudioFormatMPEG4AAC_ELD_SBR:
        return "kAudioFormatMPEG4AAC_ELD_SBR"
    case kAudioFormatMPEG4AAC_ELD_V2:
        return "kAudioFormatMPEG4AAC_ELD_V2"
    case kAudioFormatMPEG4AAC_HE_V2:
        return "kAudioFormatMPEG4AAC_HE_V2"
    case kAudioFormatMPEG4AAC_Spatial:
        return "kAudioFormatMPEG4AAC_Spatial"
    case kAudioFormatMPEGD_USAC:
        return "kAudioFormatMPEGD_USAC"
    case kAudioFormatAMR:
        return "kAudioFormatAMR"
    case kAudioFormatAMR_WB:
        return "kAudioFormatAMR_WB"
    case kAudioFormatAudible:
        return "kAudioFormatAudible"
    case kAudioFormatiLBC:
        return "kAudioFormatiLBC"
    case kAudioFormatDVIIntelIMA:
        return "kAudioFormatDVIIntelIMA"
    case kAudioFormatMicrosoftGSM:
        return "kAudioFormatMicrosoftGSM"
    case kAudioFormatAES3:
        return "kAudioFormatAES3"
    case kAudioFormatEnhancedAC3:
        return "kAudioFormatEnhancedAC3"
    case kAudioFormatFLAC:
        return "kAudioFormatFLAC"
    case kAudioFormatOpus:
        return "kAudioFormatOpus"
    default:
        return String(format: "unknown audio format with id %i", formatId)
    }
}

fileprivate func describe(bitdepth commonFormat: AVAudioCommonFormat?) -> String {
    guard let common = commonFormat else {
        return ""
    }
    switch common.rawValue {
    case 0: return "no pcm"
    case 1: return "pcmFloat32"
    case 2: return "pcmFloat64"
    case 3: return "pcmInt16"
    case 4: return "pcmInt32"
    default: return String(format: "unknown bitdepth  with id %i", common.rawValue)
    }
}
