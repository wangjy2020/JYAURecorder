//
//  JYAURecorder.m
//  JYAURecorder
//
//  Created by wangjy on 2021/8/18.
//

#import "JYAURecorder.h"
#import <Foundation/Foundation.h>
#import <AVFoundation/AVAudioSession.h>
#import <AudioToolbox/AUComponent.h>
#import "ScopedLock.h"
#import "JYAudioFile.h"
#import "TPCircularBuffer+AudioBufferList.h"
#import "JYRecordCoordinator.h"
#import "JYRecorderLog.h"

const char * GetAudioOSStatusError(OSStatus error) {
    static char str[16];

    *(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
    if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
        str[0] = str[5] = '\'';
        str[6] = '\0';
    } else if (error > -200000 && error < 200000)
        // no, format it as an integer
        sprintf(str, "%d", (int)error);
    else
        sprintf(str, "0x%x", (int)error);

    return str;
}

static OSStatus
recordingCallBack(    void *                            inRefCon,
                        AudioUnitRenderActionFlags *    ioActionFlags,
                        const AudioTimeStamp *            inTimeStamp,
                        UInt32                            inBusNumber,
                        UInt32                            inNumberFrames,
                    AudioBufferList * __nullable    ioData) {
    @autoreleasepool {
        JYAURecorder *pRefObj = (__bridge JYAURecorder *)inRefCon;
        if (pRefObj == nil) {
            JYLog(@"pRefObj is nil");
            return 0;
        }
        if (!pRefObj->mAUState.isRunning) {
            JYLog(@"pRefObj is not running");
            return 0;
        }
        if (pRefObj->pRecBuffLeft == NULL) {
            JYLog(@"pRefObj->pRecBuffLeft == NULL");
            return 0;
        }
        
        id<AUAudioDataSource> pDS = pRefObj->mAUState.recordDS;
        if (pDS == nil) {
            JYLog(@"recordDS == NULL");
        }

        AudioBufferList *bufferList = (AudioBufferList *)malloc(sizeof(AudioBufferList));
        bufferList->mNumberBuffers = 1;
        bufferList->mBuffers[0].mNumberChannels = pRefObj->mInChannels;
        bufferList->mBuffers[0].mDataByteSize = (inNumberFrames << pRefObj->mInChannels);
        bufferList->mBuffers[0].mData = malloc(bufferList->mBuffers[0].mDataByteSize);


//        JYLog(@"recordingCallBack nNumberBuffers %d, mNumberChannels %d, inNumberFrames %d, mDataByteSize %d, mData %lu", bufferList->mNumberBuffers, pRefObj->mInChannels, inNumberFrames, (inNumberFrames << 1), sizeof(bufferList->mBuffers[0].mData));

        
        OSStatus status = AudioUnitRender(pRefObj->mAUState.ioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, bufferList);
        if (status != 0) {
            free(bufferList->mBuffers[0].mData);
            free(bufferList);
            JYLog(@"AudioUnitRender failed, system error %s", GetAudioOSStatusError(status));
            [pRefObj Stop];
            return 0;
        }
        if (pDS) {
            [pDS AudioDevPutData:(unsigned char *)(bufferList->mBuffers[0].mData) length:bufferList->mBuffers[0].mDataByteSize];
            AudioFileIO afio = {};
            afio.audioFormat = pRefObj->mAUState.inputDataFormat;
            afio.audioBuffer = (unsigned char *)(bufferList->mBuffers[0].mData);
            afio.audioBufferByteSize = bufferList->mBuffers[0].mDataByteSize;
            afio.audioBufferNumPacket = inNumberFrames;
            [pDS RecorderPutAudioFile:afio];
        }
        /*
         return given size buffer
         */
//        int newLen = bufferList->mBuffers[0].mDataByteSize;
//        int leftLen = pRefObj->mRBLeft;
//        int avilableLen = newLen + leftLen;
//        int offset = 0;
//        if (avilableLen >= frameLen) {
//            if (leftLen > 0) {
//                memcpy(pRefObj->pRecBuffLeft + leftLen, bufferList->mBuffers[0].mData, frameLen - leftLen);
//                if (pDS) {
//                    [pDS AudioDevPutData:pRefObj->pRecBuffLeft length:frameLen];
//                }
//                newLen -= frameLen - leftLen;
//                offset = frameLen - leftLen;
//            }
//
//            while (newLen >= frameLen) {
//                if (pDS) {
//                    [pDS AudioDevPutData:(unsigned char *)(bufferList->mBuffers[0].mData) + offset length:frameLen];
//                }
//                offset += frameLen;
//                newLen -= frameLen;
//            }
//            pRefObj->mRBLeft = newLen;
//            if (pRefObj->mRBLeft > 0) {
//                memcpy(pRefObj->pRecBuffLeft, (unsigned char *)(bufferList->mBuffers[0].mData) + offset, newLen);
//            }
//        } else {
//            memcpy(pRefObj->pRecBuffLeft + leftLen, bufferList->mBuffers[0].mData, newLen);
//            pRefObj->mRBLeft += newLen;
//        }
        /*
         add buffer to CircularBuffer
         */
//        UInt32 aviableBytes = 0;
//        TPCircularBufferHead(&pRefObj->circularBuff, &aviableBytes);
//        if (aviableBytes > 0) {
//            JYLog(@"have enough space to produce %d, %d", aviableBytes, frameLen);
//            BOOL ret = TPCircularBufferProduceBytes(&pRefObj->circularBuff, bufferList->mBuffers[0].mData, bufferList->mBuffers[0].mDataByteSize);
//            if (ret == 0) {
//                JYLog(@"no enough space");
//            }
//        }
        free(bufferList->mBuffers[0].mData);
        free(bufferList);
    }
    return 0;
}

