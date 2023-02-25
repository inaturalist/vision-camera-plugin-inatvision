
#ifdef RCT_NEW_ARCH_ENABLED
#import "RNVisionCameraPluginInatvisionSpec.h"

@interface VisionCameraPluginInatvision : NSObject <NativeVisionCameraPluginInatvisionSpec>
#else
#import <React/RCTBridgeModule.h>

@interface VisionCameraPluginInatvision : NSObject <RCTBridgeModule>
#endif

@end
