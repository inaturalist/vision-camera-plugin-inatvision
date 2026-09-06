#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

@interface VisionCameraPluginInatVisionPlugin : NSObject

- (id)callback:(CVPixelBufferRef)pixelBuffer withArguments:(NSDictionary *)arguments;

@end
