//
//  JYAudioACCEncoder.m
//  JYAURecorder
//
//  Created by wangjy on 2021/9/23.
//

#import "JYAudioACCEncoder.h"
#import <AudioToolbox/AudioToolbox.h>
#import "JYRecorderLog.h"
#import <AudioToolbox/AudioFile.h>
#define MIN_ENCODE_BITRATE 8000
#define MAX_ENCODE_BITRATE 320000
#define kAACPacketPerFrame 1024


static OSStatus ACCEncoderDataProc(AudioConverterRef inAudioConverter,
                                UInt32 *ioNumberDataPackets,
                                AudioBufferList *ioData,
                                AudioStreamPacketDescription **outDataPacketDescription,
                                void *inUserData) {
    AudioFileIORef afio = (AudioFileIORef)inUserData;
    if (afio->audioBuffer == NULL) {
        *ioNumberDataPackets = 0;
        return -1;
    }
    *ioNumberDataPackets = 1;
    ioData->mBuffers[0].mData = afio->audioBuffer;
    ioData->mBuffers[0].mNumberChannels = afio->audioFormat.mChannelsPerFrame;
    ioData->mBuffers[0].mDataByteSize = afio->audioBufferByteSize;
//    afio->pcmBufferReadPos += afio->pcmBufferNumPacket;

    return noErr;
}

@interface JYAudioAACEncoder () {
    AudioConverterRef audioConverterRef;
    AudioFileIORef inputFileRef;
    AudioFormatIORef outputFormatRef;
}

@end
@implementation JYAudioAACEncoder
@synthesize delegate = _delegate;

- (BOOL)prepareEncoderWithInputFile:(AudioFileIO)inputFile outputFile:(AudioFormatIO)outputFormat {
//    self.recordPacket = 0;
//    self.outputFileID = NULL;
//
//    self.pcmDataBuffer = [NSMutableData data];
//    self.pcmBufferPacket = 0;
    
    //    AudioFileIO afio = {};
    inputFileRef = &inputFile;
    outputFormatRef = &outputFormat;

    AudioStreamBasicDescription aacFormatDes = {};
    aacFormatDes.mFormatID = kAudioFormatMPEG4AAC;
    aacFormatDes.mSampleRate = outputFormat.sampleRate;
    aacFormatDes.mChannelsPerFrame = outputFormat.channels;
    aacFormatDes.mFramesPerPacket = kAACPacketPerFrame;

    UInt32 size = sizeof(aacFormatDes);
    XReturnNoIfError(checkErrorAndStopIfError(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &aacFormatDes), @"get AAC foramtInfo error"));
    //判断编码采样率是否有效
    size = 0;
    XReturnNoIfError(checkErrorAndStopIfError(AudioFormatGetPropertyInfo(kAudioFormatProperty_AvailableEncodeSampleRates,
                                                                                 sizeof(aacFormatDes.mFormatID),
                                                                                 &aacFormatDes.mFormatID,
                                                                                 &size), @"get available encode sampleRate size error"));

    UInt32 numEncodeSampleRate = size / sizeof(AudioValueRange);
    AudioValueRange sampleRateArr[numEncodeSampleRate];
    XReturnNoIfError(checkErrorAndStopIfError(AudioFormatGetProperty(kAudioFormatProperty_AvailableEncodeSampleRates,
                                                                             sizeof(aacFormatDes.mFormatID),
                                                                             &aacFormatDes.mFormatID,
                                                                             &size,
                                                                             sampleRateArr), @"get available encode sampleRate error"));

    AudioValueRange sampleRateRange;
    BOOL isSampleRateVaild = NO;
    for (int i = 0; i < numEncodeSampleRate; i++) {
        sampleRateRange = sampleRateArr[i];
        JYLog(@"applicable sample rate max:%f, min:%f", sampleRateRange.mMaximum, sampleRateRange.mMinimum);
        if (sampleRateRange.mMinimum > 0 && outputFormat.sampleRate == sampleRateRange.mMinimum) {
            isSampleRateVaild = YES;
            break;
        }
    }

    if (isSampleRateVaild == NO) {
        JYLog(@"samplerate not available");
        return NO;
    }

    // 编码器转码设置
    if (audioConverterRef != NULL) {
        XReturnNoIfError(checkErrorAndStopIfError(AudioConverterDispose(audioConverterRef), @"dispose last encodeCoverter fail"));
        audioConverterRef = NULL;
    }
    XReturnNoIfError([self configureAACConverterWithInputFormat:inputFile.audioFormat AACFormat:aacFormatDes BitRate:outputFormat.bitRate] == NO);
    return YES;

