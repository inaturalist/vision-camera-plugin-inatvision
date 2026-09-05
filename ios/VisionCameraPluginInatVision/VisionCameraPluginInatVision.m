#import "VisionCameraPluginInatVisionPlugin.h"

@import UIKit;
@import Vision;
@import CoreML;
@import CoreGraphics;

#import "VCPTaxonomy.h"
#import "VCPPrediction.h"
#import "VCPGeomodel.h"
#import "VCPVisionModel.h"
#import "VCPMLUtils.h"
#import "VCPModelProvider.h"

@implementation VisionCameraPluginInatVisionPlugin

- (id)callback:(CVImageBufferRef*)pixelBuffer withArguments:(NSDictionary*)arguments {
    // Start timestamp
    NSDate *startDate = [NSDate date];

#ifdef DEBUG
    NSLog(@"inatVision arguments: %@", arguments);
#endif
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
        VCPGeomodel *geomodel = [VCPModelProvider geomodelWithModelFile:geomodelPath];
        geomodelPreds = [geomodel predictionsForLat:latitude.floatValue
                                                lng:longitude.floatValue
                                          elevation:elevation.floatValue];
    } else {
#ifdef DEBUG
        NSLog(@"Not using geomodel for this frame.");
#endif
    }

    UIImageOrientation orientation = UIImageOrientationUp;

    VCPVisionModel *cvModel = [VCPModelProvider visionModelWithModelFile:modelPath];
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
    VCPTaxonomy *taxonomy = [VCPModelProvider taxonomyWithTaxonomyFile:taxonomyPath];
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
#ifdef DEBUG
    NSLog(@"inatVision took %f seconds", timeElapsed);
#endif

    // Create a new dictionary with the predictions under the key "predictions"
    NSDictionary *response = [NSDictionary dictionary];
    response = @{
        @"predictions": predictions,
        @"timeElapsed": @(timeElapsed),
    };

    return response;
}

@end

