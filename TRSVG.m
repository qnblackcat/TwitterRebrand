#import "TRSVG.h"
#import "TRCommon.h"
#import <dlfcn.h>

// CoreSVG is a private framework, so its few entry points are resolved at
// runtime instead of linking against it.
typedef const void* TRSVGDocumentRef;

static TRSVGDocumentRef (*SVGDocumentCreateFromData)(CFDataRef data, CFDictionaryRef options);
static CGSize (*SVGDocumentGetCanvasSize)(TRSVGDocumentRef document);
static void (*SVGContextDrawDocument)(CGContextRef context, TRSVGDocumentRef document);

static BOOL TRLoadCoreSVG(void) {
    static BOOL available = NO;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void* handle = dlopen("/System/Library/PrivateFrameworks/CoreSVG.framework/CoreSVG",
                              RTLD_LAZY);
        if (!handle) return;
        SVGDocumentCreateFromData = dlsym(handle, "CGSVGDocumentCreateFromData");
        SVGDocumentGetCanvasSize = dlsym(handle, "CGSVGDocumentGetCanvasSize");
        SVGContextDrawDocument = dlsym(handle, "CGContextDrawSVGDocument");
        available = SVGDocumentCreateFromData && SVGDocumentGetCanvasSize &&
                    SVGContextDrawDocument;
    });
    return available;
}

// Parsed documents are kept for the life of the process: the pack is a few
// hundred small files and every glyph is requested many times.
static TRSVGDocumentRef TRDocumentForPath(NSString* path) {
    static NSMutableDictionary<NSString*, NSValue*>* documents;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        documents = [NSMutableDictionary dictionary];
    });

    @synchronized(documents) {
        NSValue* cached = documents[path];
        if (cached) return cached.pointerValue;

        TRSVGDocumentRef document = NULL;
        NSData* data = [NSData dataWithContentsOfFile:path];
        if (data) document = SVGDocumentCreateFromData((__bridge CFDataRef)data, NULL);
        // A failed parse is cached as NULL so it is not retried on every lookup.
        documents[path] = [NSValue valueWithPointer:document];
        return document;
    }
}

UIImage* TRImageFromSVGFile(NSString* path, CGSize size, CGFloat scale,
                            UIImageRenderingMode renderingMode) {
    if (size.width <= 0 || size.height <= 0 || scale <= 0) return nil;
    if (!TRLoadCoreSVG()) return nil;

    TRSVGDocumentRef document = TRDocumentForPath(path);
    if (!document) return nil;

    CGSize canvas = SVGDocumentGetCanvasSize(document);
    if (canvas.width <= 0 || canvas.height <= 0) return nil;

    UIGraphicsImageRendererFormat* format = [UIGraphicsImageRendererFormat preferredFormat];
    format.scale = scale;
    format.opaque = NO;
    UIGraphicsImageRenderer* renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size
                                                                              format:format];
    UIImage* image = [renderer imageWithActions:^(UIGraphicsImageRendererContext* rendererContext) {
        CGContextRef context = rendererContext.CGContext;
        CGFloat fit = MIN(size.width / canvas.width, size.height / canvas.height);
        CGFloat width = canvas.width * fit;
        CGFloat height = canvas.height * fit;

        // CoreSVG expects a bottom-left origin, UIKit's renderer is top-left.
        CGContextTranslateCTM(context, (size.width - width) / 2,
                              (size.height - height) / 2 + height);
        CGContextScaleCTM(context, fit, -fit);
        SVGContextDrawDocument(context, document);
    }];
    return [image imageWithRenderingMode:renderingMode];
}