static OSStatus
playCallBack(    void *                            inRefCon,
                        AudioUnitRenderActionFlags *    ioActionFlags,
                        const AudioTimeStamp *            inTimeStamp,
                        UInt32                            inBusNumber,
                        UInt32                            inNumberFrames,
             AudioBufferList * __nullable    ioData) {
    @autoreleasepool {
        JYAURecorder *pRefObj = (__bridge JYAURecorder *)inRefCon;
        if (pRefObj == nil) {
            JYLog(@"pRefObj is nil");
            return 0;
        }
        if (!pRefObj->mAUState.isRunning) {
            JYLog(@"pRefObj is not Running");
            return 0;
        }
        int frameLen = pRefObj->mInFrameSize;
        while (1) {
            UInt32 aviableBytes = 0;
            void *buff = TPCircularBufferTail(&pRefObj->circularBuff, &aviableBytes);
            if (aviableBytes > frameLen) {
                int offset = 0;
//                while (aviableBytes >= frameLen) {
                    JYLog(@"have buff to consume %d, %d", aviableBytes, frameLen);
                    memcpy(ioData->mBuffers[0].mData, (unsigned int *)buff + offset, frameLen);
                    TPCircularBufferConsume(&pRefObj->circularBuff, frameLen);
                    aviableBytes -= frameLen;
//                }
                JYLog(@"consume buff finished");
            } else {
                JYLog(@"no enough buff to consume");
                break;
            }
        }

    }
    return 0;
}

@implementation JYAURecorder
@synthesize workMode = mWorkMode;
@synthesize mAudioSessionLock;
@synthesize bEnableRmIO;
@synthesize audioDevErrCode;
@synthesize dataSource;

+ (id)sharedInstance {
    static JYAURecorder *recorder;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        recorder = [[JYAURecorder alloc] init];
    });
    return recorder;
}

