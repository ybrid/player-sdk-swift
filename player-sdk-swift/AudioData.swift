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
    static func describeFormatId(_ formatId: AudioFormatID) -> String { return describe(formatId: formatId ) }
    static func describeBitdepth(_ bitdepth: AVAudioCommonFormat?) -> String { return describe(bitdepth: bitdepth) }
    
    static func describeProperty(_ property: AudioFileStreamPropertyID) -> String {
        return describe(property)
    }
}

class AudioDataError : LocalizedError {
    enum ErrorKind  {
        case cannotOpenStream
        case parsingFailed
        case invalidStream
        case notSupported
    }
    let kind: ErrorKind
    var message: String?
    var oscode: OSStatus?
    init(_ kind: ErrorKind, _ code: OSStatus) {
        self.kind = kind
        self.oscode = code
    }
    init(_ kind: ErrorKind, _ message: String) {
        self.kind = kind
        self.message = message
    }
    var errorDescription: String? {
        if let oscode = oscode {
            return String(format:"%@.%@ Code=%d \"%@\"", String(describing: Self.self), String(describing: kind), oscode, describe(osstatus: oscode))
        }
        if let message = message {
            return String(format:"%@.%@ '%@'", String(describing: Self.self), String(describing: kind), message)
        }
        return String(format:"%@.%@", String(describing: Self.self), String(describing: kind))
    }
}

// MARK: decriptions of constants

