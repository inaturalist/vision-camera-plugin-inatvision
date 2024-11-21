@import UIKit;
@import Photos;
@import Vision;
@import CoreML;

#import "VCPTaxonomy.h"
#import "VCPPrediction.h"
#import "VCPVisionModel.h"

#import <React/RCTBridgeModule.h>

// When using the name VisionCameraPluginInatVisionModule here the plugin did not work,
// maybe there is some kind of name conflict somewhere. So I changed the name to AwesomeModule
// because it doesn't matter what the name is and it is quite awesome.
@interface AwesomeModule : NSObject <RCTBridgeModule>

+ (VCPTaxonomy *) taxonomyWithTaxonomyFile:(NSString *)taxonomyPath;
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

+ (VCPVisionModel *)visionModelWithModelFile:(NSString *)modelPath {
    static VCPVisionModel *cvModel = nil;

    if (cvModel == nil) {
        cvModel = [[VCPVisionModel alloc] initWithModelPath:modelPath];
    }

    return cvModel;
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

    // Setup threshold
    float threshold = 0.70;
    if (confidenceThreshold) {
      threshold = [confidenceThreshold floatValue];
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

          NSMutableArray *topBranches = [NSMutableArray array];
          NSArray *bestBranch = [taxonomy inflateTopBranchFromClassification:visionScores];
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

        NSMutableArray *topBranches = [NSMutableArray array];
        NSArray *bestBranch = [taxonomy inflateTopBranchFromClassification:visionScores];
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
    // Destructure location out of options
    NSDictionary* location = options[@"location"];
    NSMutableArray *sortedPredictions = [NSMutableArray array];
    NSTimeInterval timeElapsed = [[NSDate date] timeIntervalSinceDate:startDate];
    NSLog(@"getPredictionsForLocation took %f seconds", timeElapsed);
    NSDictionary *response = [NSDictionary dictionary];
    response = @{
        @"predictions": sortedPredictions,
        @"options": options,
        @"timeElapsed": @(timeElapsed),
    };

    resolve(response);
}

@end
