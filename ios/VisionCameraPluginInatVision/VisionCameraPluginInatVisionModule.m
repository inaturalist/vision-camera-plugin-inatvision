@import UIKit;
@import Photos;
@import Vision;
@import CoreML;
@import CoreGraphics;

#import "VCPTaxonomy.h"
#import "VCPPrediction.h"
#import "VCPGeomodel.h"
#import "VCPVisionModel.h"
#import "VCPMLUtils.h"

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
    // Destructure mode out of options
    NSString *mode = options[@"mode"];

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
              results = [VCPMLUtils combineVisionScores:visionScores with:geomodelPreds error:&err];
              results = [VCPMLUtils normalizeMultiArray:results error:&err];
          } else {
              results = visionScores;
          }

          [taxonomy deriveTopScoreRatioCutoff:results];

          NSMutableArray *predictions = [NSMutableArray array];
          if ([mode isEqualToString:@"COMMON_ANCESTOR"]) {
            NSArray *commonAncestor = [taxonomy inflateCommonAncestorFromClassification:results visionScores:visionScores geoScores:geomodelPreds];
            for (VCPPrediction *prediction in commonAncestor) {
              [predictions addObject:[prediction asDict]];
            }
          } else {
            NSArray *bestBranch = [taxonomy inflateTopBranchFromClassification:results visionScores:visionScores geoScores:geomodelPreds];
            for (VCPPrediction *prediction in bestBranch) {
                // convert the VCPPredictions in the bestBranch into dicts
                [predictions addObject:[prediction asDict]];
            }
          }

          // End timestamp
          NSTimeInterval timeElapsed = [[NSDate date] timeIntervalSinceDate:startDate];
          NSLog(@"getPredictionsForImage took %f seconds", timeElapsed);

          // Create a new dictionary with the predictions under the key "predictions"
          // and the options passed in under the key "options"
          NSDictionary *response = [NSDictionary dictionary];
          response = @{
            @"predictions": predictions,
            @"options": options,
            @"timeElapsed": @(timeElapsed),
          };

          resolve(response);
      }];
    } else {
        NSURL *imageURL = [NSURL URLWithString:uri];
        if (!imageURL) {
            reject(@"invalid_uri", @"Invalid image URI format", nil);
            return;
        }

        // Check if the image format is supported
        CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)imageURL, NULL);
        if (!source) {
            reject(@"invalid_image", @"Image format not supported or file not accessible", nil);
            return;
        }
        CFRelease(source);

        MLMultiArray *visionScores = [cvModel visionPredictionsForUrl:imageURL];

        // Combine vision scores with geomodel scores
        MLMultiArray *results = nil;
        if (geomodelPreds != nil) {
            NSError *err = nil;
            results = [VCPMLUtils combineVisionScores:visionScores with:geomodelPreds error:&err];
            results = [VCPMLUtils normalizeMultiArray:results error:&err];
        } else {
            results = visionScores;
        }

        [taxonomy deriveTopScoreRatioCutoff:results];

        // convert the VCPPredictions in the bestBranch into dicts
        NSMutableArray *predictions = [NSMutableArray array];

        // Only in mode "COMMON_ANCESTOR"
        if ([mode isEqualToString:@"COMMON_ANCESTOR"]) {
          NSArray *commonAncestor = [taxonomy inflateCommonAncestorFromClassification:results visionScores:visionScores geoScores:geomodelPreds];
          for (VCPPrediction *prediction in commonAncestor) {
              [predictions addObject:[prediction asDict]];
          }
        } else {
          NSArray *bestBranch = [taxonomy inflateTopBranchFromClassification:results visionScores:visionScores geoScores:geomodelPreds];
          for (VCPPrediction *prediction in bestBranch) {
              [predictions addObject:[prediction asDict]];
          }
        }

        // End timestamp
        NSTimeInterval timeElapsed = [[NSDate date] timeIntervalSinceDate:startDate];
        NSLog(@"getPredictionsForImage took %f seconds", timeElapsed);

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
