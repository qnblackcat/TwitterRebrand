#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <roothide.h>

#define TR_TWITTER_BUNDLE_ID @"com.atebits.Tweetie2"
#define TR_SPRINGBOARD_BUNDLE_ID @"com.apple.springboard"
#define TR_DISPLAY_NAME @"Twitter"
#define TR_RESOURCE_ROOT @"/Library/Application Support/TwitterRebrand"

#ifdef TR_DEBUG
void TRLog(NSString* format, ...) NS_FORMAT_FUNCTION(1, 2);
#else
#define TRLog(...) ((void)0)
#endif

// Absolute path of a file shipped in the package, resolved for the current
// jailbreak scheme (rootful, rootless or roothide).
NSString* TRResourcePath(NSString* relativePath);

BOOL TRIsProcess(NSString* bundleIdentifier);
