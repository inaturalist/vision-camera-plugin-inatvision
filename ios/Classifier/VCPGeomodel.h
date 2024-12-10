//
//  VCPGeomodel.h
//  VisionCameraPluginInatVision
//
//  Created by Alex Shepard on 10/18/24.
//  Copyright © 2024 iNaturalist. All rights reserved.
//

#import <Foundation/Foundation.h>
@import CoreML;

NS_ASSUME_NONNULL_BEGIN

@interface VCPGeomodel : NSObject

- (instancetype _Nullable)initWithModelPath:(NSString *)modelPath;
- (MLMultiArray *)predictionsForLat:(float)latitude lng:(float)longitude elevation:(float)elevation;

@property MLModel *geomodel;
@property float locationChangeThreshold;

@end

NS_ASSUME_NONNULL_END
