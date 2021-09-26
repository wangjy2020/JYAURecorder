//
//  ViewController.m
//  JYAURecorder
//
//  Created by wangjy on 2021/8/18.
//

#import "ViewController.h"
#import "JYAudioPlayer.h"
#import <AVFoundation/AVCaptureDevice.h>
#import "JYRecordCoordinator.h"
@interface ViewController () <JYAudioPlayerState, JYRecorderAudioSource>
@property (nonatomic, strong) UIButton *button;
@property (nonatomic, strong) UIButton *stopButton;
@property (nonatomic, strong) JYAudioPlayer *audioPlayer;
@property (nonatomic, strong) JYRecordCoordinator *recordCoor;
@end

@implementation ViewController

- (instancetype)init
{
    self = [super init];
    if (self) {

    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [NSThread sleepForTimeInterval:1];
}

- (void)viewWillLayoutSubviews {
    if (!_button) {
        _button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [_button setTitle:@"开始录音" forState:UIControlStateNormal];
        [_button addTarget:self action:@selector(startRecord) forControlEvents:UIControlEventTouchUpInside];
        CGRect rect = CGRectMake(self.view.center.x, self.view.center.y, 50, 20);
        _button.frame = rect;
        [self.view addSubview:_button];
    }
    [self.button sizeToFit];
    if (!_stopButton) {
        _stopButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [_stopButton setTitle:@"停止录音" forState:UIControlStateNormal];
        [_stopButton addTarget:self action:@selector(stopRecord) forControlEvents:UIControlEventTouchUpInside];
        CGRect rect = CGRectMake(self.view.center.x, self.view.center.y + 50, 50, 20);
        _stopButton.frame = rect;
        [self.view addSubview:_stopButton];
    }
    [self.stopButton sizeToFit];
}

- (void)startRecord {
    NSLog(@"BtnClick start record");
    [self.button setTitle:@"已开始录音" forState:UIControlStateNormal];
    AVAuthorizationStatus audioAuthStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    if (audioAuthStatus == AVAuthorizationStatusNotDetermined) {  //未询问用户是否授权 //第一次询问用户是否进行授权，只会调用一次
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
            if (!granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                [self showAlertMessage:@"您已禁用了麦克风，请到设置中开启后重试~"];
                
            }); } }];
     }
     else if (audioAuthStatus == AVAuthorizationStatusAuthorized) { //麦克风已开启
         if (!_recordCoor) {
             _recordCoor = [JYRecordCoordinator initWithSampleRate:16000 Channels:2 FrameSize:2048 BitRate:48000];
             _recordCoor.encodeType = EncodeTypeAAC;
         }
         _recordCoor.delegate = self;
         [_recordCoor startRecord];
     }
     else{ //未授权
         [self showAlertMessage:@"您未开启麦克风权限，请到设置中开启后重试~"];
     }

}

- (void)stopRecord {
    NSLog(@"BtnClick stopRecord");
    [self.recordCoor stopRecord];
}

-(void)showAlertMessage:(NSString *)message{
    UIAlertController *alertView = [UIAlertController alertControllerWithTitle:@"提示" message:message preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alertView animated:YES completion:nil];
}

- (void)OnStartPlay {
    [self.button setTitle:@"已开始播放" forState:UIControlStateNormal];
}

- (void)OnStopRecord {
    [self.stopButton setTitle:@"停止录音" forState:UIControlStateNormal];
}

- (void)JYRecorderPutData:(unsigned char *)data length:(UInt32)datalen {
    NSLog(@"receive buffer data success %d", datalen);
}

@end
