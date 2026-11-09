#import <UIKit/UIKit.h>

// Renders an SVG file with the system CoreSVG renderer, aspect-fit and centred
// inside `size` (points) at `scale`. Returns nil if CoreSVG is unavailable or the
// file cannot be parsed.
UIImage* TRImageFromSVGFile(NSString* path, CGSize size, CGFloat scale,
                            UIImageRenderingMode renderingMode);