//    AudioFileID outputFileID;
//    XReturnNoneIfError(checkErrorAndStopIfError(AudioFileCreateWithURL((__bridge CFURLRef _Nonnull)(self.url),
//                                                                             kAudioFileM4AType,
//                                                                             &aacFormatDes,
//                                                                             kAudioFileFlags_EraseFile,
//                                                                             &outputFileID), @"AudioFileCreate Fail"));

//    self.outputFileID = outputFileID;
//    XReturnNoneIfError([self copyEncoderCookieToFile] == NO);
}

- (BOOL)configureAACConverterWithInputFormat:(AudioStreamBasicDescription)inputFormat AACFormat:(AudioStreamBasicDescription)aacFormatDes BitRate:(UInt32)desBitRate {
    UInt32 size = 0;
    XReturnNoIfError(checkErrorAndStopIfError(AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders, sizeof(aacFormatDes.mFormatID), &aacFormatDes.mFormatID, &size), @"get AAC converter encoders size fail"));
    //选择软件编码
    UInt32 numEncoders = size / sizeof(AudioClassDescription);
    AudioClassDescription audioClassArr[numEncoders];
    XReturnNoIfError(checkErrorAndStopIfError(AudioFormatGetProperty(kAudioFormatProperty_Encoders,
                                                                           sizeof(aacFormatDes.mFormatID),
                                                                           &aacFormatDes.mFormatID,
                                                                           &size,
                                                                           audioClassArr), @"get AAC converter encoders array fail"));
    AudioClassDescription audioClassDes;
    for (int i = 0; i < numEncoders; i++) {
        if (audioClassArr[i].mSubType == kAudioFormatMPEG4AAC && audioClassArr[i].mManufacturer == kAppleSoftwareAudioCodecManufacturer) {
            memcpy(&audioClassDes, &audioClassArr[i], sizeof(AudioClassDescription));
            break;
        }
    }

    XReturnNoIfError(checkErrorAndStopIfError(AudioConverterNewSpecific(&inputFormat, &aacFormatDes, 1, &audioClassDes, &audioConverterRef), @"init AAC converter fail"));

    // 设置码率，需要和采样率对应
