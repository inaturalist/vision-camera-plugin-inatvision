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

@class VCPGeoModel;
#import "VCPVisionModel.h"

@interface VisionCameraPluginInatVisionPlugin : FrameProcessorPlugin

+ (VCPTaxonomy *) taxonomyWithTaxonomyFile:(NSString *)taxonomyPath;
+ (VCPGeoModel *)geoModelWithModelFile:(NSString *)geoModelPath;
+ (VCPVisionModel *)visionModelWithModelFile:(NSString *)modelPath;

@end

@interface VCPGeoModel: NSObject

- (instancetype)initWithModelPath:(NSString *)modelPath;
- (MLMultiArray *)predictionsForLat:(float)latitude lng:(float)longitude elevation:(float)elevation;

@property MLModel *geoModel;

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

- (MLMultiArray *)combineVisionScores:(MLMultiArray *)visionScores with:(MLMultiArray *)geoScores error:(NSError **)error {
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
                                                             dataType:MLMultiArrayDataTypeDouble
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
    double *visionData = (double *)visionScores.dataPointer;
    double *geoData = (double *)geoScores.dataPointer;
    double *combinedData = (double *)combinedArray.dataPointer;

    // Get the number of elements
    NSInteger count = visionScores.count;

    // Perform element-wise multiplication using vDSP_vmul
    vDSP_vmulD(visionData, 1, geoData, 1, combinedData, 1, count);
        
    return combinedArray;
}

- (MLMultiArray *)normalizeMultiArray:(MLMultiArray *)mlArray error:(NSError **)error {
    NSInteger count = mlArray.count;
    double *mlData = (double *)mlArray.dataPointer;
    
    double sum = 0.0;
    vDSP_sveD(mlData, 1, &sum, count);
    
    // Normalize by dividing each element by the sum
    if (sum != 0) {
        vDSP_vsdivD(mlData, 1, &sum, mlData, 1, count);
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
    if ([arguments objectForKey:@"latitude"]
        && [arguments objectForKey:@"longitude"]
        && [arguments objectForKey:@"elevation"]
        && [arguments objectForKey:@"geoModelPath"])
    {
        NSString *geoModelPath = arguments[@"geoModelPath"];
        VCPGeoModel *geoModel = [VisionCameraPluginInatVisionPlugin geoModelWithModelFile:geoModelPath];
        geoModelPreds = [geoModel predictionsForLat:[[arguments objectForKey:@"latitude"] floatValue]
                                                lng:[[arguments objectForKey:@"longitude"] floatValue]
                                          elevation:[[arguments objectForKey:@"elevation"] floatValue]];
    } else {
        NSLog(@"not doing anything geo related.");
    }
    
    NSLog(@"got %ld geo model scores", geoModelPreds.count);

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
    
    // Create a new dictionary with the bestBranchAsDict under the key "predictions"
    NSDictionary *response = [NSDictionary dictionary];
    response = @{@"predictions": bestBranchAsDict};
    
    // End timestamp
    NSTimeInterval timeElapsed = [[NSDate date] timeIntervalSinceDate:startDate];
    NSLog(@"inatVision took %f seconds", timeElapsed);
    
    return response;
}

VISION_EXPORT_FRAME_PROCESSOR(VisionCameraPluginInatVisionPlugin, inatVision)

@end




@implementation VCPGeoModel

- (instancetype _Nullable)initWithModelPath:(NSString *)modelPath {
    if (self = [super init]) {
        NSURL *geoModelUrl = [NSURL fileURLWithPath:modelPath];
        if (!geoModelUrl) {
            NSLog(@"no file for geo model");
            return nil;
        }
        
        NSError *loadError = nil;
        self.geoModel = [MLModel modelWithContentsOfURL:geoModelUrl error:&loadError];
        if (loadError) {
            NSString *errString = [NSString stringWithFormat:@"error loading model: %@",
                                   loadError.localizedDescription];
            NSLog(@"%@", errString);
            return nil;
        }
        if (!self.geoModel) {
            NSLog(@"unable to make geo model");
            return nil;
        }
    }
    
    return self;
}

- (NSArray *)normAndEncodeLat:(float)latitude lng:(float)longitude elevation:(float)elevation {
    float normLat = latitude / 90.0;
    float normLng = longitude / 180.0;
    float normElev = 0.0;
    if (elevation > 0) {
        normElev = elevation / 5705.63;
    } else {
        normElev = elevation / 32768.0;
    }
    float a = sin(M_PI * normLng);
    float b = sin(M_PI * normLat);
    float c = cos(M_PI * normLng);
    float d = cos(M_PI * normLat);
    
    return @[ @(a), @(b), @(c), @(d), @(normElev) ];
}

- (MLMultiArray *)predictionsForLat:(float)latitude lng:(float)longitude elevation:(float)elevation {
    NSArray *geoModelInputs = [self normAndEncodeLat:latitude
                                                 lng:longitude
                                           elevation:elevation];
    
    NSError *err = nil;
    MLMultiArray *mlInputs = [[MLMultiArray alloc] initWithShape:@[@1, @5]
                                                        dataType:MLMultiArrayDataTypeDouble
                                                           error:&err];
    for (int i = 0; i < 5; i++) {
        mlInputs[i] = geoModelInputs[i];
    }
    MLFeatureValue *fv = [MLFeatureValue featureValueWithMultiArray:mlInputs];
    
    NSError *fpError = nil;
    NSDictionary *fpDict = @{ @"input_1": fv };
    MLDictionaryFeatureProvider *fp = [[MLDictionaryFeatureProvider alloc] initWithDictionary:fpDict
                                                                                        error:&fpError];
    
    NSError *predError = nil;
    id <MLFeatureProvider> results = [self.geoModel predictionFromFeatures:fp error:&predError];
    MLFeatureValue *result = [results featureValueForName:@"Identity"];
    MLMultiArray *geoModelScores = result.multiArrayValue;
    
    return geoModelScores;
}

@end
