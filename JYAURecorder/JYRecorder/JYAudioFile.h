//
//  JYAudioFile.h
//  JYAURecorder
//
//  Created by wangjy on 2021/8/20.
//

#import <AudioToolbox/AudioFile.h>
#import <Foundation/Foundation.h>

@interface JYAudioFile : NSObject {
    AudioStreamBasicDescription mDataFormat;
    AudioFileID mAudioFile;
    NSString *mFilePath;
    UInt32 mCurrentPacket;
}
- (NSString *)acquireFileFullPath;
- (void)setDataFormat:(AudioStreamBasicDescription)dataFormat;
- (BOOL)openByFileName:(NSString *)fileName;
- (BOOL)writeByte:(void *)data len:(UInt32)dataByteSize;
- (void)closeFile;

@end


