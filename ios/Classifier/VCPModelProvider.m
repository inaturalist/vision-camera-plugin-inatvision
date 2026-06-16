//
//  VCPModelProvider.m
//  VisionCameraPluginInatVision
//
//  Copyright © 2026 iNaturalist. All rights reserved.
//

#import "VCPModelProvider.h"

#import "VCPTaxonomy.h"
#import "VCPGeomodel.h"
#import "VCPVisionModel.h"

@implementation VCPModelProvider

+ (VCPTaxonomy *)taxonomyWithTaxonomyFile:(NSString *)taxonomyPath {
    if (taxonomyPath.length == 0) {
        return nil;
    }

    static NSMutableDictionary<NSString *, VCPTaxonomy *> *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSMutableDictionary dictionary];
    });

    VCPTaxonomy *taxonomy = cache[taxonomyPath];
    if (taxonomy == nil) {
        taxonomy = [[VCPTaxonomy alloc] initWithTaxonomyFile:taxonomyPath];
        if (taxonomy != nil) {
            cache[taxonomyPath] = taxonomy;
        }
    }

    return taxonomy;
}

+ (VCPGeomodel *)geomodelWithModelFile:(NSString *)modelPath {
    if (modelPath.length == 0) {
        return nil;
    }

    static NSMutableDictionary<NSString *, VCPGeomodel *> *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSMutableDictionary dictionary];
    });

    VCPGeomodel *geomodel = cache[modelPath];
    if (geomodel == nil) {
        geomodel = [[VCPGeomodel alloc] initWithModelPath:modelPath];
        if (geomodel != nil) {
            cache[modelPath] = geomodel;
        }
    }

    return geomodel;
}

+ (VCPVisionModel *)visionModelWithModelFile:(NSString *)modelPath {
    if (modelPath.length == 0) {
        return nil;
    }

    static NSMutableDictionary<NSString *, VCPVisionModel *> *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSMutableDictionary dictionary];
    });

    VCPVisionModel *visionModel = cache[modelPath];
    if (visionModel == nil) {
        visionModel = [[VCPVisionModel alloc] initWithModelPath:modelPath];
        if (visionModel != nil) {
            cache[modelPath] = visionModel;
        }
    }

    return visionModel;
}

@end
