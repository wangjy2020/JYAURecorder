//
//  JYRecordCoordinator.m
//  JYAURecorder
//
//  Created by wangjy on 2021/9/16.
//

#import "JYRecordCoordinator.h"
#import <Foundation/Foundation.h>
#import <AVFoundation/AVAudioSession.h>
#import "JYAURecorder.h"
#import "JYAudioACCEncoder.h"
#import "JYAudioWAVEncoder.h"
#import "JYAudioMP3Encoder.h"

@interface JYRecordCoordinator () <JYAudioEncoderDelegate, AUAudioDataSource> {
    TPCircularBuffer circularBuff;
}
//@property (nonatomic, strong) dispatch_queue_t processQueue;
@property (nonatomic, strong) NSOperationQueue *processQueue;
@property (nonatomic, strong) id<JYAudioEncoderProtocol> audioEncoder;
@property (nonatomic, strong) JYAURecorder *auRecorder;
@property (nonatomic, assign) UInt32 dataByteSize;
@property (nonatomic, assign) UInt32 bitRate;
@end

@implementation JYRecordCoordinator
+ (instancetype)initWithSampleRate:(float)sampleRate Channels:(UInt32)channels FrameSize:(UInt32)frameSize BitRate:(UInt32)bitRate {
    JYRecordCoordinator *coordinator = [[JYRecordCoordinator alloc] init];
    coordinator.auRecorder = [JYAURecorder sharedInstance];
    BOOL ret = [coordinator.auRecorder setSampleRate:sampleRate Channels:channels FrameSize:frameSize];
    if (ret == NO) {
        
        return nil;
    }
    coordinator.dataByteSize = frameSize << channels;
    coordinator.bitRate = bitRate;
    return coordinator;
}

- (id<JYAudioEncoderProtocol>)audioEncoder {
    if (!_audioEncoder || [_audioEncoder class] != [self EncodeClass:self.encodeType]) {
        _audioEncoder = [[[self EncodeClass:self.encodeType] alloc] init];
        _audioEncoder.delegate = self;
    }
    return _audioEncoder;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopRecord];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
//        _processQueue = dispatch_queue_create("com.jy.JYAudioProcessQueue", DISPATCH_QUEUE_SERIAL);
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRouteChange:)
                                                     name:AVAudioSessionRouteChangeNotification
                                                   object:nil];
        [self initializeProcessQueue];
        _encodeType = EncodeTypePCM;
    }
    return self;
}

- (void)initializeProcessQueue {
    _processQueue = [[NSOperationQueue alloc] init];
    _processQueue.maxConcurrentOperationCount = 1;
}

- (Class)EncodeClass:(EncodeType)encodeType {
    switch (encodeType) {
        case EncodeTypePCM:
            return [JYAudioPCMEncoder class];
        case EncodeTypeAAC:
            return [JYAudioAACEncoder class];
        case EncodeTypeWAV:
            return [JYAudioWAVEncoder class];
        case EncodeTypeMP3:
            return [JYAudioMP3Encoder class];
            break;
            
        default:
            return [JYAudioPCMEncoder class];
            break;
    }
}

- (void)prepareBuffer {
    if(TPCircularBufferInit(&circularBuff, self.dataByteSize * 2) == 0) {
        
    }
    TPCircularBufferClear(&circularBuff);
}

- (void)clearBuffer {
    TPCircularBufferCleanup(&self->circularBuff);
}

- (BOOL)startRecord {
    [self prepareBuffer];
    [self activateAudioSession];
    self.auRecorder.dataSource = self;
    [self.auRecorder StartRecord];
    return NO;
}

- (void)stopRecord {
    [self.auRecorder Stop];
    self.auRecorder.dataSource = nil;
    self.audioEncoder.delegate = nil;
    [self clearBuffer];
    [self.processQueue cancelAllOperations];
}

- (void)pauseRecord {
    [self stopRecord];
}

- (void)resumeRecord {
    [self startRecord];
}

- (void)startEncode {
    [self.processQueue addOperationWithBlock:^{
        UInt32 aviableBytes = 0;
        void *buff = TPCircularBufferTail(&self->circularBuff, &aviableBytes);
        unsigned char *audioData = (unsigned char *)calloc(self.dataByteSize, sizeof(char));
        int offset = 0;
        while (self.dataByteSize > 0 && aviableBytes > self.dataByteSize) {
            memcpy(audioData, (unsigned int *)buff + offset, self.dataByteSize);
            TPCircularBufferConsume(&self->circularBuff, self.dataByteSize);
            aviableBytes -= self.dataByteSize;
            offset += self.dataByteSize;
            [self.audioEncoder encodeAudioData:audioData];
        }

    }];
}

