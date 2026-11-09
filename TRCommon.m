#import "TRCommon.h"

NSString* TRResourcePath(NSString* relativePath) {
    NSString* path = [TR_RESOURCE_ROOT stringByAppendingPathComponent:relativePath];
    return jbroot(path);
}

BOOL TRIsProcess(NSString* bundleIdentifier) {
    return [[NSBundle mainBundle].bundleIdentifier isEqualToString:bundleIdentifier];
}

#ifdef TR_DEBUG
void TRLog(NSString* format, ...) {
    va_list args;
    va_start(args, format);
    NSString* line = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    static NSString* path;
    static NSObject* lock;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // splashboardd is sandboxed and may not write to its temp directory, but it
        // does write its own snapshot cache under SplashBoard/.
        if ([[NSProcessInfo processInfo].processName isEqualToString:@"splashboardd"]) {
            path = @"/var/mobile/Library/SplashBoard/TwitterRebrand.log";
        } else {
            path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"TwitterRebrand.log"];
        }
        lock = [NSObject new];
    });

    @synchronized(lock) {
        NSFileHandle* handle = [NSFileHandle fileHandleForWritingAtPath:path];
        if (!handle) {
            [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
            handle = [NSFileHandle fileHandleForWritingAtPath:path];
        }
        [handle seekToEndOfFile];
        NSString* full = [NSString stringWithFormat:@"[%@] %@\n",
                                                    [NSBundle mainBundle].bundleIdentifier, line];
        [handle writeData:[full dataUsingEncoding:NSUTF8StringEncoding]];
        [handle closeFile];
    }
}
#endif
