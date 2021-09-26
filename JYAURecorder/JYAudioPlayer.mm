//
//  JYAudioPlayer.m
//  JYAURecorder
//
//  Created by wangjy on 2021/8/19.
//

#import "JYAudioPlayer.h"
#import <AVFoundation/AVAudioPlayer.h>
#import "JYRecorderLog.h"
@interface JYAudioPlayer () <AVAudioPlayerDelegate>
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@property (nonatomic, strong) NSMutableData *audioBuffer;
@property (nonatomic, strong) JYAURecorder *audioRecorder;
@property (nonatomic, strong) NSString *audioFilePath;
@end
static uint cnt = 0;
@implementation JYAudioPlayer
@synthesize delegate;
- (instancetype)init
{
    self = [super init];
    if (self) {
        _audioBuffer = nil;
    }
    return self;
}

- (void)startRecord {
    _audioBuffer = nil;
    if ([self.audioRecorder isRunning]) {
        [self.audioRecorder Stop];
        JYLog(@"stopRecorder before start recorder %@", _audioRecorder);
    }
    if (!_audioRecorder) {
        _audioRecorder = [JYAURecorder sharedInstance];
        JYLog(@"new recorder %@", _audioRecorder);
    }
    if(!_audioRecorder.dataSource) {
        _audioRecorder.dataSource = self;
    }
    [self.audioRecorder setSampleRate:16000 Channels:2 FrameSize:2048];
    self.audioRecorder->mRecordFileName = [NSString stringWithFormat:@"test%d", cnt++];
    JYLog(@"set record filename %@", self.audioRecorder->mRecordFileName);
    if (![self.audioRecorder StartVoip]) {
        [self stopRecord];
    };
}

- (void)stopRecord {
    if ([self.delegate respondsToSelector:@selector(OnStopRecord)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate OnStopRecord];
        });
    }
    [_audioRecorder Stop];
}

- (void)startPlay {
    NSError *error;
    if (self.audioFilePath.length > 0) {
        _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL URLWithString:self.audioFilePath] fileTypeHint:@"wav" error:&error];
        _audioPlayer.delegate = self;
        if (error) {
            JYLog(@"init AudioPlayer url error %@", [error description]);
            return;
        }
        JYLog(@"init AudioPlayer url");
    }
    if ([self.audioBuffer length] > 0) {
        if (!_audioPlayer) {
            _audioPlayer = [[AVAudioPlayer alloc] initWithData:self.audioBuffer error:&error];
            _audioPlayer.delegate = self;
            if (error) {
                JYLog(@"init AudioPlayer error %@", [error description]);
                return;
            }
            JYLog(@"init AudioPlayer");
        }
        
    }
    JYLog(@"init AudioPlayer finish %@", self.audioPlayer);
    [self.audioPlayer prepareToPlay];
        [self.audioPlayer play];
        if ([self.delegate respondsToSelector:@selector(OnStartPlay)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                JYLog(@"OnStartPlay");
                [self.delegate OnStartPlay];
            });
        }
    JYLog(@"isPlaying %d, duration %f, format %@ ", self.audioPlayer.isPlaying, self.audioPlayer.duration, self.audioPlayer.format);
}

- (int)AudioDevPutData:(unsigned char *)data length:(UInt32)datalen {
    if (data) {
        if (!_audioBuffer) {
            _audioBuffer = [NSMutableData dataWithBytes:data length:datalen];
        } else {
            [self.audioBuffer appendBytes:data length:datalen];
            if ([self.audioBuffer length] > 4096) {
                [self stopRecord];
            }
        }
        
    }
    return 1;
}
- (int)AudioDevGetData:(unsigned char *)data length:(UInt32)datalen {
    
    return 1;
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    if (player == self.audioPlayer) {
        JYLog(@"finish success %d", flag);
        
        _audioPlayer.delegate = nil;
        _audioPlayer = nil;
    }
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError * __nullable)error {
    if (player == self.audioPlayer) {
        JYLog(@"decode error %@, debug %@", [error description], [error debugDescription]);
        
        _audioPlayer.delegate = nil;
        _audioPlayer = nil;
    }
}
@end
