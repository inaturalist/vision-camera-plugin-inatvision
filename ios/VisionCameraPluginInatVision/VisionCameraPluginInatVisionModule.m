@import UIKit;
@import Photos;
@import Vision;
@import CoreML;

#import "VCPTaxonomy.h"
#import "VCPPrediction.h"

#import <React/RCTBridgeModule.h>

// When using the name VisionCameraPluginInatVisionModule here the plugin did not work,
// maybe there is some kind of name conflict somewhere. So I changed the name to AwesomeModule
// because it doesn't matter what the name is and it is quite awesome.
@interface AwesomeModule : NSObject <RCTBridgeModule>
+ (VCPTaxonomy*) taxonomyWithTaxonomyFile:(NSString*)taxonomyPath;
+ (VNCoreMLModel*) visionModelWithModelFile:(NSString*)modelPath;
@end

@implementation AwesomeModule
RCT_EXPORT_MODULE(VisionCameraPluginInatVision)

+ (VCPTaxonomy*) taxonomyWithTaxonomyFile:(NSString*)taxonomyPath {
  static VCPTaxonomy* taxonomy = nil;
  if (taxonomy == nil) {
    taxonomy = [[VCPTaxonomy alloc] initWithTaxonomyFile:taxonomyPath];
  }
  return taxonomy;
}

+ (VNCoreMLModel*) visionModelWithModelFile:(NSString*)modelPath {
  static VNCoreMLModel* visionModel = nil;
  if (visionModel == nil) {
    // Setup vision
    NSURL *modelUrl = [NSURL fileURLWithPath:modelPath];
    if (!modelUrl) {
      // TODO: handle this error
      // [self.delegate classifierError:@"no file for optimized model"];
      NSLog(@"no file for optimized model");
      return nil;
    }

    NSError *loadError = nil;
    MLModel *model = [MLModel modelWithContentsOfURL:modelUrl
                                                error:&loadError];
    if (loadError) {
      NSString *errString = [NSString stringWithFormat:@"error loading model: %@",
                                loadError.localizedDescription];
      NSLog(@"%@", errString);
      // TODO: handle this error
      // [self.delegate classifierError:errString];
      return nil;
    }
    if (!model) {
      // TODO: handle this error
      // [self.delegate classifierError:@"unable to make model"];
      NSLog(@"unable to make model");
      return nil;
    }

    NSError *modelError = nil;
    visionModel = [VNCoreMLModel modelForMLModel:model
                                              error:&modelError];
    if (modelError) {
        NSString *errString = [NSString stringWithFormat:@"error making vision model: %@",
                                modelError.localizedDescription];
        // [self.delegate classifierError:errString];
        NSLog(@"%@", errString);
        return nil;
    }
    if (!visionModel) {
        // [self.delegate classifierError:@"unable to make vision model"];
        NSLog(@"unable to make vision model");
        return nil;
    }
  }
  return visionModel;
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
    VNCoreMLModel *visionModel = [AwesomeModule visionModelWithModelFile:modelPath];

    NSMutableArray *topBranches = [NSMutableArray array];
    VNRequestCompletionHandler recognitionHandler = ^(VNRequest * _Nonnull request, NSError * _Nullable error) {
      VNCoreMLFeatureValueObservation *firstResult = request.results.firstObject;
      MLFeatureValue *firstFV = firstResult.featureValue;
      MLMultiArray *mm = firstFV.multiArrayValue;

      // evaluate the best branch
      NSArray *bestBranch = [taxonomy inflateTopBranchFromClassification:mm];
      // add this to the end of the recent top branches array
      [topBranches addObject:bestBranch];
    };

    VNCoreMLRequest *objectRecognition = [[VNCoreMLRequest alloc] initWithModel:visionModel
                                                              completionHandler:recognitionHandler];
    objectRecognition.imageCropAndScaleOption = VNImageCropAndScaleOptionCenterCrop;
    NSArray *requests = @[objectRecognition];

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

          VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithData:imageData options:@{}];

          NSError *requestError = nil;
          [handler performRequests:requests
                              error:&requestError];
          if (requestError) {
              NSString *errString = [NSString stringWithFormat:@"got a request error: %@",
                                      requestError.localizedDescription];
              NSLog(@"%@", errString);
              reject(@"request_error", errString, nil);
          }

          NSArray *bestRecentBranch = nil;
          if (topBranches.count == 0) {
              //resolve(@[]);
          } else if (topBranches.count == 1) {
              bestRecentBranch = topBranches.firstObject;
          }

          // convert the VCPPredictions in the bestRecentBranch into dicts
          NSMutableArray *bestRecentBranchAsDict = [NSMutableArray array];
          for (VCPPrediction *prediction in bestRecentBranch) {
              // only add predictions that are above the threshold
              if (prediction.score < threshold) {
                  continue;
              }
              [bestRecentBranchAsDict addObject:[prediction asDict]];
          }

          // Create a new dictionary with the bestRecentBranchAsDict under the key "predictions"
          // and the options passed in under the key "options"
          NSDictionary *response = [NSDictionary dictionary];
          response = @{@"predictions": bestRecentBranchAsDict, @"options": options};

          // End timestamp
          NSTimeInterval timeElapsed = [[NSDate date] timeIntervalSinceDate:startDate];
          NSLog(@"getPredictionsForImage took %f seconds", timeElapsed);

          resolve(response);
      }];
    } else {
        VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithURL:[NSURL URLWithString:uri]
                                                                                  options:@{}];
        NSError *requestError = nil;
        [handler performRequests:requests
                            error:&requestError];
        if (requestError) {
            NSString *errString = [NSString stringWithFormat:@"got a request error: %@",
                                    requestError.localizedDescription];
            NSLog(@"%@", errString);
            reject(@"request_error", errString, nil);
        }

        NSArray *bestRecentBranch = nil;
        if (topBranches.count == 0) {
            //resolve(@[]);
        } else if (topBranches.count == 1) {
            bestRecentBranch = topBranches.firstObject;
        }

        // convert the VCPPredictions in the bestRecentBranch into dicts
        NSMutableArray *bestRecentBranchAsDict = [NSMutableArray array];
        for (VCPPrediction *prediction in bestRecentBranch) {
            // only add predictions that are above the threshold
            if (prediction.score < threshold) {
                continue;
            }
            [bestRecentBranchAsDict addObject:[prediction asDict]];
        }

        // Create a new dictionary with the bestRecentBranchAsDict under the key "predictions"
        // and the options passed in under the key "options"
        NSDictionary *response = [NSDictionary dictionary];
        response = @{@"predictions": bestRecentBranchAsDict, @"options": options};

        // End timestamp
        NSTimeInterval timeElapsed = [[NSDate date] timeIntervalSinceDate:startDate];
        NSLog(@"getPredictionsForImage took %f seconds", timeElapsed);

        resolve(response);
    }
}

@end
