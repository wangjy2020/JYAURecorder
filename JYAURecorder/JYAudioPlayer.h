//
//  JYAudioPlayer.h
//  JYAURecorder
//
//  Created by wangjy on 2021/8/19.
//

#import <Foundation/Foundation.h>
#import "JYAURecorder.h"

NS_ASSUME_NONNULL_BEGIN

@protocol JYAudioPlayerState <NSObject>
@optional
- (void)OnStopRecord;
- (void)OnStartPlay;

@end

@interface JYAudioPlayer : NSObject <AUAudioDataSource>
@property (nonatomic, weak) id <JYAudioPlayerState> delegate;
- (void)startRecord;
- (void)stopRecord;
- (void)startPlay;
@end

NS_ASSUME_NONNULL_END
