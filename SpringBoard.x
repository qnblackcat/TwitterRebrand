#import "TRCommon.h"
#import <notify.h>

// Mirrors SBIconImageInfo from SpringBoardHome (same layout on iOS 15-17).
typedef struct {
    CGSize size;
    CGFloat scale;
    CGFloat continuousCornerRadius;
} TRIconImageInfo;

@interface SBIcon : NSObject
@property (nonatomic, readonly, copy) NSString* displayName;
- (NSString*)applicationBundleID;
- (void)reloadIconImage;
+ (UIImage*)iconImageFromUnmaskedImage:(UIImage*)image info:(TRIconImageInfo)info;
@end

@interface SBLeafIcon : SBIcon
@end

@interface SBIconModel : NSObject
- (SBIcon*)applicationIconForBundleIdentifier:(NSString*)identifier;
@end

@interface SBIconController : NSObject
@property (nonatomic, retain) SBIconModel* model;
+ (instancetype)sharedInstance;
@end

@interface SBApplication : NSObject
@property (nonatomic, readonly, copy) NSString* bundleIdentifier;
@end

#pragma mark - Selected icon

// The Twitter app asks us to switch icons with a Darwin notification named
// kIconNotificationPrefix + <icon name>, because a sandboxed app cannot write to
// SpringBoard's preferences. The choice is persisted here so it survives respring.
static NSString* const kPrefsDomain = @"com.qn.twitterrebrand";
static NSString* const kIconKey = @"icon";
static NSString* const kIconNotificationPrefix = @"com.qn.twitterrebrand.icon.";
// Selection meaning "do not override": SpringBoard draws the app's real icon.
static NSString* const kNoOverride = @"none";
static NSString* const kDefaultIcon = @"ProductionAppIcon";

// File names (without .png) of the icons shipped in Icons/.
static NSSet<NSString*>* TRKnownIcons(void) {
    static NSSet* icons;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray<NSString*>* files = [[NSFileManager defaultManager]
            contentsOfDirectoryAtPath:TRResourcePath(@"Icons")
                                error:nil];
        NSMutableSet* names = [NSMutableSet setWithCapacity:files.count];
        for (NSString* file in files) {
            if ([file.pathExtension isEqualToString:@"png"]) {
                [names addObject:file.stringByDeletingPathExtension];
            }
        }
        icons = names;
    });
    return icons;
}

static NSString* gSelectedIcon;

static NSString* TRSelectedIcon(void) {
    @synchronized(kPrefsDomain) {
        if (!gSelectedIcon) {
            CFPropertyListRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)kIconKey,
                                                                (__bridge CFStringRef)kPrefsDomain);
            id saved = CFBridgingRelease(value);
            gSelectedIcon = ([saved isKindOfClass:[NSString class]] && [saved length]) ? saved : kDefaultIcon;
        }
        return gSelectedIcon;
    }
}

static NSCache<NSString*, UIImage*>* TRArtCache(void) {
    static NSCache* cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [NSCache new];
    });
    return cache;
}

static BOOL TRIsTwitterIcon(SBIcon* icon) {
    return [[icon applicationBundleID] isEqualToString:TR_TWITTER_BUNDLE_ID];
}

// The artwork (square, unmasked) of the selected icon, drawn at the size
// SpringBoard asks for; SpringBoard applies the rounded-corner mask itself.
// Returns nil when no override is selected, so the real icon is used.
static UIImage* TRHomeIconArt(TRIconImageInfo info) {
    if (info.size.width <= 0 || info.size.height <= 0 || info.scale <= 0) return nil;

    NSString* name = TRSelectedIcon();
    if (![TRKnownIcons() containsObject:name]) return nil;  // also covers kNoOverride

    NSString* key = [NSString stringWithFormat:@"%@|%.2fx%.2f@%.2f", name, info.size.width,
                                               info.size.height, info.scale];
    UIImage* art = [TRArtCache() objectForKey:key];
    if (art) return art;

    UIImage* source = [UIImage
        imageWithContentsOfFile:TRResourcePath([[@"Icons" stringByAppendingPathComponent:name]
                                    stringByAppendingPathExtension:@"png"])];
    if (!source) return nil;

    UIGraphicsImageRendererFormat* format = [UIGraphicsImageRendererFormat preferredFormat];
    format.scale = info.scale;
    format.opaque = NO;
    UIGraphicsImageRenderer* renderer = [[UIGraphicsImageRenderer alloc] initWithSize:info.size
                                                                              format:format];
    art = [renderer imageWithActions:^(UIGraphicsImageRendererContext* context) {
        [source drawInRect:CGRectMake(0, 0, info.size.width, info.size.height)];
    }];
    [TRArtCache() setObject:art forKey:key];
    TRLog(@"home icon %@ rendered", key);
    return art;
}

static void TRApplySelection(NSString* name) {
    @synchronized(kPrefsDomain) {
        gSelectedIcon = name;
    }
    CFPreferencesSetAppValue((__bridge CFStringRef)kIconKey, (__bridge CFStringRef)name,
                             (__bridge CFStringRef)kPrefsDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)kPrefsDomain);
    [TRArtCache() removeAllObjects];
    TRLog(@"selected icon: %@", name);

    // Ask SpringBoard to draw the Twitter icon again with the new selection.
    dispatch_async(dispatch_get_main_queue(), ^{
        SBIconController* controller = [%c(SBIconController) sharedInstance];
        SBIcon* icon = [controller.model applicationIconForBundleIdentifier:TR_TWITTER_BUNDLE_ID];
        [icon reloadIconImage];
    });
}

static void TRRegisterIconNotifications(void) {
    NSMutableArray<NSString*>* names = [TRKnownIcons().allObjects mutableCopy];
    [names addObject:kNoOverride];
    for (NSString* name in names) {
        NSString* notification = [kIconNotificationPrefix stringByAppendingString:name];
        int token = 0;
        // The token is kept for the life of SpringBoard on purpose.
        notify_register_dispatch(notification.UTF8String, &token, dispatch_get_main_queue(),
                                 ^(int __unused t) {
                                     TRApplySelection(name);
                                 });
    }
    TRLog(@"listening for %lu icon notifications", (unsigned long)names.count);
}

#pragma mark - Hooks

%group SpringBoardHooks

%hook SBIcon

- (NSString*)displayName {
    return TRIsTwitterIcon(self) ? TR_DISPLAY_NAME : %orig;
}

%end

%hook SBLeafIcon

- (id)displayNameForLocation:(id)location {
    return TRIsTwitterIcon(self) ? TR_DISPLAY_NAME : %orig;
}

- (id)generateIconImageWithInfo:(TRIconImageInfo)info {
    if (TRIsTwitterIcon(self)) {
        UIImage* art = TRHomeIconArt(info);
        if (art) return [%c(SBIcon) iconImageFromUnmaskedImage:art info:info];
    }
    return %orig;
}

- (id)unmaskedIconImageWithInfo:(TRIconImageInfo)info {
    if (TRIsTwitterIcon(self)) {
        UIImage* art = TRHomeIconArt(info);
        if (art) return art;
    }
    return %orig;
}

%end

// App switcher and anything else inside SpringBoard that asks the app itself.
%hook SBApplication

- (NSString*)displayName {
    return [self.bundleIdentifier isEqualToString:TR_TWITTER_BUNDLE_ID] ? TR_DISPLAY_NAME : %orig;
}

%end

%end

%ctor {
    if (TRIsProcess(TR_SPRINGBOARD_BUNDLE_ID)) {
        %init(SpringBoardHooks);
        TRRegisterIconNotifications();
    }
}
