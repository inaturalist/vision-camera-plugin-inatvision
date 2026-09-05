#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

@interface VisionCameraPluginInatVisionPlugin : NSObject

- (id)callback:(CVImageBufferRef *)pixelBuffer withArguments:(NSDictionary *)arguments;

@end