fileprivate func describe(osstatus result: OSStatus ) -> String {
    switch result {
    case kAudioFileStreamError_UnsupportedFileType:
        return "The file type is not supported."
    case kAudioFileStreamError_UnsupportedDataFormat:
        return "The data format is not supported by this file type."
    case kAudioFileStreamError_UnsupportedProperty:
        return "The property is not supported."
    case kAudioFileStreamError_BadPropertySize:
        return "The size of the property data was not correct."
    case kAudioFileStreamError_NotOptimized:
        return "It is not possible to produce output packets because the file's packet table or other defining info is either not present or is after the audio data."
    case kAudioFileStreamError_InvalidPacketOffset:
        return "A packet offset was less than zero, or past the end of the file, or a corrupt packet size was read when building the packet table."
    case kAudioFileStreamError_InvalidFile:
        return "The file is malformed, or otherwise not a valid instance of an audio file of its type, or is not recognized as an audio file."
    case kAudioFileStreamError_ValueUnknown:
        return "The property value is not present in this file before the audio data."
    case  kAudioFileStreamError_DataUnavailable:
        return "The amount of data provided to the parser was insufficient to produce any result."
    case  kAudioFileStreamError_IllegalOperation:
        return "An illegal operation was attempted."
    case kAudioFileStreamError_UnspecifiedError:
        return "An unspecified error has occurred."
    default:
        return "unknown result code \(result)"
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

fileprivate func describe(channelLayout: AudioChannelLayoutTag?) -> String {
    guard let layout = channelLayout else {
        return ""
    }
    switch layout {
    case kAudioChannelLayoutTag_UseChannelDescriptions:
        return "kAudioChannelLayoutTag_UseChannelDescriptions"
    case kAudioChannelLayoutTag_UseChannelBitmap:
        return "kAudioChannelLayoutTag_UseChannelBitmap"
    case kAudioChannelLayoutTag_Mono:
        return "kAudioChannelLayoutTag_Mono"
    case kAudioChannelLayoutTag_Stereo:
        return "kAudioChannelLayoutTag_Stereo"
    case kAudioChannelLayoutTag_StereoHeadphones:
        return "kAudioChannelLayoutTag_StereoHeadphones"
    case kAudioChannelLayoutTag_MatrixStereo:
        return "kAudioChannelLayoutTag_MatrixStereo"
    case kAudioChannelLayoutTag_MidSide:
        return "kAudioChannelLayoutTag_MidSide"
    case kAudioChannelLayoutTag_XY:
        return "kAudioChannelLayoutTag_XY"
    case kAudioChannelLayoutTag_Binaural:
        return "kAudioChannelLayoutTag_Binaural"
    case kAudioChannelLayoutTag_Ambisonic_B_Format:
        return "kAudioChannelLayoutTag_Ambisonic_B_Format"
    case kAudioChannelLayoutTag_Pentagonal:
        return "kAudioChannelLayoutTag_Pentagonal"
    case kAudioChannelLayoutTag_Hexagonal:
        return "kAudioChannelLayoutTag_Hexagonal"
    case kAudioChannelLayoutTag_Octagonal:
        return "kAudioChannelLayoutTag_Octagonal"
    case kAudioChannelLayoutTag_Cube:
        return "kAudioChannelLayoutTag_Cube"
    case kAudioChannelLayoutTag_MPEG_1_0:
        return "kAudioChannelLayoutTag_MPEG_1_0"
    case kAudioChannelLayoutTag_MPEG_2_0:
        return "kAudioChannelLayoutTag_MPEG_2_0"
    case kAudioChannelLayoutTag_MPEG_3_0_A:
        return "kAudioChannelLayoutTag_MPEG_3_0_A"
    case kAudioChannelLayoutTag_MPEG_3_0_B:
        return "kAudioChannelLayoutTag_MPEG_3_0_B"
    case kAudioChannelLayoutTag_MPEG_4_0_A:
        return "kAudioChannelLayoutTag_MPEG_4_0_A"
    case kAudioChannelLayoutTag_MPEG_4_0_B:
        return "kAudioChannelLayoutTag_MPEG_4_0_B"
    case kAudioChannelLayoutTag_MPEG_5_0_A:
        return "kAudioChannelLayoutTag_MPEG_5_0_A"
    case kAudioChannelLayoutTag_MPEG_5_0_B:
        return "kAudioChannelLayoutTag_MPEG_5_0_B"
    case kAudioChannelLayoutTag_MPEG_5_0_C:
        return "kAudioChannelLayoutTag_MPEG_5_0_C"
    case kAudioChannelLayoutTag_MPEG_5_0_D:
        return "kAudioChannelLayoutTag_MPEG_5_0_D"
    case kAudioChannelLayoutTag_MPEG_5_1_A:
        return "kAudioChannelLayoutTag_MPEG_5_1_A"
    case kAudioChannelLayoutTag_MPEG_5_1_B:
        return "kAudioChannelLayoutTag_MPEG_5_1_B"
    case kAudioChannelLayoutTag_MPEG_5_1_C:
        return "kAudioChannelLayoutTag_MPEG_5_1_C"
    case kAudioChannelLayoutTag_MPEG_5_1_D:
        return "kAudioChannelLayoutTag_MPEG_5_1_D"
    case kAudioChannelLayoutTag_MPEG_6_1_A:
        return "kAudioChannelLayoutTag_MPEG_6_1_A"
    case kAudioChannelLayoutTag_MPEG_7_1_A:
        return "kAudioChannelLayoutTag_MPEG_7_1_A"
    case kAudioChannelLayoutTag_MPEG_7_1_B:
        return "kAudioChannelLayoutTag_MPEG_7_1_B"
    case kAudioChannelLayoutTag_MPEG_7_1_C:
        return "kAudioChannelLayoutTag_MPEG_7_1_C"
    case kAudioChannelLayoutTag_Emagic_Default_7_1:
        return "kAudioChannelLayoutTag_Emagic_Default_7_1"
    case kAudioChannelLayoutTag_SMPTE_DTV:
        return "kAudioChannelLayoutTag_SMPTE_DTV"
    case kAudioChannelLayoutTag_ITU_1_0:
        return "kAudioChannelLayoutTag_ITU_1_0"
    case kAudioChannelLayoutTag_ITU_2_0:
        return "kAudioChannelLayoutTag_ITU_2_0"
    case kAudioChannelLayoutTag_ITU_2_1:
        return "kAudioChannelLayoutTag_ITU_2_1"
    case kAudioChannelLayoutTag_ITU_2_2:
        return "kAudioChannelLayoutTag_ITU_2_2"
    case kAudioChannelLayoutTag_ITU_3_0:
        return "kAudioChannelLayoutTag_ITU_3_0"
    case kAudioChannelLayoutTag_ITU_3_1:
        return "kAudioChannelLayoutTag_ITU_3_1"
    case kAudioChannelLayoutTag_ITU_3_2:
        return "kAudioChannelLayoutTag_ITU_3_2"
    case kAudioChannelLayoutTag_ITU_3_2_1:
        return "kAudioChannelLayoutTag_ITU_3_2_1"
    case kAudioChannelLayoutTag_ITU_3_4_1:
        return "kAudioChannelLayoutTag_ITU_3_4_1"
    case kAudioChannelLayoutTag_DVD_0:
        return "kAudioChannelLayoutTag_DVD_0"
    case kAudioChannelLayoutTag_DVD_1:
        return "kAudioChannelLayoutTag_DVD_1"
    case kAudioChannelLayoutTag_DVD_2:
        return "kAudioChannelLayoutTag_DVD_2"
    case kAudioChannelLayoutTag_DVD_3:
        return "kAudioChannelLayoutTag_DVD_3"
    case kAudioChannelLayoutTag_DVD_4:
        return "kAudioChannelLayoutTag_DVD_4"
    case kAudioChannelLayoutTag_DVD_5:
        return "kAudioChannelLayoutTag_DVD_5"
    case kAudioChannelLayoutTag_DVD_6:
        return "kAudioChannelLayoutTag_DVD_6"
    case kAudioChannelLayoutTag_DVD_7:
        return "kAudioChannelLayoutTag_DVD_7"
    case kAudioChannelLayoutTag_DVD_8:
        return "kAudioChannelLayoutTag_DVD_8"
    case kAudioChannelLayoutTag_DVD_9:
        return "kAudioChannelLayoutTag_DVD_9"
    case kAudioChannelLayoutTag_DVD_10:
        return "kAudioChannelLayoutTag_DVD_10"
    case kAudioChannelLayoutTag_DVD_11:
        return "kAudioChannelLayoutTag_DVD_11"
    case kAudioChannelLayoutTag_DVD_12:
        return "kAudioChannelLayoutTag_DVD_12"
    case kAudioChannelLayoutTag_DVD_13:
        return "kAudioChannelLayoutTag_DVD_13"
    case kAudioChannelLayoutTag_DVD_14:
        return "kAudioChannelLayoutTag_DVD_14"
    case kAudioChannelLayoutTag_DVD_15:
        return "kAudioChannelLayoutTag_DVD_15"
    case kAudioChannelLayoutTag_DVD_16:
        return "kAudioChannelLayoutTag_DVD_16"
    case kAudioChannelLayoutTag_DVD_17:
        return "kAudioChannelLayoutTag_DVD_17"
    case kAudioChannelLayoutTag_DVD_18:
        return "kAudioChannelLayoutTag_DVD_18"
    case kAudioChannelLayoutTag_DVD_19:
        return "kAudioChannelLayoutTag_DVD_19"
    case kAudioChannelLayoutTag_DVD_20:
        return "kAudioChannelLayoutTag_DVD_20"
    case kAudioChannelLayoutTag_AudioUnit_4:
        return "kAudioChannelLayoutTag_AudioUnit_4"
    case kAudioChannelLayoutTag_AudioUnit_5:
        return "kAudioChannelLayoutTag_AudioUnit_5"
    case kAudioChannelLayoutTag_AudioUnit_6:
        return "kAudioChannelLayoutTag_AudioUnit_6"
    case kAudioChannelLayoutTag_AudioUnit_8:
        return "kAudioChannelLayoutTag_AudioUnit_8"
    case kAudioChannelLayoutTag_AudioUnit_5_0:
        return "kAudioChannelLayoutTag_AudioUnit_5_0"
    case kAudioChannelLayoutTag_AudioUnit_6_0:
        return "kAudioChannelLayoutTag_AudioUnit_6_0"
    case kAudioChannelLayoutTag_AudioUnit_7_0:
        return "kAudioChannelLayoutTag_AudioUnit_7_0"
    case kAudioChannelLayoutTag_AudioUnit_7_0_Front:
        return "kAudioChannelLayoutTag_AudioUnit_7_0_Front"
    case kAudioChannelLayoutTag_AudioUnit_5_1:
        return "kAudioChannelLayoutTag_AudioUnit_5_1"
    case kAudioChannelLayoutTag_AudioUnit_6_1:
        return "kAudioChannelLayoutTag_AudioUnit_6_1"
    case kAudioChannelLayoutTag_AudioUnit_7_1:
        return "kAudioChannelLayoutTag_AudioUnit_7_1"
    case kAudioChannelLayoutTag_AudioUnit_7_1_Front:
        return "kAudioChannelLayoutTag_AudioUnit_7_1_Front"
    case kAudioChannelLayoutTag_AAC_3_0:
        return "kAudioChannelLayoutTag_AAC_3_0"
    case kAudioChannelLayoutTag_AAC_Quadraphonic:
        return "kAudioChannelLayoutTag_AAC_Quadraphonic"
    case kAudioChannelLayoutTag_AAC_4_0:
        return "kAudioChannelLayoutTag_AAC_4_0"
    case kAudioChannelLayoutTag_AAC_5_0:
        return "kAudioChannelLayoutTag_AAC_5_0"
    case kAudioChannelLayoutTag_AAC_5_1:
        return "kAudioChannelLayoutTag_AAC_5_1"
    case kAudioChannelLayoutTag_AAC_6_0:
        return "kAudioChannelLayoutTag_AAC_6_0"
    case kAudioChannelLayoutTag_AAC_6_1:
        return "kAudioChannelLayoutTag_AAC_6_1"
    case kAudioChannelLayoutTag_AAC_7_0:
        return "kAudioChannelLayoutTag_AAC_7_0"
    case kAudioChannelLayoutTag_AAC_7_1:
        return "kAudioChannelLayoutTag_AAC_7_1"
    case kAudioChannelLayoutTag_AAC_7_1_B:
        return "kAudioChannelLayoutTag_AAC_7_1_B"
    case kAudioChannelLayoutTag_AAC_7_1_C:
        return "kAudioChannelLayoutTag_AAC_7_1_C"
    case kAudioChannelLayoutTag_AAC_Octagonal:
        return "kAudioChannelLayoutTag_AAC_Octagonal"
    case kAudioChannelLayoutTag_TMH_10_2_std:
        return "kAudioChannelLayoutTag_TMH_10_2_std"
    case kAudioChannelLayoutTag_TMH_10_2_full:
        return "kAudioChannelLayoutTag_TMH_10_2_full"
    case kAudioChannelLayoutTag_AC3_1_0_1:
        return "kAudioChannelLayoutTag_AC3_1_0_1"
    case kAudioChannelLayoutTag_AC3_3_0:
        return "kAudioChannelLayoutTag_AC3_3_0"
    case kAudioChannelLayoutTag_AC3_3_1:
        return "kAudioChannelLayoutTag_AC3_3_1"
    case kAudioChannelLayoutTag_AC3_3_0_1:
        return "kAudioChannelLayoutTag_AC3_3_0_1"
    case kAudioChannelLayoutTag_AC3_2_1_1:
        return "kAudioChannelLayoutTag_AC3_2_1_1"
    case kAudioChannelLayoutTag_AC3_3_1_1:
        return "kAudioChannelLayoutTag_AC3_3_1_1"
    case kAudioChannelLayoutTag_EAC_6_0_A:
        return "kAudioChannelLayoutTag_EAC_6_0_A"
    case kAudioChannelLayoutTag_EAC_7_0_A:
        return "kAudioChannelLayoutTag_EAC_7_0_A"
    case kAudioChannelLayoutTag_EAC3_6_1_A:
        return "kAudioChannelLayoutTag_EAC3_6_1_A"
    case kAudioChannelLayoutTag_EAC3_6_1_B:
        return "kAudioChannelLayoutTag_EAC3_6_1_B"
    case kAudioChannelLayoutTag_EAC3_6_1_C:
        return "kAudioChannelLayoutTag_EAC3_6_1_C"
    case kAudioChannelLayoutTag_EAC3_7_1_A:
        return "kAudioChannelLayoutTag_EAC3_7_1_A"
    case kAudioChannelLayoutTag_EAC3_7_1_B:
        return "kAudioChannelLayoutTag_EAC3_7_1_B"
    case kAudioChannelLayoutTag_EAC3_7_1_C:
        return "kAudioChannelLayoutTag_EAC3_7_1_C"
    case kAudioChannelLayoutTag_EAC3_7_1_D:
        return "kAudioChannelLayoutTag_EAC3_7_1_D"
    case kAudioChannelLayoutTag_EAC3_7_1_E:
        return "kAudioChannelLayoutTag_EAC3_7_1_E"
    case kAudioChannelLayoutTag_EAC3_7_1_F:
        return "kAudioChannelLayoutTag_EAC3_7_1_F"
    case kAudioChannelLayoutTag_EAC3_7_1_G:
        return "kAudioChannelLayoutTag_EAC3_7_1_G"
    case kAudioChannelLayoutTag_EAC3_7_1_H:
        return "kAudioChannelLayoutTag_EAC3_7_1_H"
    case kAudioChannelLayoutTag_DTS_3_1:
        return "kAudioChannelLayoutTag_DTS_3_1"
    case kAudioChannelLayoutTag_DTS_4_1:
        return "kAudioChannelLayoutTag_DTS_4_1"
    case kAudioChannelLayoutTag_DTS_6_0_A:
        return "kAudioChannelLayoutTag_DTS_6_0_A"
    case kAudioChannelLayoutTag_DTS_6_0_B:
        return "kAudioChannelLayoutTag_DTS_6_0_B"
    case kAudioChannelLayoutTag_DTS_6_0_C:
        return "kAudioChannelLayoutTag_DTS_6_0_C"
    case kAudioChannelLayoutTag_DTS_6_1_A:
        return "kAudioChannelLayoutTag_DTS_6_1_A"
    case kAudioChannelLayoutTag_DTS_6_1_B:
        return "kAudioChannelLayoutTag_DTS_6_1_B"
    case kAudioChannelLayoutTag_DTS_6_1_C:
        return "kAudioChannelLayoutTag_DTS_6_1_C"
    case kAudioChannelLayoutTag_DTS_7_0:
        return "kAudioChannelLayoutTag_DTS_7_0"
    case kAudioChannelLayoutTag_DTS_7_1:
        return "kAudioChannelLayoutTag_DTS_7_1"
    case kAudioChannelLayoutTag_DTS_8_0_A:
        return "kAudioChannelLayoutTag_DTS_8_0_A"
    case kAudioChannelLayoutTag_DTS_8_0_B:
        return "kAudioChannelLayoutTag_DTS_8_0_B"
    case kAudioChannelLayoutTag_DTS_8_1_A:
        return "kAudioChannelLayoutTag_DTS_8_1_A"
    case kAudioChannelLayoutTag_DTS_8_1_B:
        return "kAudioChannelLayoutTag_DTS_8_1_B"
    case kAudioChannelLayoutTag_DTS_6_1_D:
        return "kAudioChannelLayoutTag_DTS_6_1_D"
    case kAudioChannelLayoutTag_WAVE_2_1:
        return "kAudioChannelLayoutTag_WAVE_2_1"
    case kAudioChannelLayoutTag_WAVE_3_0:
        return "kAudioChannelLayoutTag_WAVE_3_0"
    case kAudioChannelLayoutTag_WAVE_4_0_A:
        return "kAudioChannelLayoutTag_WAVE_4_0_A"
    case kAudioChannelLayoutTag_WAVE_4_0_B:
        return "kAudioChannelLayoutTag_WAVE_4_0_B"
    case kAudioChannelLayoutTag_WAVE_5_0_A:
        return "kAudioChannelLayoutTag_WAVE_5_0_A"
    case kAudioChannelLayoutTag_WAVE_5_0_B:
        return "kAudioChannelLayoutTag_WAVE_5_0_B"
    case kAudioChannelLayoutTag_WAVE_5_1_A:
        return "kAudioChannelLayoutTag_WAVE_5_1_A"
    case kAudioChannelLayoutTag_WAVE_5_1_B:
        return "kAudioChannelLayoutTag_WAVE_5_1_B"
    case kAudioChannelLayoutTag_WAVE_6_1:
        return "kAudioChannelLayoutTag_WAVE_6_1"
    case kAudioChannelLayoutTag_WAVE_7_1:
        return "kAudioChannelLayoutTag_WAVE_7_1"
    case kAudioChannelLayoutTag_HOA_ACN_SN3D:
        return "kAudioChannelLayoutTag_HOA_ACN_SN3D"
    case kAudioChannelLayoutTag_HOA_ACN_N3D:
        return "kAudioChannelLayoutTag_HOA_ACN_N3D"
    case kAudioChannelLayoutTag_Atmos_7_1_4:
        return "kAudioChannelLayoutTag_Atmos_7_1_4"
    case kAudioChannelLayoutTag_Atmos_9_1_6:
        return "kAudioChannelLayoutTag_Atmos_9_1_6"
    case kAudioChannelLayoutTag_Atmos_5_1_2:
        return "kAudioChannelLayoutTag_Atmos_5_1_2"
    case kAudioChannelLayoutTag_DiscreteInOrder:
        return "kAudioChannelLayoutTag_DiscreteInOrder"
    case kAudioChannelLayoutTag_BeginReserved:
        return "kAudioChannelLayoutTag_BeginReserved"
    case kAudioChannelLayoutTag_EndReserved:
        return "kAudioChannelLayoutTag_EndReserved"
    case kAudioChannelLayoutTag_Unknown:
        return "kAudioChannelLayoutTag_Unknown"
        
        
    default: return String("don't know channel layout \(channelLayout)")
    }
}

fileprivate func describe(channelLabel: AudioChannelLabel?) -> String {
    guard let label = channelLabel else {
        return ""
    }
    switch label {
    
    case kAudioChannelLabel_Unknown:
        return "kAudioChannelLabel_Unknown"
    case kAudioChannelLabel_Unused:
        return "kAudioChannelLabel_Unused"
    case kAudioChannelLabel_UseCoordinates:
        return "kAudioChannelLabel_UseCoordinates"
    case kAudioChannelLabel_Left:
        return "kAudioChannelLabel_Left"
    case kAudioChannelLabel_Right:
        return "kAudioChannelLabel_Right"
    case kAudioChannelLabel_Center:
        return "kAudioChannelLabel_Center"
    case kAudioChannelLabel_LFEScreen:
        return "kAudioChannelLabel_LFEScreen"
    case kAudioChannelLabel_LeftSurround:
        return "kAudioChannelLabel_LeftSurround"
    case kAudioChannelLabel_RightSurround:
        return "kAudioChannelLabel_RightSurround"
    case kAudioChannelLabel_LeftCenter:
        return "kAudioChannelLabel_LeftCenter"
    case kAudioChannelLabel_RightCenter:
        return "kAudioChannelLabel_RightCenter"
    case kAudioChannelLabel_CenterSurround:
        return "kAudioChannelLabel_CenterSurround"
    case kAudioChannelLabel_LeftSurroundDirect:
        return "kAudioChannelLabel_LeftSurroundDirect"
    case kAudioChannelLabel_RightSurroundDirect:
        return "kAudioChannelLabel_RightSurroundDirect"
    case kAudioChannelLabel_TopCenterSurround:
        return "kAudioChannelLabel_TopCenterSurround"
    case kAudioChannelLabel_VerticalHeightLeft:
        return "kAudioChannelLabel_VerticalHeightLeft"
    case kAudioChannelLabel_VerticalHeightCenter:
        return "kAudioChannelLabel_VerticalHeightCenter"
    case kAudioChannelLabel_VerticalHeightRight:
        return "kAudioChannelLabel_VerticalHeightRight"
    case kAudioChannelLabel_TopBackLeft:
        return "kAudioChannelLabel_TopBackLeft"
    case kAudioChannelLabel_TopBackCenter:
        return "kAudioChannelLabel_TopBackCenter"
    case kAudioChannelLabel_TopBackRight:
        return "kAudioChannelLabel_TopBackRight"
    case kAudioChannelLabel_RearSurroundLeft:
        return "kAudioChannelLabel_RearSurroundLeft"
    case kAudioChannelLabel_RearSurroundRight:
        return "kAudioChannelLabel_RearSurroundRight"
    case kAudioChannelLabel_LeftWide:
        return "kAudioChannelLabel_LeftWide"
    case kAudioChannelLabel_RightWide:
        return "kAudioChannelLabel_RightWide"
    case kAudioChannelLabel_LFE2:
        return "kAudioChannelLabel_LFE2"
    case kAudioChannelLabel_LeftTotal:
        return "kAudioChannelLabel_LeftTotal"
    case kAudioChannelLabel_RightTotal:
        return "kAudioChannelLabel_RightTotal"
    case kAudioChannelLabel_HearingImpaired:
        return "kAudioChannelLabel_HearingImpaired"
    case kAudioChannelLabel_Narration:
        return "kAudioChannelLabel_Narration"
    case kAudioChannelLabel_Mono:
        return "kAudioChannelLabel_Mono"
    case kAudioChannelLabel_DialogCentricMix:
        return "kAudioChannelLabel_DialogCentricMix"
    case kAudioChannelLabel_CenterSurroundDirect:
        return "kAudioChannelLabel_CenterSurroundDirect"
    case kAudioChannelLabel_Haptic:
        return "kAudioChannelLabel_Haptic"
    case kAudioChannelLabel_LeftTopFront:
        return "kAudioChannelLabel_LeftTopFront"
    case kAudioChannelLabel_CenterTopFront:
        return "kAudioChannelLabel_CenterTopFront"
    case kAudioChannelLabel_RightTopFront:
        return "kAudioChannelLabel_RightTopFront"
    case kAudioChannelLabel_LeftTopMiddle:
        return "kAudioChannelLabel_LeftTopMiddle"
    case kAudioChannelLabel_CenterTopMiddle:
        return "kAudioChannelLabel_CenterTopMiddle"
    case kAudioChannelLabel_RightTopMiddle:
        return "kAudioChannelLabel_RightTopMiddle"
    case kAudioChannelLabel_LeftTopRear:
        return "kAudioChannelLabel_LeftTopRear"
    case kAudioChannelLabel_CenterTopRear:
        return "kAudioChannelLabel_CenterTopRear"
    case kAudioChannelLabel_RightTopRear:
        return "kAudioChannelLabel_RightTopRear"
    case kAudioChannelLabel_Ambisonic_W:
        return "kAudioChannelLabel_Ambisonic_W"
    case kAudioChannelLabel_Ambisonic_X:
        return "kAudioChannelLabel_Ambisonic_X"
    case kAudioChannelLabel_Ambisonic_Y:
        return "kAudioChannelLabel_Ambisonic_Y"
    case kAudioChannelLabel_Ambisonic_Z:
        return "kAudioChannelLabel_Ambisonic_Z"
    case kAudioChannelLabel_MS_Mid:
        return "kAudioChannelLabel_MS_Mid"
    case kAudioChannelLabel_MS_Side:
        return "kAudioChannelLabel_MS_Side"
    case kAudioChannelLabel_XY_X:
        return "kAudioChannelLabel_XY_X"
    case kAudioChannelLabel_XY_Y:
        return "kAudioChannelLabel_XY_Y"
    case kAudioChannelLabel_BinauralLeft:
        return "kAudioChannelLabel_BinauralLeft"
    case kAudioChannelLabel_BinauralRight:
        return "kAudioChannelLabel_BinauralRight"
    case kAudioChannelLabel_HeadphonesLeft:
        return "kAudioChannelLabel_HeadphonesLeft"
    case kAudioChannelLabel_HeadphonesRight:
        return "kAudioChannelLabel_HeadphonesRight"
    case kAudioChannelLabel_ClickTrack:
        return "kAudioChannelLabel_ClickTrack"
    case kAudioChannelLabel_ForeignLanguage:
        return "kAudioChannelLabel_ForeignLanguage"
    case kAudioChannelLabel_Discrete:
        return "kAudioChannelLabel_Discrete"
    case kAudioChannelLabel_Discrete_0:
        return "kAudioChannelLabel_Discrete_0"
    case kAudioChannelLabel_Discrete_1:
        return "kAudioChannelLabel_Discrete_1"
    case kAudioChannelLabel_Discrete_2:
        return "kAudioChannelLabel_Discrete_2"
    case kAudioChannelLabel_Discrete_3:
        return "kAudioChannelLabel_Discrete_3"
    case kAudioChannelLabel_Discrete_4:
        return "kAudioChannelLabel_Discrete_4"
    case kAudioChannelLabel_Discrete_5:
        return "kAudioChannelLabel_Discrete_5"
    case kAudioChannelLabel_Discrete_6:
        return "kAudioChannelLabel_Discrete_6"
    case kAudioChannelLabel_Discrete_7:
        return "kAudioChannelLabel_Discrete_7"
    case kAudioChannelLabel_Discrete_8:
        return "kAudioChannelLabel_Discrete_8"
    case kAudioChannelLabel_Discrete_9:
        return "kAudioChannelLabel_Discrete_9"
    case kAudioChannelLabel_Discrete_10:
        return "kAudioChannelLabel_Discrete_10"
    case kAudioChannelLabel_Discrete_11:
        return "kAudioChannelLabel_Discrete_11"
    case kAudioChannelLabel_Discrete_12:
        return "kAudioChannelLabel_Discrete_12"
    case kAudioChannelLabel_Discrete_13:
        return "kAudioChannelLabel_Discrete_13"
    case kAudioChannelLabel_Discrete_14:
        return "kAudioChannelLabel_Discrete_14"
    case kAudioChannelLabel_Discrete_15:
        return "kAudioChannelLabel_Discrete_15"
    case kAudioChannelLabel_Discrete_65535:
        return "kAudioChannelLabel_Discrete_65535"
    case kAudioChannelLabel_HOA_ACN:
        return "kAudioChannelLabel_HOA_ACN"
    case kAudioChannelLabel_HOA_ACN_0:
        return "kAudioChannelLabel_HOA_ACN_0"
    case kAudioChannelLabel_HOA_ACN_1:
        return "kAudioChannelLabel_HOA_ACN_1"
    case kAudioChannelLabel_HOA_ACN_2:
        return "kAudioChannelLabel_HOA_ACN_2"
    case kAudioChannelLabel_HOA_ACN_3:
        return "kAudioChannelLabel_HOA_ACN_3"
    case kAudioChannelLabel_HOA_ACN_4:
        return "kAudioChannelLabel_HOA_ACN_4"
    case kAudioChannelLabel_HOA_ACN_5:
        return "kAudioChannelLabel_HOA_ACN_5"
    case kAudioChannelLabel_HOA_ACN_6:
        return "kAudioChannelLabel_HOA_ACN_6"
    case kAudioChannelLabel_HOA_ACN_7:
        return "kAudioChannelLabel_HOA_ACN_7"
    case kAudioChannelLabel_HOA_ACN_8:
        return "kAudioChannelLabel_HOA_ACN_8"
    case kAudioChannelLabel_HOA_ACN_9:
        return "kAudioChannelLabel_HOA_ACN_9"
    case kAudioChannelLabel_HOA_ACN_10:
        return "kAudioChannelLabel_HOA_ACN_10"
    case kAudioChannelLabel_HOA_ACN_11:
        return "kAudioChannelLabel_HOA_ACN_11"
    case kAudioChannelLabel_HOA_ACN_12:
        return "kAudioChannelLabel_HOA_ACN_12"
    case kAudioChannelLabel_HOA_ACN_13:
        return "kAudioChannelLabel_HOA_ACN_13"
    case kAudioChannelLabel_HOA_ACN_14:
        return "kAudioChannelLabel_HOA_ACN_14"
    case kAudioChannelLabel_HOA_ACN_15:
        return "kAudioChannelLabel_HOA_ACN_15"
    case kAudioChannelLabel_HOA_ACN_65024:
        return "kAudioChannelLabel_HOA_ACN_65024"
    case kAudioChannelLabel_BeginReserved:
        return "kAudioChannelLabel_BeginReserved"
    case kAudioChannelLabel_EndReserved:
        return "kAudioChannelLabel_EndReserved"
    default: return String("don't know channel label \(label)")
    }
}
