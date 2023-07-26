#import <VisionCamera/FrameProcessorPlugin.h>
#import <VisionCamera/Frame.h>

@import UIKit;
@import Vision;
@import CoreML;

#import "VCPTaxonomy.h"
#import "VCPPrediction.h"

@interface VisionCameraPluginInatVisionPlugin : NSObject
@end

@implementation VisionCameraPluginInatVisionPlugin

static inline id inatVision(Frame* frame, NSArray* args) {
  // Log args
  NSLog(@"inatVision args: %@", args);
  // First arg is model path
  NSString* modelPath = args[0];
  // Second arg is taxonomy path
  NSString* taxonomyPath = args[1];
  // Third arg is threshold
  NSString* thresholdArg = args[2];
  CMSampleBufferRef buffer = frame.buffer;
  UIImageOrientation orientation = frame.orientation;

  CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(buffer);
  if (!pixelBuffer) {
      NSLog(@"unable to get pixel buffer");
      return nil;
  }

  int NUM_RECENT_PREDICTIONS = 5;
  NSMutableArray *recentTopPredictions = [NSMutableArray array];

  // Setup taxonomy
  VCPTaxonomy *taxonomy = [[VCPTaxonomy alloc] initWithTaxonomyFile:taxonomyPath];

  // Setup threshold
  float threshold = 0.70;
  if (thresholdArg) {
    threshold = [thresholdArg floatValue];
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

  VNRequestCompletionHandler recognitionHandler = ^(VNRequest * _Nonnull request, NSError * _Nullable error) {
    VNCoreMLFeatureValueObservation *firstResult = request.results.firstObject;
    MLFeatureValue *firstFV = firstResult.featureValue;
    MLMultiArray *mm = firstFV.multiArrayValue;

    // evaluate the best branch
    NSArray *bestBranch = [taxonomy inflateTopBranchFromClassification:mm];

    // evaluate the top prediction
    VCPPrediction *topPrediction = [taxonomy inflateTopPredictionFromClassification:mm
                                                                      confidenceThreshold:threshold];

    // add this top prediction to the recent top predictions array
    [recentTopPredictions addObject:topPrediction];
    // trim stuff from the beginning
    while (recentTopPredictions.count > NUM_RECENT_PREDICTIONS) {
        [recentTopPredictions removeObjectAtIndex:0];
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

  // find the recent prediction with the most specific rank
  VCPPrediction *bestRecentPrediction = [recentTopPredictions lastObject];
  for (VCPPrediction *candidateRecentPrediction in [recentTopPredictions reverseObjectEnumerator]) {
      if (candidateRecentPrediction.rank < bestRecentPrediction.rank) {
          bestRecentPrediction = candidateRecentPrediction;
      }
  }
  NSDictionary *topPredictionDict = [bestRecentPrediction asDict];
  NSLog(@"topPredictionDict: %@", topPredictionDict);
  return @[topPredictionDict];

}

VISION_EXPORT_FRAME_PROCESSOR(inatVision)

@end
