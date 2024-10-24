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
#import "VCPGeoModel.h"
#import "VCPVisionModel.h"

@interface VisionCameraPluginInatVisionPlugin : FrameProcessorPlugin

+ (VCPTaxonomy *) taxonomyWithTaxonomyFile:(NSString *)taxonomyPath;
+ (VCPGeoModel *)geoModelWithModelFile:(NSString *)geoModelPath;
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

+ (VCPGeoModel *)geoModelWithModelFile:(NSString *)modelPath {
    static VCPGeoModel *geoModel = nil;
    
    if (geoModel == nil) {
        geoModel = [[VCPGeoModel alloc] initWithModelPath:modelPath];
    }
    
    return geoModel;
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

    MLMultiArray *geoModelPreds = nil;
    if ([arguments objectForKey:@"useGeoModel"] &&
        [[arguments objectForKey:@"useGeoModel"] boolValue] &&
        [arguments objectForKey:@"latitude"] &&
        [arguments objectForKey:@"longitude"] &&
        [arguments objectForKey:@"elevation"] &&
        [arguments objectForKey:@"geoModelPath"])
    {
        VCPGeoModel *geoModel = [VisionCameraPluginInatVisionPlugin geoModelWithModelFile:arguments[@"geoModelPath"]];
        geoModelPreds = [geoModel predictionsForLat:[[arguments objectForKey:@"latitude"] floatValue]
                                                lng:[[arguments objectForKey:@"longitude"] floatValue]
                                          elevation:[[arguments objectForKey:@"elevation"] floatValue]];
    } else {
        NSLog(@"not doing anything geo related.");
    }
    
    // Log arguments
    NSLog(@"inatVision arguments: %@", arguments);
    // Destructure version out of options
    NSString* version = arguments[@"version"];
    // Destructure model path out of options
    NSString* modelPath = arguments[@"modelPath"];
    // Destructure taxonomy path out of options
    NSString* taxonomyPath = arguments[@"taxonomyPath"];
    
    CMSampleBufferRef buffer = frame.buffer;
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(buffer);
    UIImageOrientation orientation = frame.orientation;
    
    VCPVisionModel *cvModel = [VisionCameraPluginInatVisionPlugin visionModelWithModelFile:modelPath];
    MLMultiArray *visionScores = [cvModel visionPredictionsFor:pixelBuffer orientation:orientation];
    
    MLMultiArray *results = nil;
    

    if (geoModelPreds != nil) {
        NSError *err = nil;
        results = [self combineVisionScores:visionScores with:geoModelPreds error:&err];
        results = [self normalizeMultiArray:results error:&err];
    } else {
        results = visionScores;
    }

    
    // Setup taxonomy
    VCPTaxonomy *taxonomy = [VisionCameraPluginInatVisionPlugin taxonomyWithTaxonomyFile:taxonomyPath];

    NSMutableArray *topBranches = [NSMutableArray array];
    NSArray *bestBranch = [taxonomy inflateTopBranchFromClassification:results];
    // add this to the end of the recent top branches array
    [topBranches addObject:bestBranch];
    
    // convert the VCPPredictions in the bestRecentBranch into dicts
    NSMutableArray *bestBranchAsDict = [NSMutableArray array];
    for (VCPPrediction *prediction in topBranches.firstObject) {
        [bestBranchAsDict addObject:[prediction asDict]];
    }
    
    NSTimeInterval timeElapsed = [[NSDate date] timeIntervalSinceDate:startDate];
    NSLog(@"inatVision took %f seconds", timeElapsed);

    // Create a new dictionary with the bestBranchAsDict under the key "predictions"
    NSDictionary *response = [NSDictionary dictionary];
    response = @{
        @"predictions": bestBranchAsDict,
        @"timeElapsed": @(timeElapsed),
    };
    
    // End timestamp
    
    return response;
}

VISION_EXPORT_FRAME_PROCESSOR(VisionCameraPluginInatVisionPlugin, inatVision)

@end

