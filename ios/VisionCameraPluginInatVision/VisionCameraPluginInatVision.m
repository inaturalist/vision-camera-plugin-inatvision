#import <Foundation/Foundation.h>
#import <VisionCamera/FrameProcessorPlugin.h>
#import <VisionCamera/FrameProcessorPluginRegistry.h>
#import <VisionCamera/Frame.h>

@import UIKit;
@import Vision;
@import CoreML;
@import CoreGraphics;

#import "VCPTaxonomy.h"
#import "VCPPrediction.h"
#import "VCPGeomodel.h"
#import "VCPVisionModel.h"
#import "VCPMLUtils.h"

@interface VisionCameraPluginInatVisionPlugin : FrameProcessorPlugin

+ (VCPTaxonomy *) taxonomyWithTaxonomyFile:(NSString *)taxonomyPath;
+ (VCPGeomodel *)geomodelWithModelFile:(NSString *)geomodelPath;
+ (VCPVisionModel *)visionModelWithModelFile:(NSString *)modelPath;

@end

@implementation VisionCameraPluginInatVisionPlugin

+ (VCPTaxonomy *)taxonomyWithTaxonomyFile:(NSString *)taxonomyPath {
    static VCPTaxonomy *taxonomy = nil;
    if (taxonomy == nil) {
        taxonomy = [[VCPTaxonomy alloc] initWithTaxonomyFile:taxonomyPath];
    }
    return taxonomy;
}

+ (VCPGeomodel *)geomodelWithModelFile:(NSString *)modelPath {
    static VCPGeomodel *geomodel = nil;

    if (geomodel == nil) {
        geomodel = [[VCPGeomodel alloc] initWithModelPath:modelPath];
    }

    return geomodel;
}

+ (VCPVisionModel *)visionModelWithModelFile:(NSString *)modelPath {
    static VCPVisionModel *cvModel = nil;

    if (cvModel == nil) {
        cvModel = [[VCPVisionModel alloc] initWithModelPath:modelPath];
    }

    return cvModel;
}

- (instancetype)initWithProxy:(VisionCameraProxyHolder*)proxy
                  withOptions:(NSDictionary* _Nullable)options {
    self = [super initWithProxy:proxy withOptions:options];
    return self;
}

- (id)callback:(Frame*)frame withArguments:(NSDictionary*)arguments {
    // Start timestamp
    NSDate *startDate = [NSDate date];

    // Log arguments
    NSLog(@"inatVision arguments: %@", arguments);
    // Destructure version out of options
    NSString *version = arguments[@"version"];
    // Destructure model path out of options
    NSString *modelPath = arguments[@"modelPath"];
    // Destructure taxonomy path out of options
    NSString *taxonomyPath = arguments[@"taxonomyPath"];
    // Destructure taxonomyRollupCutoff out of options
    NSNumber *taxonomyRollupCutoff = arguments[@"taxonomyRollupCutoff"];
    // Destructure location out of options
    NSDictionary *location = arguments[@"location"];
    // Destructure latitude out of location
    NSNumber *latitude = location[@"latitude"];
    // Destructure longitude out of location
    NSNumber *longitude = location[@"longitude"];
    // Destructure elevation out of location
    NSNumber *elevation = location[@"elevation"];
    // Destructure geomodel path out of options
    NSString *geomodelPath = arguments[@"geomodelPath"];

    MLMultiArray *geomodelPreds = nil;
    if ([arguments objectForKey:@"useGeomodel"] &&
        [[arguments objectForKey:@"useGeomodel"] boolValue])
    {
        VCPGeomodel *geomodel = [VisionCameraPluginInatVisionPlugin geomodelWithModelFile:geomodelPath];
        geomodelPreds = [geomodel predictionsForLat:latitude.floatValue
                                                lng:longitude.floatValue
                                          elevation:elevation.floatValue];
    } else {
        NSLog(@"Not using geomodel for this frame.");
    }

    CMSampleBufferRef buffer = frame.buffer;
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(buffer);
    UIImageOrientation orientation = frame.orientation;

    VCPVisionModel *cvModel = [VisionCameraPluginInatVisionPlugin visionModelWithModelFile:modelPath];
    MLMultiArray *visionScores = [cvModel visionPredictionsForPixelBuffer:pixelBuffer orientation:orientation];

    MLMultiArray *results = nil;

    if (geomodelPreds != nil) {
        NSError *err = nil;
        results = [VCPMLUtils combineVisionScores:visionScores with:geomodelPreds error:&err];
        results = [VCPMLUtils normalizeMultiArray:results error:&err];
    } else {
        results = visionScores;
    }

    // Setup taxonomy
    VCPTaxonomy *taxonomy = [VisionCameraPluginInatVisionPlugin taxonomyWithTaxonomyFile:taxonomyPath];
    [taxonomy deriveTopScoreRatioCutoff:results];
    if (taxonomyRollupCutoff) {
      [taxonomy setTaxonomyRollupCutoff:taxonomyRollupCutoff.floatValue];
    }

    // convert the VCPPredictions in the bestRecentBranch into dicts
    NSMutableArray *predictions = [NSMutableArray array];
    NSArray *bestBranch = [taxonomy inflateTopBranchFromClassification:results visionScores:visionScores geoScores:geomodelPreds];
    for (VCPPrediction *prediction in bestBranch) {
        [predictions addObject:[prediction asDict]];
    }

    // End timestamp
    NSTimeInterval timeElapsed = [[NSDate date] timeIntervalSinceDate:startDate];
    NSLog(@"inatVision took %f seconds", timeElapsed);

    // Create a new dictionary with the predictions under the key "predictions"
    NSDictionary *response = [NSDictionary dictionary];
    response = @{
        @"predictions": predictions,
        @"timeElapsed": @(timeElapsed),
    };

    return response;
}

VISION_EXPORT_FRAME_PROCESSOR(VisionCameraPluginInatVisionPlugin, inatVision)

@end

