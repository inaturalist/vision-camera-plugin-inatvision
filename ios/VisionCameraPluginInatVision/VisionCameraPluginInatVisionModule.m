@import UIKit;
@import Photos;
@import Vision;
@import CoreML;
@import Accelerate;
@import CoreGraphics;

#import "VCPTaxonomy.h"
#import "VCPPrediction.h"
#import "VCPGeomodel.h"
#import "VCPVisionModel.h"

#import <React/RCTBridgeModule.h>

// When using the name VisionCameraPluginInatVisionModule here the plugin did not work,
// maybe there is some kind of name conflict somewhere. So I changed the name to AwesomeModule
// because it doesn't matter what the name is and it is quite awesome.
@interface AwesomeModule : NSObject <RCTBridgeModule>

+ (VCPTaxonomy *) taxonomyWithTaxonomyFile:(NSString *)taxonomyPath;
+ (VCPGeomodel *)geomodelWithModelFile:(NSString *)geomodelPath;
+ (VCPVisionModel *)visionModelWithModelFile:(NSString *)modelPath;

@end

@implementation AwesomeModule
RCT_EXPORT_MODULE(VisionCameraPluginInatVision)

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

RCT_EXPORT_METHOD(getPredictionsForImage:(NSDictionary *)options
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    // Start timestamp
    NSDate *startDate = [NSDate date];

    // Log args
    NSLog(@"getPredictionsForImage options: %@", options);
    // Destructure image uri out of options
    NSString* uri = options[@"uri"];
    // Destructure version out of options
    NSString* version = options[@"version"];
    // Destructure model path out of options
    NSString* modelPath = options[@"modelPath"];
    // Destructure taxonomy path out of options
    NSString* taxonomyPath = options[@"taxonomyPath"];
    // Destructure threshold out of options
    NSNumber* confidenceThreshold = options[@"confidenceThreshold"];
    // Destructure location out of options
    NSDictionary *location = options[@"location"];
    // Destructure latitude out of location
    NSNumber *latitude = location[@"latitude"];
    // Destructure longitude out of location
    NSNumber *longitude = location[@"longitude"];
    // Destructure elevation out of location
    NSNumber *elevation = location[@"elevation"];
    // Destructure geomodel path out of options
    NSString *geomodelPath = options[@"geomodelPath"];

    // Setup threshold
    float threshold = 0.70;
    if (confidenceThreshold) {
      threshold = [confidenceThreshold floatValue];
    }

    MLMultiArray *geomodelPreds = nil;
    if ([options objectForKey:@"useGeomodel"] &&
        [[options objectForKey:@"useGeomodel"] boolValue])
    {
        VCPGeomodel *geomodel = [AwesomeModule geomodelWithModelFile:geomodelPath];
        geomodelPreds = [geomodel predictionsForLat:latitude.floatValue
                                                lng:longitude.floatValue
                                          elevation:elevation.floatValue];
    } else {
        NSLog(@"not doing anything geo related.");
    }

    // Setup taxonomy
    VCPTaxonomy *taxonomy = [AwesomeModule taxonomyWithTaxonomyFile:taxonomyPath];

    // Setup vision model
    VCPVisionModel *cvModel = [AwesomeModule visionModelWithModelFile:modelPath];

    // If uri starts with ph://, it's a photo library asset
    if ([uri hasPrefix:@"ph://"]) {
      // Convert ph:// path to local identifier
      NSString *localIdentifier = [uri stringByReplacingOccurrencesOfString:@"ph://" withString:@""];

      // Fetch the asset
      PHFetchResult<PHAsset *> *assetResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[localIdentifier] options:nil];
      PHAsset *asset = [assetResult firstObject];
      if (!asset) {
          reject(@"error", @"Asset not found", nil);
          return;
      }

      // Fetch image data
      [[PHImageManager defaultManager] requestImageDataForAsset:asset options:nil resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
          if (!imageData) {
              reject(@"error", @"Image data not found", nil);
              return;
          }

          MLMultiArray *visionScores = [cvModel visionPredictionsForImageData:imageData orientation:orientation];

          // Combine vision scores with geomodel scores
          MLMultiArray *results = nil;
          if (geomodelPreds != nil) {
              NSError *err = nil;
              results = [self combineVisionScores:visionScores with:geomodelPreds error:&err];
              results = [self normalizeMultiArray:results error:&err];
          } else {
              results = visionScores;
          }

          NSMutableArray *topBranches = [NSMutableArray array];
          NSArray *bestBranch = [taxonomy inflateTopBranchFromClassification:results];
          // add this to the end of the recent top branches array
          [topBranches addObject:bestBranch];

          // convert the VCPPredictions in the bestBranch into dicts
          NSMutableArray *bestBranchAsDict = [NSMutableArray array];
          for (VCPPrediction *prediction in bestBranch) {
              // only add predictions that are above the threshold
              if (prediction.score < threshold) {
                  continue;
              }
              [bestBranchAsDict addObject:[prediction asDict]];
          }

          // End timestamp
          NSTimeInterval timeElapsed = [[NSDate date] timeIntervalSinceDate:startDate];
          NSLog(@"getPredictionsForImage took %f seconds", timeElapsed);

          // Create a new dictionary with the bestBranchAsDict under the key "predictions"
          // and the options passed in under the key "options"
          NSDictionary *response = [NSDictionary dictionary];
          response = @{
            @"predictions": bestBranchAsDict,
            @"options": options,
            @"timeElapsed": @(timeElapsed),
          };

          resolve(response);
      }];
    } else {
        MLMultiArray *visionScores = [cvModel visionPredictionsForUrl:[NSURL URLWithString:uri]];

        // Combine vision scores with geomodel scores
        MLMultiArray *results = nil;
        if (geomodelPreds != nil) {
            NSError *err = nil;
            results = [self combineVisionScores:visionScores with:geomodelPreds error:&err];
            results = [self normalizeMultiArray:results error:&err];
        } else {
            results = visionScores;
        }

        NSMutableArray *topBranches = [NSMutableArray array];
        NSArray *bestBranch = [taxonomy inflateTopBranchFromClassification:results];
        // add this to the end of the recent top branches array
        [topBranches addObject:bestBranch];

        // convert the VCPPredictions in the bestBranch into dicts
        NSMutableArray *bestBranchAsDict = [NSMutableArray array];
        for (VCPPrediction *prediction in bestBranch) {
            // only add predictions that are above the threshold
            if (prediction.score < threshold) {
                continue;
            }
            [bestBranchAsDict addObject:[prediction asDict]];
        }

        // End timestamp
        NSTimeInterval timeElapsed = [[NSDate date] timeIntervalSinceDate:startDate];
        NSLog(@"getPredictionsForImage took %f seconds", timeElapsed);

        // Create a new dictionary with the bestBranchAsDict under the key "predictions"
        // and the options passed in under the key "options"
        NSDictionary *response = [NSDictionary dictionary];
        response = @{
            @"predictions": bestBranchAsDict,
            @"options": options,
            @"timeElapsed": @(timeElapsed),
        };

        resolve(response);
    }
}