- (id)init {
    if (self = [super init]) {
        mAUState.volumeFactor = 0;
        mAUState.isRunning = false;

        mWillWorkMode = kInvalidMode;
        mWorkMode = kInvalidMode;

        mInSamplerate = 0;
        mInChannels = 0;
        mInFrameSize = 0;

        pRecBuffLeft = NULL;
        mRBLeft = 0;

        mRecordFileName = nil;
        mRecordPCMFile = nil;

        bEnableRmIO = false;

        mAudioSessionLock = [[NSRecursiveLock alloc] init];
        mAudioPlayLock = [[NSRecursiveLock alloc] init];

        mAudioSessionQueue = dispatch_queue_create("com.jy.audiounit", NULL);

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(mediaServiceFail:)
                                                     name:AVAudioSessionMediaServicesWereLostNotification
                                                   object:[AVAudioSession sharedInstance]];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(mediaServiceReset:)
                                                     name:AVAudioSessionMediaServicesWereResetNotification
                                                   object:[AVAudioSession sharedInstance]];
    }

    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)setSampleRate:(int)samplerate Channels:(int)channels FrameSize:(int)frameSize {
    if (0 >= samplerate || 0 >= channels || 0 >= frameSize) {
        JYLog(@"argument error sampleRate %d, channels %d, frameSize %d.", mInSamplerate, mInChannels, mInFrameSize);
        return NO;
    }
    mInSamplerate = samplerate;
    mInChannels = channels;
    mInFrameSize = frameSize;
    return YES;
}
- (void)setEableRmIOFlag:(int)isUseRmIO {
    if (1 == isUseRmIO) {
        bEnableRmIO = true;
    } else {
        bEnableRmIO = false;
    }
}
- (BOOL)StartRecord {
    JYLog(@"start record");
    mWillWorkMode = kRecordMode;
    return [self StartSessionWithWorkMode:mWillWorkMode];
}
- (BOOL)StartVoip {
    JYLog(@"start voip");
    mWillWorkMode = kVoIPMode;
    return [self StartSessionWithWorkMode:mWillWorkMode];
}
- (void)Stop {
    dispatch_async(mAudioSessionQueue, ^{
        {
            {
                JYLog(@"Stop audioSession lock");
                SCOPED_LOCK(mAudioSessionLock);
                mAUState.isRunning = false;
                JYLog(@"Stop audioSession unlock");
            }
            if (mAUState.ioUnit) {
                JYLog(@"AudioOutputUnitStop begin");
                XLogIfErrorNoReturn(AudioOutputUnitStop(mAUState.ioUnit), "AudioOutputUnitStop failed");
                XLogIfErrorNoReturn(AudioUnitUninitialize(mAUState.ioUnit), "AudioUnitUninitialize failed");
                JYLog(@"AudioComponentInstanceDispose begin");
                XLogIfErrorNoReturn(AudioComponentInstanceDispose(mAUState.ioUnit), "AudioComponentInstanceDispose failed");
                mAUState.ioUnit = NULL;
            }
            if (mAUState.recordDS) {
                mAUState.recordDS = NULL;
            }
            TPCircularBufferCleanup(&circularBuff);
            if (NULL != pRecBuffLeft) {
                free(pRecBuffLeft);
                pRecBuffLeft = NULL;
            }
            mRBLeft = 0;
            
            mWorkMode = kInvalidMode;
            bEnableRmIO = NO;
//            {
//                JYLog(@"play lock");
//                SCOPED_LOCK(mAudioPlayLock);
//                if (mBufferList != NULL && mBufferList->mBuffers[0].mData != NULL) {
//                    free(mBufferList->mBuffers[0].mData);
//                    mBufferList->mBuffers[0].mData = NULL;
//                    free(mBufferList);
//                    mBufferList = NULL;
//                }
//                JYLog(@"play unlock");
//            }
        
        }
        JYLog(@"stop Record ok");
    });
}

- (BOOL)isRunning {
    return mAUState.isRunning;
}

