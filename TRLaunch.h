#import <UIKit/UIKit.h>

// Shared by the two places that build Twitter's launch screen: splashboardd (the
// system launch screen) and the Twitter app itself, whose own splash loads the same
// LaunchScreen nib right after and is made to look identical, so the two blend.

// Name of the launch screen nib and of the image it shows.
extern NSString* const TRLaunchNibName;
extern NSString* const TRLaunchImageName;

// The pack's launch image (the bird) at 2x, or nil if the file is missing.
UIImage* TRLaunchBackgroundImage(void);

// A nib made from the pack's LaunchScreen.nib, or nil if the file is missing.
UINib* TRLaunchReplacementNib(NSBundle* bundle);

// The pack's xLogo.png (the bird) drawn aspect-fit into the size, scale and rendering
// mode of `original`, the app's own X logo. Returns `original` if the pack file is missing.
UIImage* TRSplashLogoReplacement(UIImage* original);
