#import <VisionCamera/FrameProcessorPlugin.h>
#import <VisionCamera/Frame.h>

@interface VisionCameraPluginInatVisionPlugin : NSObject
@end

@implementation VisionCameraPluginInatVisionPlugin

static inline id inatVision(Frame* frame, NSArray* args) {
  // Log args
  NSLog(@"inatVision args: %@", args);
  CMSampleBufferRef buffer = frame.buffer;
  UIImageOrientation orientation = frame.orientation;
  // code goes here
  return @[];
}

VISION_EXPORT_FRAME_PROCESSOR(inatVision)

@end
