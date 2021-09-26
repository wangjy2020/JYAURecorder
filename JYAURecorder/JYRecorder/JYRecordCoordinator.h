//
//  JYRecordCoordinator.h
//  JYAURecorder
//
//  Created by wangjy on 2021/9/16.
//

#import <Foundation/Foundation.h>
//#import "JYAudioEncoder.h"
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    AudioStreamBasicDescription audioFormat;
    unsigned char *audioBuffer;
    UInt32 audioBufferByteSize;
    UInt32 audioBufferNumPacket;
//    UInt32 audioBufferReadPos;
} AudioFileIO, *AudioFileIORef;

typedef NS_ENUM(NSInteger, EncodeType) {
    EncodeTypePCM,
    EncodeTypeAAC,
    EncodeTypeWAV,
    EncodeTypeMP3
};

@protocol JYRecorderAudioSource <NSObject>

- (void)JYRecorderPutData:(unsigned char *)data length:(UInt32)datalen;

@end

@interface JYRecordCoordinator : NSObject
@property (nonatomic, strong) NSString *filePath;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, strong) NSArray *inputSourceArr;
@property (nonatomic, assign) EncodeType encodeType;
@property (nonatomic, weak) id<JYRecorderAudioSource> delegate;
+ (instancetype)initWithSampleRate:(float)sampleRate Channels:(UInt32)channels FrameSize:(UInt32)frameSize BitRate:(UInt32)bitRate;
- (BOOL)startRecord;
- (void)stopRecord;
- (void)pauseRecord;
- (void)resumeRecord;
@end

NS_ASSUME_NONNULL_END
