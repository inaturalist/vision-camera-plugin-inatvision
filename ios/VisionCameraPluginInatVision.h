
#ifdef RCT_NEW_ARCH_ENABLED
#import "RNVisionCameraPluginInatVisionSpec.h"

@interface VisionCameraPluginInatVision : NSObject <NativeVisionCameraPluginInatVisionSpec>
#else
#import <React/RCTBridgeModule.h>

@interface VisionCameraPluginInatVision : NSObject <RCTBridgeModule>
#endif

@end
