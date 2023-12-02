#ifdef RCT_NEW_ARCH_ENABLED
#import "RNAwesomeModuleSpec.h"

@interface AwesomeModule : NSObject <NativeAwesomeModuleSpec>
#else
#import <React/RCTBridgeModule.h>

@interface AwesomeModule : NSObject <RCTBridgeModule>
#endif
@end
