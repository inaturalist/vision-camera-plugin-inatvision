//
//  VisionCameraImageLabeler.m
//  VisionCameraExample
//

#import <VisionCamera/FrameProcessorPlugin.h>
#import <VisionCamera/Frame.h>

// TODO: Objective-C Frame Processor plugin needs implementation

static inline id labelImage(Frame* frame, NSArray* arguments) {
  return nil;
}

VISION_EXPORT_FRAME_PROCESSOR(labelImage)

@end
