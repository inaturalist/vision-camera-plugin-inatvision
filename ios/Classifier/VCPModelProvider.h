//
//  VCPModelProvider.h
//  VisionCameraPluginInatVision
//
//  Copyright © 2026 iNaturalist. All rights reserved.
//

#import <Foundation/Foundation.h>

@class VCPTaxonomy;
@class VCPGeomodel;
@class VCPVisionModel;

NS_ASSUME_NONNULL_BEGIN

@interface VCPModelProvider : NSObject

+ (VCPTaxonomy *) taxonomyWithTaxonomyFile:(NSString *)taxonomyPath;
+ (VCPGeomodel *)geomodelWithModelFile:(NSString *)modelPath;
+ (VCPVisionModel *)visionModelWithModelFile:(NSString *)modelPath;

@end

NS_ASSUME_NONNULL_END
