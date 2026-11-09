#import "TRCommon.h"
#import "TRSVG.h"
#import "TRLaunch.h"

// glyph name (file name without .svg) -> absolute path of the replacement SVG.
static NSDictionary<NSString*, NSString*>* TRGlyphTable(void) {
    static NSDictionary* table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString* directory = TRResourcePath(@"Glyphs");
        NSArray<NSString*>* files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory
                                                                                         error:nil];
        NSMutableDictionary* result = [NSMutableDictionary dictionaryWithCapacity:files.count];
        for (NSString* file in files) {
            if (![file.pathExtension isEqualToString:@"svg"]) continue;
            result[file.stringByDeletingPathExtension] = [directory stringByAppendingPathComponent:file];
        }
        table = result;
        TRLog(@"glyph table: %lu glyphs from %@", (unsigned long)table.count, directory);
    });
    return table;
}

// The X logo of the app's main catalog; a few screens draw it under this name.
static NSString* const kSplashLogoName = @"xLogo";

// Images looked up in the app's own bundle (not a resource bundle).
static UIImage* TRReplacementForMainBundleImage(UIImage* original, NSString* name) {
    if (!original || name.length == 0) return original;
    if ([name isEqualToString:kSplashLogoName]) return TRSplashLogoReplacement(original);
    return original;
}

static UIImage* TRReplacementForImage(UIImage* original, NSString* name, NSBundle* bundle) {
    if (!original || name.length == 0) return original;
    if (!bundle || bundle == [NSBundle mainBundle] ||
        [bundle.bundlePath isEqualToString:[NSBundle mainBundle].bundlePath]) {
        return TRReplacementForMainBundleImage(original, name);
    }

    NSString* bundleName = bundle.bundlePath.lastPathComponent;
    // Twitter's vector glyphs live in the XIconsAssets resource bundle.
    if ([bundleName rangeOfString:@"XIconsAssets"].location == NSNotFound) return original;

    NSString* glyph = [name.pathExtension isEqualToString:@"svg"] ? name.stringByDeletingPathExtension : name;
    NSString* path = TRGlyphTable()[glyph];
    if (!path) return original;

    static NSCache<NSString*, UIImage*>* cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [NSCache new];
    });

    NSString* key = [NSString stringWithFormat:@"%@|%@|%.2f|%ld", glyph, NSStringFromCGSize(original.size),
                                               original.scale, (long)original.renderingMode];
    UIImage* replacement = [cache objectForKey:key];
    if (!replacement) {
        replacement = TRImageFromSVGFile(path, original.size, original.scale, original.renderingMode);
        if (!replacement) return original;
        if (original.flipsForRightToLeftLayoutDirection) {
            replacement = [replacement imageFlippedForRightToLeftLayoutDirection];
        }
        if (!UIEdgeInsetsEqualToEdgeInsets(original.alignmentRectInsets, UIEdgeInsetsZero)) {
            replacement = [replacement imageWithAlignmentRectInsets:original.alignmentRectInsets];
        }
        [cache setObject:replacement forKey:key];
    }
    return replacement;
}

%group AppHooks

%hook UIImage

+ (UIImage*)imageNamed:(NSString*)name {
    return TRReplacementForMainBundleImage(%orig, name);
}

+ (UIImage*)imageNamed:(NSString*)name compatibleWithTraitCollection:(UITraitCollection*)traitCollection {
    return TRReplacementForMainBundleImage(%orig, name);
}

+ (UIImage*)imageNamed:(NSString*)name
                   inBundle:(NSBundle*)bundle
compatibleWithTraitCollection:(UITraitCollection*)traitCollection {
    return TRReplacementForImage(%orig, name, bundle);
}

+ (UIImage*)imageNamed:(NSString*)name
             inBundle:(NSBundle*)bundle
    withConfiguration:(UIImageConfiguration*)configuration {
    return TRReplacementForImage(%orig, name, bundle);
}

%end

%end

%ctor {
    if (TRIsProcess(TR_TWITTER_BUNDLE_ID)) {
        %init(AppHooks);
    }
}
