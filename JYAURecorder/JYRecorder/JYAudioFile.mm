//
//  JYAudioFile.m
//  JYAURecorder
//
//  Created by wangjy on 2021/8/20.
//

#import "JYAudioFile.h"
#import "JYAURecorder.h"
#define JYLog(log, ...) \
{   \
    NSString *__log = [[NSString alloc] initWithFormat:log, ##__VA_ARGS__, nil];  \
    NSLog(@"%s, %d::%@",  __FUNCTION__, __LINE__, __log);   \
}
#define XLogIfErrorNoReturn(error, operation)                                                    \
    do {\
        OSStatus __err = error;                                                          \
        if (__err) {                                                                     \
            NSLog(@"JYAURecorder throw %d: %s", error, operation); \
        }                                                                                \
    } while (0)

#define XLogIfError(error, operation)                                                    \
    do {                                                                                 \
        OSStatus __err = error;                                                          \
        if (__err) {                                                                     \
            NSLog(@"JYAURecorder throw %s: %s", GetAudioOSStatusError(error), operation); \
            return 0; \
        }                                                                                \
    } while (0)

@implementation JYAudioFile

- (instancetype)init
{
    self = [super init];
    if (self) {
        mAudioFile = NULL;
        mCurrentPacket = 0;
    }
    return self;
}

- (void)dealloc
{
    if (mFilePath) {
        mFilePath = nil;
    }
    
}

- (void)closeFile {
}

- (void)setDataFormat:(AudioStreamBasicDescription)dataFormat {
    mDataFormat.mFormatID = kAudioFormatLinearPCM;
    mDataFormat.mSampleRate = dataFormat.mSampleRate;
    mDataFormat.mChannelsPerFrame = dataFormat.mChannelsPerFrame;
    mDataFormat.mBitsPerChannel = 16;
    mDataFormat.mBytesPerPacket = dataFormat.mBytesPerPacket;
    mDataFormat.mBytesPerFrame = dataFormat.mBytesPerFrame;
    mDataFormat.mFramesPerPacket = dataFormat.mFramesPerPacket;
    mDataFormat.mFormatFlags = dataFormat.mFormatFlags;
    mDataFormat.mReserved = dataFormat.mReserved;
}

- (NSString *)acquireFileFullPath {
    return mFilePath;
}

- (BOOL)openByFileName:(NSString *)fileName {
    if ([fileName length] == 0) {
        JYLog(@"open filename is nil");
        return NO;
    }
    NSString *fileDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"VOIP"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (access(fileDir.UTF8String, F_OK) != 0) {
        if (fileManager) {
            NSError *error;
            [fileManager createDirectoryAtPath:fileDir withIntermediateDirectories:YES attributes:nil error:&error];
            if (error) {
                JYLog(@"create fileDir %@ error %@", fileDir, [error description]);
                return NO;
            }
            JYLog(@"create fileDir %@ success", fileDir);
        }
    }
    NSString *filePath = [[fileDir stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:@"wav"];
    if (access(filePath.UTF8String, F_OK) == 0) {
        NSError *err = nil;
        if (![fileManager removeItemAtPath:filePath error:&err]) {
            JYLog(@"remove duplicate filePath %@, error %@", filePath, [err localizedDescription]);
            return NO;
        }
        JYLog(@"remove filePath %@ success", filePath);
    }
    mFilePath = filePath;

    return [self createAudioFile_WAVE:mFilePath];
}

- (BOOL)createAudioFile_WAVE:(NSString *)path {
    const char *filePath = [path UTF8String];

    CFURLRef audioFileURL = CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8 *)filePath, strlen(filePath), false);
    JYLog(@"create audio file type %d, filePath %s", kAudioFileWAVEType, filePath);
    XLogIfError(AudioFileCreateWithURL(audioFileURL, kAudioFileWAVEType, &mDataFormat, kAudioFileFlags_EraseFile, &mAudioFile),
                "AudioFileCreateWithURL failed");
    CFRelease(audioFileURL);
    return YES;
}

- (BOOL)writeByte:(void *)data len:(UInt32)dataByteSize {
    if (!mAudioFile) {
        JYLog(@"WritePackets mAudioFile is nil");
        return NO;
    }

    UInt32 inNumPackets = dataByteSize / mDataFormat.mBytesPerPacket;
    OSStatus result = AudioFileWritePackets(mAudioFile,
                                            true, //false,
                                            dataByteSize,
                                            NULL,
                                            mCurrentPacket,
                                            &inNumPackets,
                                            data);
    if (result) {
        JYLog(@"WritePackets failed:%s", GetAudioOSStatusError(result));
        return NO;
    } else {
        JYLog(@"WritePackets packet num %d", mCurrentPacket);
        mCurrentPacket += inNumPackets;
        return YES;
    }
}

@end
