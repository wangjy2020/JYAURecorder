//
//  JYAURecorder.h
//  JYAURecorder
//
//  Created by wangjy on 2021/8/18.
//
#import <AudioToolbox/AudioUnit.h>
#import <UIKit/UIKit.h>
#import "TPCircularBuffer.h"
#import "JYRecordCoordinator.h"

extern const char * GetAudioOSStatusError(OSStatus error);
NS_ASSUME_NONNULL_BEGIN
@protocol AUAudioDataSource <NSObject>

@optional
- (BOOL)isGetDataReady;

@required
- (int)AudioDevPutData:(unsigned char *)data length:(UInt32)datalen;
- (int)RecorderPutAudioFile:(AudioFileIO)afio;
@end
#define kInputBus 1
#define kOutputBus 0

#if __has_feature(objc_arc)
#define JYWeak __weak
#else
#define JYWeak
#endif

typedef struct {
    AudioUnit ioUnit;

    AudioStreamBasicDescription inputDataFormat;
    AudioStreamBasicDescription outputDataFormat;
    JYWeak id<AUAudioDataSource> recordDS;

    unsigned int volumeFactor;

    bool isRunning;
} AUState;

typedef enum { kInvalidMode = 0x00, kRecordMode = 0x01, kVoIPMode = 0x02} AUWorkMode;

@class JYAudioFile;

@interface JYAURecorder : NSObject {
    @public
    AUState mAUState;
    AUWorkMode mWillWorkMode;
    AUWorkMode mWorkMode;
        
    int mInSamplerate;
    int mInChannels;
    int mInFrameSize;
    
    TPCircularBuffer circularBuff;
    unsigned char *pRecBuffLeft;
    int mRBLeft;
    
    NSString *mRecordFileName;
    JYAudioFile *mRecordPCMFile;
    
    NSRecursiveLock *mAudioPlayLock;
    NSRecursiveLock *mAudioSessionLock;
    dispatch_queue_t mAudioSessionQueue;
    AudioBufferList *mBufferList;
}

@property (nonatomic, weak) id<AUAudioDataSource> dataSource;
@property (nonatomic, assign) AUWorkMode workMode;
@property (nonatomic, assign) SInt32 audioDevErrCode;
@property (nonatomic, assign) bool bEnableRmIO;
+ (id)sharedInstance;
- (id)init NS_UNAVAILABLE;
- (BOOL)setSampleRate:(int)samplerate Channels:(int)channels FrameSize:(int)frameSize;
- (BOOL)StartRecord;
- (BOOL)StartVoip;
- (void)Stop;
- (BOOL)isRunning;
@end


@interface JYAURecorder ()
@property (nonatomic, strong) NSRecursiveLock *mAudioSessionLock;

@end
NS_ASSUME_NONNULL_END
