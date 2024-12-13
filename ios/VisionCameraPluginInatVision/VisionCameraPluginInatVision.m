#import <Foundation/Foundation.h>
#import <VisionCamera/FrameProcessorPlugin.h>
#import <VisionCamera/FrameProcessorPluginRegistry.h>
#import <VisionCamera/Frame.h>

@import UIKit;
@import Vision;
@import CoreML;
@import Accelerate;
@import CoreGraphics;

#import "VCPTaxonomy.h"
#import "VCPPrediction.h"
#import "VCPGeomodel.h"
#import "VCPVisionModel.h"

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

- (MLMultiArray * _Nullable)combineVisionScores:(MLMultiArray *)visionScores with:(MLMultiArray *)geoScores error:(NSError **)error {
    // Ensure both arrays have the same shape
    if (![visionScores.shape isEqualToArray:geoScores.shape]) {
        NSDictionary *userInfo = @{
            NSLocalizedDescriptionKey: @"Arrays must have the same shape",
        };
        *error = [NSError errorWithDomain:@"MLMultiArrayErrorDomain"
                                     code:1
                                 userInfo:userInfo];
        return nil;
    }

    // Create a result MLMultiArray with the same shape as the input arrays
    MLMultiArray *combinedArray = [[MLMultiArray alloc] initWithShape:visionScores.shape
                                                             dataType:MLMultiArrayDataTypeFloat32
                                                                error:error];
    if (!combinedArray) {
        NSDictionary *userInfo = @{
            NSLocalizedDescriptionKey: @"Failed to make combined array",
        };
        *error = [NSError errorWithDomain:@"MLMultiArrayErrorDomain"
                                     code:2
                                 userInfo:userInfo];
        return nil;
    }

    // Get the data pointers
    float *visionData = (float *)visionScores.dataPointer;
    float *geoData = (float *)geoScores.dataPointer;
    float *combinedData = (float *)combinedArray.dataPointer;

    // Get the number of elements
    NSInteger count = visionScores.count;

    // Perform element-wise multiplication using vDSP_vmul
    vDSP_vmul(visionData, 1, geoData, 1, combinedData, 1, count);

    return combinedArray;
}

- (MLMultiArray *)normalizeMultiArray:(MLMultiArray *)mlArray error:(NSError **)error {
    NSInteger count = mlArray.count;
    float *mlData = (float *)mlArray.dataPointer;

    float sum = 0.0;
    vDSP_sve(mlData, 1, &sum, count);

    if (sum != 0) {
        vDSP_vsdiv(mlData, 1, &sum, mlData, 1, count);
    } else {
        NSDictionary *userInfo = @{
            NSLocalizedDescriptionKey: @"Sum of elements is zero, normalization not possible."
        };
        *error = [NSError errorWithDomain:@"MLMultiArrayErrorDomain"
                                     code:3
                                 userInfo:userInfo];
        return nil;
    }

    return mlArray;
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
        NSLog(@"not doing anything geo related.");
    }

    CMSampleBufferRef buffer = frame.buffer;
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(buffer);
    UIImageOrientation orientation = frame.orientation;

    VCPVisionModel *cvModel = [VisionCameraPluginInatVisionPlugin visionModelWithModelFile:modelPath];
    MLMultiArray *visionScores = [cvModel visionPredictionsForPixelBuffer:pixelBuffer orientation:orientation];

    MLMultiArray *results = nil;

    if (geomodelPreds != nil) {
        NSError *err = nil;
        results = [self combineVisionScores:visionScores with:geomodelPreds error:&err];
        results = [self normalizeMultiArray:results error:&err];
    } else {
        results = visionScores;
    }

    // Get a pointer to the raw data
    float *dataPointer = (float *)results.dataPointer;
    NSUInteger count = results.count;
    // Use vDSP to find the maximum value
    float topCombinedScore;
    vDSP_maxv(dataPointer, 1, &topCombinedScore, count);
    // define some cutoff based on a percentage of the top combined score. Taxa with
    // scores below the cutoff will be ignored when aggregating scores up the taxonomy
    float scoreRatioCutoff = 0.001;
    float cutoff = topCombinedScore * scoreRatioCutoff;

    // Setup taxonomy
    VCPTaxonomy *taxonomy = [VisionCameraPluginInatVisionPlugin taxonomyWithTaxonomyFile:taxonomyPath];
    [taxonomy setTaxonomyRollupCutoff:cutoff];
    if (taxonomyRollupCutoff) {
      [taxonomy setTaxonomyRollupCutoff:taxonomyRollupCutoff.floatValue];
    }

    NSMutableArray *topBranches = [NSMutableArray array];
    NSArray *bestBranch = [taxonomy inflateTopBranchFromClassification:results];
    // add this to the end of the recent top branches array
    [topBranches addObject:bestBranch];

    // convert the VCPPredictions in the bestRecentBranch into dicts
    NSMutableArray *bestBranchAsDict = [NSMutableArray array];
    for (VCPPrediction *prediction in topBranches.firstObject) {
        [bestBranchAsDict addObject:[prediction asDict]];
    }

    // End timestamp
    NSTimeInterval timeElapsed = [[NSDate date] timeIntervalSinceDate:startDate];
    NSLog(@"inatVision took %f seconds", timeElapsed);

    // Create a new dictionary with the bestBranchAsDict under the key "predictions"
    NSDictionary *response = [NSDictionary dictionary];
    response = @{
        @"predictions": bestBranchAsDict,
        @"timeElapsed": @(timeElapsed),
    };

    return response;
}

VISION_EXPORT_FRAME_PROCESSOR(VisionCameraPluginInatVisionPlugin, inatVision)

@end

