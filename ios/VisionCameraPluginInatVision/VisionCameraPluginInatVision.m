#import <Foundation/Foundation.h>
#import <VisionCamera/FrameProcessorPlugin.h>
#import <VisionCamera/FrameProcessorPluginRegistry.h>
#import <VisionCamera/Frame.h>

@import UIKit;
@import Vision;
@import CoreML;

#import "VCPTaxonomy.h"
#import "VCPPrediction.h"

@interface VisionCameraPluginInatVisionPlugin : FrameProcessorPlugin

+ (VCPTaxonomy*) taxonomyWithTaxonomyFile:(NSString*)taxonomyPath;
+ (VNCoreMLModel*) visionModelWithModelFile:(NSString*)modelPath;

@end

@implementation VisionCameraPluginInatVisionPlugin

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

- (instancetype)initWithProxy:(VisionCameraProxyHolder*)proxy
                  withOptions:(NSDictionary* _Nullable)options {
  self = [super initWithProxy:proxy withOptions:options];
  return self;
}

- (id)callback:(Frame*)frame withArguments:(NSDictionary*)arguments {
  // Start timestamp
  NSDate *startDate = [NSDate date];

  // Log arguments
  NSLog(@"inatVision arguments: %@", arguments);
  // Destructure version out of options
  NSString* version = arguments[@"version"];
  // Destructure model path out of options
  NSString* modelPath = arguments[@"modelPath"];
  // Destructure taxonomy path out of options
  NSString* taxonomyPath = arguments[@"taxonomyPath"];

  CMSampleBufferRef buffer = frame.buffer;
  UIImageOrientation orientation = frame.orientation;

  CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(buffer);
  if (!pixelBuffer) {
      NSLog(@"unable to get pixel buffer");
      return nil;
  }

  // Setup taxonomy
  VCPTaxonomy *taxonomy = [VisionCameraPluginInatVisionPlugin taxonomyWithTaxonomyFile:taxonomyPath];

  // Setup vision model
  VNCoreMLModel *visionModel = [VisionCameraPluginInatVisionPlugin visionModelWithModelFile:modelPath];

  // Setup top branches
  NSMutableArray *topBranches = [NSMutableArray array];
  VNRequestCompletionHandler recognitionHandler = ^(VNRequest * _Nonnull request, NSError * _Nullable error) {
    VNCoreMLFeatureValueObservation *firstResult = request.results.firstObject;
    MLFeatureValue *firstFV = firstResult.featureValue;
    MLMultiArray *mm = firstFV.multiArrayValue;

    NSArray *bestBranch = [taxonomy inflateTopBranchFromClassification:mm];
    // add this to the end of the recent top branches array
    [topBranches addObject:bestBranch];
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
