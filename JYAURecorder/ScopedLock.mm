//
//  ScopedLock.cpp
//  JYAURecorder
//
//  Created by wangjy on 2021/8/20.
//

#include "ScopedLock.h"
#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <unistd.h>

CScopedLock::CScopedLock(NSRecursiveLock *oLock, NSString *nsLockName) {
    //set lock
    m_oLock = nil;
    m_nsOldLockName = nil;

    if (oLock != nil) {
        m_oLock = oLock;
//                [m_oLock retain];

        [m_oLock lock];

        m_nsOldLockName = nsLockName;
//                [m_nsOldLockName retain];
    }
}

CScopedLock::CScopedLock(NSRecursiveLock *oLock) {
    m_oLock = nil;
    m_nsOldLockName = nil;

    if (oLock != nil) {
        m_oLock = oLock;
//                [m_oLock retain];

        [m_oLock lock];
    }
}

CScopedLock::~CScopedLock() {
    if (m_oLock != nil) {
        [m_oLock unlock];

//              [m_oLock release];
        m_oLock = nil;

        if (m_nsOldLockName != nil) {
//                        [m_nsOldLockName release];
            m_nsOldLockName = nil;
        }
    }
}