- (void)saveToAudioFile:(unsigned char *)audioData {
    [self.processQueue addOperationWithBlock:^{
        [self saveToAudioFile:audioData];
    }];
}

- (void)activateAudioSession {
    NSError *error;
    NSUInteger options = 0;
    options |= AVAudioSessionCategoryOptionMixWithOthers|AVAudioSessionCategoryOptionDefaultToSpeaker|AVAudioSessionCategoryOptionAllowBluetoothA2DP;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeVideoRecording options:options error:&error];
    [[AVAudioSession sharedInstance] setActive:YES error:&error];
}


#pragma mark - JYAudioEncoderDelegate
- (void)encodeAudioDataFinished:(unsigned char *)audioData {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(JYRecorderPutData:length:)]) {
            [self.delegate JYRecorderPutData:audioData length:self.dataByteSize];
        }
    });
    [self saveToAudioFile:audioData];
}

#pragma mark - AUAudioDataSource
- (int)AudioDevPutData:(unsigned char *)data length:(UInt32)datalen {
    UInt32 aviableBytes = 0;
    TPCircularBufferHead(&self->circularBuff, &aviableBytes);
    if (aviableBytes > 0) {
//        JYLog(@"have enough space to produce %d, %d", aviableBytes, frameLen);
        BOOL ret = TPCircularBufferProduceBytes(&self->circularBuff, data, aviableBytes);
        if (ret == 0) {
//            JYLog(@"no enough space");
        }
    }
    
//    [self startEncode];
    return 0;
}

- (int)RecorderPutAudioFile:(AudioFileIO)afio {
    AudioFormatIO outputFormat = {};
    outputFormat.sampleRate = afio.audioFormat.mSampleRate;
    outputFormat.channels = afio.audioFormat.mChannelsPerFrame;
    outputFormat.bitRate = self.bitRate;
    outputFormat.frameSize = afio.audioFormat.mFramesPerPacket;
    if (self.audioEncoder.delegate == nil) {
        self.audioEncoder.delegate = self;
        if (![self.audioEncoder prepareEncoderWithInputFile:afio outputFile:outputFormat]) {
            return -1;
        }
    }
    [self startEncode];
    return 0;
}


#pragma mark - AVAudioSessionRouteChangeNotification

- (void)handleRouteChange:(NSNotification *)notification {
    NSDictionary *notificationInfo = notification.userInfo;

    if ([notificationInfo isKindOfClass:[NSDictionary class]] == NO) {
        return;
    }

    NSNumber *routeChangeReasonInfo = [notificationInfo objectForKey:AVAudioSessionRouteChangeReasonKey];

    if ([routeChangeReasonInfo isKindOfClass:[NSNumber class]] == NO) {
        return;
    }

    NSUInteger reasonValue = routeChangeReasonInfo.unsignedIntegerValue;

    if (reasonValue == AVAudioSessionRouteChangeReasonNewDeviceAvailable) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self onWCAudioSessionNewDeviceAvailable];
        });

    } else if (reasonValue == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self onWCAudioSessionOldDeviceUnavailable];
        });
    }
}

- (void)onWCAudioSessionNewDeviceAvailable {
    [self setInputSourceIfNeed];
}

- (void)onWCAudioSessionOldDeviceUnavailable {
    [self setInputSourceIfNeed];
}

- (BOOL)setInputSourceIfNeed {
    if (self.inputSourceArr.count <= 0) {
        return NO;
    }
    NSArray *availableInputs = [[AVAudioSession sharedInstance] availableInputs];
    for (AVAudioSessionPortDescription *desc in availableInputs) {
        if ([self.inputSourceArr containsObject:desc.portType]) {
            NSError *error = nil;
            BOOL ret = [[AVAudioSession sharedInstance] setPreferredInput:desc error:&error];
            return ret;
        }
    }
    return NO;
}

- (BOOL)shouldForceUseBuiltinMic {
    if ([self.inputSourceArr containsObject:AVAudioSessionPortBuiltInMic]) {
        return YES;
    }
    return NO;
}
@end
