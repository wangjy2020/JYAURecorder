//
//  JYAudioEncoder.h
//  JYAURecorder
//
//  Created by wangjy on 2021/9/16.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioFile.h>
#import "JYRecordCoordinator.h"
NS_ASSUME_NONNULL_BEGIN

typedef struct {
    float sampleRate;
    UInt32 channels;
    UInt32 frameSize;
    UInt32 bitRate;
} AudioFormatIO, *AudioFormatIORef;

@protocol JYAudioEncoderDelegate <NSObject>

- (void)encodeAudioDataFinished:(unsigned char *)audioData;

@end

@protocol JYAudioEncoderProtocol <NSObject>
@property (nonatomic, weak) id<JYAudioEncoderDelegate> delegate;
- (BOOL)prepareEncoderWithInputFile:(AudioFileIO)inputFile outputFile:(AudioFormatIO)outputFormat;
- (void)encodeAudioData:(unsigned char *)audioData;

@end

@interface JYAudioPCMEncoder : NSObject <JYAudioEncoderProtocol>

@end

NS_ASSUME_NONNULL_END
