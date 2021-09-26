//
//  JYRecorderLog.h
//
//  Created by wangjy on 2021/8/18.
//

#ifndef JYRecorderLog_h
#define JYRecorderLog_h

#define XReturnNoneIfError(error) \
    if (error) {                  \
        return;                   \
    }

#define XReturnNoIfError(error) \
    if (error) {                \
        return NO;              \
    }

#define JYLog(log, ...) \
{   \
NSString *__log = [[NSString alloc] initWithFormat:log, ##__VA_ARGS__, nil];  \
    NSLog(@"%s:%d::%@",  __FUNCTION__, __LINE__, __log);   \
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
            NSLog(@"JYAURecorder throw %d: %s", error, operation); \
            return 0; \
        }                                                                                \
    } while (0)

static bool checkErrorAndStopIfError(OSStatus error, NSString *errString) {
    if (error == noErr) {
        return NO;
    }
    NSError *err = [NSError errorWithDomain:@"JYRecorderDomin"
                                       code:error
                                   userInfo:@{ NSLocalizedDescriptionKey : errString.length > 0 ? errString : @"" }];
    JYLog(@"JYRecorderDomin throw error %@", err);
    return YES;
}



#endif /* JYRecorderLog_h */
