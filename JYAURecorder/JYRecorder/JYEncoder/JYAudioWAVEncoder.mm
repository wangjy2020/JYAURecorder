//
//  JYAudioWAVEncoder.m
//  JYAURecorder
//
//  Created by wangjy on 2021/9/23.
//

#import "JYAudioWAVEncoder.h"


@implementation JYAudioWAVEncoder
@synthesize delegate = _delegate;
- (void)encodeAudioData:(unsigned char *)audioData {
    
}

- (BOOL)prepareEncoderWithInputFile:(AudioFileIO)inputFile outputFile:(AudioFormatIO)outputFormat {
    return NO;
}
@end