//    NSNumber *encodeBitRate = [self.settings objectForKey:WAEncoderBitRateKey];
    UInt32 outputBitRate = desBitRate;

    //判断码率是否有效
    size = 0;
    XReturnNoIfError(checkErrorAndStopIfError(AudioConverterGetPropertyInfo(audioConverterRef, kAudioConverterApplicableEncodeBitRates, &size, NULL), @"get AAC converter encoders size fail"));

    UInt32 numEncodeBitRate = size / sizeof(AudioValueRange);
    AudioValueRange bitRateArr[numEncodeBitRate];
    XReturnNoIfError(checkErrorAndStopIfError(AudioConverterGetProperty(audioConverterRef, kAudioConverterApplicableEncodeBitRates, &size, bitRateArr), @"get AAC converter encoders array fail"));
    AudioValueRange bitRate;
    Float64 minBitRate = MAX_ENCODE_BITRATE;
    Float64 maxBitRate = MIN_ENCODE_BITRATE;
    for (int i = 0; i < numEncodeBitRate; i++) {
        bitRate = bitRateArr[i];
        JYLog(@"applicable bitRate max:%f, min:%f", bitRate.mMaximum, bitRate.mMinimum);

        if (bitRate.mMinimum >= MIN_ENCODE_BITRATE && bitRate.mMinimum <= MAX_ENCODE_BITRATE && bitRate.mMaximum >= MIN_ENCODE_BITRATE
            && bitRate.mMaximum <= MAX_ENCODE_BITRATE) {
            if (maxBitRate == 0 && bitRate.mMinimum > 0) {
                maxBitRate = bitRate.mMinimum;
            }
            if (bitRate.mMinimum > 0 && bitRate.mMinimum < minBitRate) {
                minBitRate = bitRate.mMinimum;
            }
            if (bitRate.mMaximum > maxBitRate) {
                maxBitRate = bitRate.mMaximum;
            }
        }
    }

    if (outputBitRate < minBitRate || outputBitRate > maxBitRate) {
//        [self onNotifyStateChangeOnMainThread:WARecorderStateError
//                                        error:[NSError errorWithDomain:@"WAAACRecorderErrorDomain"
//                                                                  code:WARecorderErrEncoderParamsErr
//                                                              userInfo:@{ NSLocalizedDescriptionKey : @"encodeBitRate not applicable" }]];
        JYLog(@"encodeBitRate apply error");
        return NO;
    }

    size = sizeof(outputBitRate);
    XReturnNoIfError(checkErrorAndStopIfError(AudioConverterSetProperty(audioConverterRef, kAudioConverterEncodeBitRate, size, &outputBitRate), @"encodeBitRate not applicable"));
    return YES;
}

- (void)encodeAudioData:(unsigned char *)audioData {
    UInt32 outputSizePerPacket = 0;
    UInt32 size = sizeof(outputSizePerPacket);
    XReturnNoneIfError(checkErrorAndStopIfError(AudioConverterGetProperty(audioConverterRef,
                                                                kAudioConverterPropertyMaximumOutputPacketSize,
                                                                &size,
                                                                          &outputSizePerPacket), @"get maximumOutputPacketSize fail"));

    
    UInt32 outputBufferSize = inputFileRef->audioBufferNumPacket;
    AudioBufferList *outputBuffer = (AudioBufferList *)malloc(sizeof(AudioBufferList));
    outputBuffer->mNumberBuffers = 1;
    outputBuffer->mBuffers[0].mDataByteSize = outputBufferSize;
    outputBuffer->mBuffers[0].mData = malloc(outputBufferSize);
    outputBuffer->mBuffers[0].mNumberChannels = inputFileRef->audioFormat.mChannelsPerFrame;
    
    UInt32 ioOutputDataPackets = 1;
    AudioStreamPacketDescription *outputPacketDescriptions =
    (AudioStreamPacketDescription *)malloc(ioOutputDataPackets * sizeof(AudioStreamPacketDescription));
    
    BOOL fillComplexBufferError = AudioConverterFillComplexBuffer(audioConverterRef,
                                                                                                ACCEncoderDataProc,
                                                                                                &inputFileRef,
                                                                                                &ioOutputDataPackets,
                                                             outputBuffer,
                                                             outputPacketDescriptions);
    if(!fillComplexBufferError) {
        JYLog(@"AudioConverterFillComplexBuffer fail");
        if (outputPacketDescriptions)
            free(outputPacketDescriptions);
        if (outputBuffer) {
            free(outputBuffer->mBuffers[0].mData);
            free(outputBuffer);
        }
        return;
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(encodeAudioDataFinished:)]) {
        [self.delegate encodeAudioDataFinished:(unsigned char *)outputBuffer->mBuffers[0].mData];
    }
    if (outputPacketDescriptions)
        free(outputPacketDescriptions);
    if (outputBuffer) {
        free(outputBuffer->mBuffers[0].mData);
        free(outputBuffer);
    }
    
}
@end