#pragma mark - private
- (BOOL)StartSessionWithWorkMode:(AUWorkMode)workMode {
    mWorkMode = workMode;

    NSError *error;
    if ((workMode == kRecordMode || workMode == kVoIPMode) && (0 >= mInSamplerate || 0 >= mInChannels || 0 >= mInFrameSize)) {
        JYLog(@"argument error sampleRate %d, channels %d, frameSize %d.", mInSamplerate, mInChannels, mInFrameSize);
        return NO;
    }
    {
        SCOPED_LOCK(mAudioSessionLock);
        JYLog(@"StartSessionWithWorkMode audioSession lock");
        if (mAUState.isRunning) {
            JYLog(@"is working, block");
            return YES;
        } else {
            mAUState.isRunning = true;
            AudioComponentDescription desc;
            desc.componentType = kAudioUnitType_Output;
            if (mWorkMode == kRecordMode) {
                desc.componentSubType = kAudioUnitSubType_RemoteIO;
            }
            desc.componentManufacturer = kAudioUnitManufacturer_Apple;
            desc.componentFlags = 0;
            desc.componentFlagsMask = 0;
            
            AudioComponent comp = AudioComponentFindNext(NULL, &desc);
            XLogIfError(AudioComponentInstanceNew(comp, &mAUState.ioUnit), "AudioComponentInstanceNew failed");
            JYLog(@"ioUnit %x", mAUState.ioUnit);

            if (error) {
                JYLog(@"set active failed %@", [error description]);
            }

            if (error) {
                JYLog(@"set category failed %@", [error description]);
            }
            
            JYLog(@"workMode %d, samplerate %d, channels %d, framesize %d", workMode, mInSamplerate, mInChannels, mInFrameSize);
        }
        if (workMode == kRecordMode) {
            [self SetInputIOEnable:mAUState.ioUnit enabled:YES];
            [self SetInputDataFormat:mAUState.ioUnit];
            [self SetInputCallback:mAUState.ioUnit];

            [self SetOutputIOEnable:mAUState.ioUnit enabled:NO];
        } else if(workMode == kVoIPMode) {
            [self SetInputIOEnable:mAUState.ioUnit enabled:YES];
            [self SetInputDataFormat:mAUState.ioUnit];
            [self SetInputCallback:mAUState.ioUnit];
            [self SetMicroIOEnable:mAUState.ioUnit enabled:YES];
            [self SetOutputDataFormat:mAUState.ioUnit];
            [self SetOutputCallback:mAUState.ioUnit];
        }
        {
            JYLog(@"iounit set finish");
        }
        mAUState.recordDS = dataSource;
        size_t len = mInFrameSize * mInChannels;
        if (NULL == pRecBuffLeft) {
            pRecBuffLeft = (unsigned char *)malloc(len);
            if (NULL == pRecBuffLeft) {
                JYLog(@"malloc record buffer failed");
                return NO;
            } else {
                JYLog(@"mallco record buffer success %x, %x", pRecBuffLeft, pRecBuffLeft);
            }
        }
        memset(pRecBuffLeft, 0, len);
        if (workMode == kVoIPMode) {
            if(TPCircularBufferInit(&circularBuff, 4096*10) == 0) {
                    JYLog(@"init buff fail");
                    return NO;
            }
            TPCircularBufferClear(&circularBuff);
//            SCOPED_LOCK(mAudioPlayLock);
//            mBufferList = (AudioBufferList *)malloc(sizeof(AudioBufferList));
//            mBufferList->mNumberBuffers = 1;
//            mBufferList->mBuffers[0].mNumberChannels = mInChannels;
//            mBufferList->mBuffers[0].mDataByteSize = mInFrameSize;
//            mBufferList->mBuffers[0].mData = malloc(mInFrameSize);
//            JYLog(@"mBufferList %x, mBufferList.data %x", mBufferList, mBufferList->mBuffers[0].mData);
        }
        mRBLeft = 0;
        XLogIfError(AudioUnitInitialize(mAUState.ioUnit), "AudioUnitInitialize failed");
        XLogIfError(AudioOutputUnitStart(mAUState.ioUnit), "AudioOutputUnitStart failed");
        mAUState.isRunning = true;
        JYLog(@"iounit start finish");
    }
    
    return YES;
}

