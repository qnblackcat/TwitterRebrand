#import "TRCommon.h"
#import "TRLaunch.h"

// The system launch screen of Twitter is built by splashboardd from the app's
// LaunchScreen nib. These hooks run only in that daemon and touch only Twitter's launch
// screen; every other app goes straight to the original implementation. The Twitter app
// shows its own splash right after, built from the same nib; AppSplashHooks makes that
// one look the same so the two screens blend into each other.

@interface _UIAssetManager : NSObject
- (NSBundle*)bundle;
@end

static BOOL TRIsTwitterBundle(NSBundle* bundle) {
    return [bundle.bundleIdentifier isEqualToString:TR_TWITTER_BUNDLE_ID];
}

static UIImage* TRLaunchReplacement(UIImage* original, NSString* name, NSBundle* bundle) {
    if (TRIsTwitterBundle(bundle) && [name isEqualToString:TRLaunchImageName]) {
        return TRLaunchBackgroundImage() ?: original;
    }
    return original;
}

%group LaunchScreenHooks

%hook UINib

+ (UINib*)nibWithNibName:(NSString*)name bundle:(NSBundle*)bundle {
    if (TRIsTwitterBundle(bundle) && [name isEqualToString:TRLaunchNibName]) {
        UINib* replacement = TRLaunchReplacementNib(bundle);
        if (replacement) return replacement;
    }
    return %orig;
}

%end

%hook UIImage

+ (UIImage*)imageNamed:(NSString*)name
                   inBundle:(NSBundle*)bundle
compatibleWithTraitCollection:(UITraitCollection*)traitCollection {
    return TRLaunchReplacement(%orig, name, bundle);
}

+ (UIImage*)imageNamed:(NSString*)name
             inBundle:(NSBundle*)bundle
    withConfiguration:(UIImageConfiguration*)configuration {
    return TRLaunchReplacement(%orig, name, bundle);
}

%end

%end

%group LaunchImageHooks

// A nib stores its images as UIImageNibPlaceholder, which looks the image up by name
// in the asset manager of the nib's bundle (-[_UIAssetManager imageNamed:]); it never
// goes through +[UIImage imageNamed:inBundle:]. This is where the launch image of
// Twitter's launch screen is swapped.
%hook _UIAssetManager

- (id)imageNamed:(NSString*)name {
    id original = %orig;
    if (original && [name isEqualToString:TRLaunchImageName] && TRIsTwitterBundle([self bundle] ?: [NSBundle mainBundle])) {
        return TRLaunchBackgroundImage() ?: original;
    }
    return original;
}

%end

%end

%group AppSplashHooks

// The app's own splash loads the LaunchScreen nib with this call, not through
// +[UINib nibWithNibName:bundle:].
%hook NSBundle

- (NSArray*)loadNibNamed:(NSString*)name owner:(id)owner options:(NSDictionary*)options {
    if (TRIsTwitterBundle(self) && [name isEqualToString:TRLaunchNibName]) {
        UINib* replacement = TRLaunchReplacementNib(self);
        if (replacement) return [replacement instantiateWithOwner:owner options:options];
    }
    return %orig;
}

%end

%end

%ctor {
    BOOL inApp = TRIsProcess(TR_TWITTER_BUNDLE_ID);
    BOOL inSplashboard = [[NSProcessInfo processInfo].processName isEqualToString:@"splashboardd"];
    if (inApp || inSplashboard) %init(LaunchImageHooks);
    if (inApp) %init(AppSplashHooks);
    if (inSplashboard) {
        %init(LaunchScreenHooks);
        TRLog(@"launch screen hooks installed in splashboardd");
    }
}
