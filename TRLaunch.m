#import "TRLaunch.h"
#import "TRCommon.h"

NSString* const TRLaunchNibName = @"LaunchScreen";
NSString* const TRLaunchImageName = @"LaunchStoryboardBackgroundImage";

// The pack's nib shows its image at 136x111 pt, i.e. the 272x222 px PNG at 2x.
UIImage* TRLaunchBackgroundImage(void) {
    static UIImage* image;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSData* data = [NSData dataWithContentsOfFile:TRResourcePath(@"Launch/LaunchStoryboardBackgroundImage.png")];
        if (data) image = [UIImage imageWithData:data scale:2];
        TRLog(@"launch image %@", image ? @"loaded" : @"MISSING");
    });
    return image;
}

UINib* TRLaunchReplacementNib(NSBundle* bundle) {
    NSData* data = [NSData dataWithContentsOfFile:TRResourcePath(@"Launch/LaunchScreen.nib")];
    TRLog(@"launch nib %@", data ? @"replaced" : @"MISSING, using original");
    return data ? [UINib nibWithData:data bundle:bundle] : nil;
}

// The app's own splash and a few other screens draw the X logo from the main catalog
// under the name xLogo; the pack has a bird for it.
UIImage* TRSplashLogoReplacement(UIImage* original) {
    CGSize size = original.size;
    if (size.width <= 0 || size.height <= 0) return original;

    static NSCache<NSString*, UIImage*>* cache;
    static UIImage* source;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [NSCache new];
        source = [UIImage imageWithContentsOfFile:TRResourcePath(@"Icons/xLogo.png")];
    });
    if (!source) return original;

    NSString* key = [NSString stringWithFormat:@"%@|%.2f|%ld", NSStringFromCGSize(size),
                                               original.scale, (long)original.renderingMode];
    UIImage* replacement = [cache objectForKey:key];
    if (!replacement) {
        UIGraphicsImageRendererFormat* format = [UIGraphicsImageRendererFormat preferredFormat];
        format.scale = original.scale;
        format.opaque = NO;
        UIGraphicsImageRenderer* renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size
                                                                                  format:format];
        CGFloat fit = MIN(size.width / source.size.width, size.height / source.size.height);
        CGSize drawn = CGSizeMake(source.size.width * fit, source.size.height * fit);
        UIImage* drawing = [renderer imageWithActions:^(UIGraphicsImageRendererContext* context) {
            [source drawInRect:CGRectMake((size.width - drawn.width) / 2,
                                          (size.height - drawn.height) / 2, drawn.width, drawn.height)];
        }];
        replacement = [drawing imageWithRenderingMode:original.renderingMode];
        [cache setObject:replacement forKey:key];
    }
    return replacement;
}
