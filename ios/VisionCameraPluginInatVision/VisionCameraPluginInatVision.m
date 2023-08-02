#import <VisionCamera/FrameProcessorPlugin.h>
#import <VisionCamera/Frame.h>

@import UIKit;
@import Vision;
@import CoreML;

#import "VCPTaxonomy.h"
#import "VCPPrediction.h"

@interface VisionCameraPluginInatVisionPlugin : NSObject

+ (VCPTaxonomy*) taxonomyWithTaxonomyFile:(NSString*)taxonomyPath;

@end

@implementation VisionCameraPluginInatVisionPlugin

+ (VCPTaxonomy*) taxonomyWithTaxonomyFile:(NSString*)taxonomyPath {
  static VCPTaxonomy* taxonomy = nil;
  if (taxonomy == nil) {
    taxonomy = [[VCPTaxonomy alloc] initWithTaxonomyFile:taxonomyPath];
  }
  return taxonomy;
}

static inline id inatVision(Frame* frame, NSArray* args) {
  // Log args
  NSLog(@"inatVision args: %@", args);
  // First arg is the options dict
  NSDictionary* options = args[0];
  // Destructure version out of options
  NSString* version = options[@"version"];
  // Destructure model path out of options
  NSString* modelPath = options[@"modelPath"];
  // Destructure taxonomy path out of options
  NSString* taxonomyPath = options[@"taxonomyPath"];
  // Destructure threshold out of options
  NSString* confidenceThreshold = options[@"confidenceThreshold"];

  CMSampleBufferRef buffer = frame.buffer;
  UIImageOrientation orientation = frame.orientation;

  CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(buffer);
  if (!pixelBuffer) {
      NSLog(@"unable to get pixel buffer");
      return nil;
  }

  int NUM_RECENT_PREDICTIONS = 5;

  // Setup taxonomy
  VCPTaxonomy *taxonomy = [VisionCameraPluginInatVisionPlugin taxonomyWithTaxonomyFile:taxonomyPath];

  // Setup threshold
  float threshold = 0.70;
  if (confidenceThreshold) {
    threshold = [confidenceThreshold floatValue];
  }

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
  VNCoreMLModel *visionModel = [VNCoreMLModel modelForMLModel:model
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

  VNCoreMLRequest *objectRec = [[VNCoreMLRequest alloc] initWithModel:visionModel];
  NSLog(@" made objectRec");

  NSMutableArray *recentTopBranches = [NSMutableArray array];
  VNRequestCompletionHandler recognitionHandler = ^(VNRequest * _Nonnull request, NSError * _Nullable error) {
    VNCoreMLFeatureValueObservation *firstResult = request.results.firstObject;
    MLFeatureValue *firstFV = firstResult.featureValue;
    MLMultiArray *mm = firstFV.multiArrayValue;

    // evaluate the best branch
    NSArray *bestBranch = [taxonomy inflateTopBranchFromClassification:mm];
    // add this to the end of the recent top branches array
    [recentTopBranches addObject:bestBranch];
    // trim stuff from the beginning
    while (recentTopBranches.count > NUM_RECENT_PREDICTIONS) {
        [recentTopBranches removeObjectAtIndex:0];
    }
  };

  VNCoreMLRequest *objectRecognition = [[VNCoreMLRequest alloc] initWithModel:visionModel
                                                            completionHandler:recognitionHandler];
  objectRecognition.imageCropAndScaleOption = VNImageCropAndScaleOptionCenterCrop;
  NSArray *requests = @[objectRecognition];

  VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCVPixelBuffer:pixelBuffer
                                                                            orientation:orientation
                                                                                options:@{}];
  NSError *requestError = nil;
  [handler performRequests:requests
                      error:&requestError];
  if (requestError) {
      NSString *errString = [NSString stringWithFormat:@"got a request error: %@",
                              requestError.localizedDescription];
      NSLog(@"%@", errString);
      return nil;
  }

  NSArray *bestRecentBranch = nil;
  if (recentTopBranches.count == 0) {
      return nil;
  } else if (recentTopBranches.count == 1) {
      bestRecentBranch = recentTopBranches.firstObject;
  } else {
      // return the recent best branch with the best, most specific score
      bestRecentBranch = [recentTopBranches lastObject];
      // most specific score is last in each branch
      float bestRecentBranchScore = [[bestRecentBranch lastObject] score];
      for (NSArray *candidateRecentBranch in [recentTopBranches reverseObjectEnumerator]) {
          float candidateRecentBranchScore = [[candidateRecentBranch lastObject] score];
          if (candidateRecentBranchScore > bestRecentBranchScore) {
              bestRecentBranch = candidateRecentBranch;
              bestRecentBranchScore = candidateRecentBranchScore;
          }
      }
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
  return bestRecentBranchAsDict;
}

VISION_EXPORT_FRAME_PROCESSOR(inatVision)

@end