- (void)SetInputIOEnable:(AudioUnit)ioUnit enabled:(BOOL)enable {
    AudioUnitElement inputBus = 1;
    UInt32 flag = 1;
    if (!enable) {
        flag = 0;
    }
    XLogIfErrorNoReturn(AudioUnitSetProperty(ioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, inputBus, &flag, sizeof(flag)), "audiounit set enableio input failed");
}

- (void)SetOutputIOEnable:(AudioUnit)ioUnit enabled:(BOOL)enable {
    AudioUnitElement outputBus = 0;
    UInt32 flag = 1;
    if (!enable) {
        flag = 0;
    }
    XLogIfErrorNoReturn(AudioUnitSetProperty(ioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, outputBus, &flag, sizeof(flag)), "audiounit set enableio output failed");
}

- (void)SetMicroIOEnable:(AudioUnit)ioUnit enabled:(BOOL)enable {
    UInt32 flag = 1;
    if (!enable) {
        flag = 0;
    }
    XLogIfErrorNoReturn(AudioUnitSetProperty(ioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, kOutputBus, &flag, sizeof(flag)), "audiounit enable micro failed");
}

- (void)SetDataFormat:(AudioStreamBasicDescription &)df SampleRate:(int)sr ChannelPerFrame:(int)cpf {
    df.mFormatID = kAudioFormatLinearPCM;
    df.mSampleRate = sr;
    df.mChannelsPerFrame = cpf;
    df.mBitsPerChannel = 16;
    df.mFramesPerPacket = 1;
    df.mBytesPerPacket = df.mBytesPerFrame = cpf * sizeof(SInt16);
    df.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    df.mReserved = 0;
    JYLog(@"SetSampleRate %d, ChannelPerFrame %d, mBytesPerPacket = mBytesPerFrame %d, Flags %d", sr, cpf, df.mBytesPerPacket, (df.mFormatFlags & kAudioFormatFlagIsNonInterleaved));
}

- (void)SetInputDataFormat:(AudioUnit)ioUnit {
    [self SetDataFormat:mAUState.inputDataFormat SampleRate:mInSamplerate ChannelPerFrame:mInChannels];
    XLogIfErrorNoReturn(AudioUnitSetProperty(ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, kInputBus, &(mAUState.inputDataFormat), sizeof(AudioStreamBasicDescription)), "audiounit set record format failed");
}

- (void)SetOutputDataFormat:(AudioUnit)ioUnit {
    [self SetDataFormat:mAUState.outputDataFormat SampleRate:mInSamplerate ChannelPerFrame:mInChannels];
    XLogIfErrorNoReturn(AudioUnitSetProperty(ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, kOutputBus, &(mAUState.inputDataFormat), sizeof(mAUState.inputDataFormat)), "audiounit set mirco format failed");
}

- (void)SetInputCallback:(AudioUnit)ioUnit {
    AURenderCallbackStruct inputCallBack;
    inputCallBack.inputProc = recordingCallBack;
    inputCallBack.inputProcRefCon = (__bridge void *)self;
    XLogIfErrorNoReturn(AudioUnitSetProperty(ioUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, kInputBus, &inputCallBack, sizeof(inputCallBack)), "audiounit set record callback property failed");
}

- (void)SetOutputCallback:(AudioUnit)ioUnit {
    AURenderCallbackStruct outputCallBack;
    outputCallBack.inputProc = playCallBack;
    outputCallBack.inputProcRefCon = (__bridge void *)self;
    XLogIfErrorNoReturn(AudioUnitSetProperty(ioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, kOutputBus, &outputCallBack, sizeof(outputCallBack)), "audiounit set play callback property failed");
}

#pragma mark - Notification
- (void)mediaServiceFail:(NSNotification *)notification {
    
}

- (void)mediaServiceReset:(NSNotification *)notification {
    
}
@end
