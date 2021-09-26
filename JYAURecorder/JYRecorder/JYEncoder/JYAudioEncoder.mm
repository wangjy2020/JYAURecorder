//
//  JYAudioEncoder.m
//  JYAURecorder
//
//  Created by wangjy on 2021/9/16.
//

#import "JYAudioEncoder.h"
//#import <AudioToolbox/AudioToolbox.h>
//#import "JYRecorderLog.h"
//#import <AudioToolbox/AudioFile.h>
@implementation JYAudioPCMEncoder
@synthesize delegate = _delegate;
- (void)encodeAudioData:(unsigned char *)audioData {
    if (self.delegate && [self.delegate respondsToSelector:@selector(encodeAudioDataFinished:)]) {
        [self.delegate encodeAudioDataFinished:audioData];
    }
}

- (BOOL)prepareEncoderWithInputFile:(AudioFileIO)inputFile outputFile:(AudioFormatIO)outputFormat {
    return NO;
}

@end