RCT_EXPORT_METHOD(getPredictionsForLocation:(NSDictionary *)options
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    // Start timestamp
    NSDate *startDate = [NSDate date];
    // Log args
    NSLog(@"getPredictionsForLocation options: %@", options);
    // Destructure taxonomy path out of options
    NSString *taxonomyPath = options[@"taxonomyPath"];
    // Destructure geomodel path out of options
    NSString *geomodelPath = options[@"geomodelPath"];
    // Destructure location out of options
    NSDictionary* location = options[@"location"];
    // Destructure latitude out of location
    NSNumber *latitude = location[@"latitude"];
    // Destructure longitude out of location
    NSNumber *longitude = location[@"longitude"];
    // Destructure elevation out of location
    NSNumber *elevation = location[@"elevation"];

    // Setup taxonomy
    VCPTaxonomy *taxonomy = [AwesomeModule taxonomyWithTaxonomyFile:taxonomyPath];

    MLMultiArray *geomodelPreds = nil;
    VCPGeomodel *geomodel = [AwesomeModule geomodelWithModelFile:geomodelPath];
    geomodelPreds = [geomodel predictionsForLat:latitude.floatValue
                                            lng:longitude.floatValue
                                      elevation:elevation.floatValue];

    NSArray *leafScores = [taxonomy expectedNearbyFromClassification:geomodelPreds];

    // convert the VCPPredictions in the bestRecentBranch into dicts
    NSMutableArray *predictions = [NSMutableArray array];
    for (VCPPrediction *prediction in leafScores) {
        [predictions addObject:[prediction asDict]];
    }

    // Time elapsed on the native side; in seconds
    NSTimeInterval timeElapsed = [[NSDate date] timeIntervalSinceDate:startDate];
    NSLog(@"getPredictionsForLocation took %f seconds", timeElapsed);

    // Create a new dictionary with the predictions under the key "predictions"
    // and the options passed in under the key "options"
    NSDictionary *response = [NSDictionary dictionary];
    response = @{
        @"predictions": predictions,
        @"options": options,
        @"timeElapsed": @(timeElapsed),
    };

    resolve(response);
}

@end
