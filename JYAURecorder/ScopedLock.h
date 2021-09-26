//
//  ScopedLock.hpp
//  JYAURecorder
//
//  Created by wangjy on 2021/8/20.
//

#pragma once

#ifdef __cplusplus

#import <Foundation/Foundation.h>

class CScopedLock {
public:
    CScopedLock(NSRecursiveLock *oLock);
    CScopedLock(NSRecursiveLock *oLock, NSString *nsLockName);
    ~CScopedLock();

private:
    NSRecursiveLock *m_oLock;
    NSString *m_nsOldLockName;
};

#define SCOPED_LOCK(lock) _SCOPEDLOCK(lock, __COUNTER__)
#define _SCOPEDLOCK(lock, counter) __SCOPEDLOCK(lock, counter)
#define __SCOPEDLOCK(lock, counter) CScopedLock __scopedLock##counter(lock)

#endif
