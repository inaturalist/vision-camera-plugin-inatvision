//
//  NATClassifier.m
//  RNTestLibrary
//
//  Created by Alex Shepard on 3/13/19.
//  Copyright © 2019 California Academy of Sciences. All rights reserved.
//

@import UIKit;
@import Vision;
@import CoreML;

#define NUM_RECENT_PREDICTIONS 5

#import "NATClassifier.h"
#import "NATTaxonomy.h"
#import "NATPrediction.h"

@interface NATClassifier ()
@property NSString *modelPath;
@property VNCoreMLModel *visionModel;
@property NATTaxonomy *taxonomy;
@property NSArray *requests;

@property NSMutableArray *recentTopBranches;
@property NSMutableArray *recentTopPredictions;

@end

@implementation NATClassifier

- (instancetype)initWithModelFile:(NSString *)modelPath
                      taxonmyFile:(NSString *)taxonomyPath
                         delegate:(id<NATClassifierDelegate>)delegate {
    
    if (self = [super init]) {
        self.delegate = delegate;
        self.modelPath = modelPath;
        self.taxonomy = [[NATTaxonomy alloc] initWithTaxonomyFile:taxonomyPath];
        
        // default prediction threshold
        self.threshold = 0.70;
        
        [self setupVision];
        
        self.recentTopBranches = [NSMutableArray array];
        self.recentTopPredictions = [NSMutableArray array];

    }
    
    return self;
}

- (void)stopProcessing {
    self.requests = nil;
    self.visionModel = nil;
    self.taxonomy = nil;
    self.recentTopBranches = nil;
    self.recentTopPredictions = nil;
}

- (void)dealloc {
    self.modelPath = nil;
}

- (NSArray *)bestRecentBranch {
    // find the best recent branch
    // from self.recentTopBranches
    NSArray *bestRecentBranch = nil;
    if (self.recentTopBranches.count == 0) {
        return nil;
    } else if (self.recentTopBranches.count == 1) {
        bestRecentBranch = self.recentTopBranches.firstObject;
    } else {
        // return the recent best branch with the best, most specific score
        bestRecentBranch = [self.recentTopBranches lastObject];
        // most specific score is last in each branch
        float bestRecentBranchScore = [[bestRecentBranch lastObject] score];
        for (NSArray *candidateRecentBranch in [self.recentTopBranches reverseObjectEnumerator]) {
            float candidateRecentBranchScore = [[candidateRecentBranch lastObject] score];
            if (candidateRecentBranchScore > bestRecentBranchScore) {
                bestRecentBranch = candidateRecentBranch;
                bestRecentBranchScore = candidateRecentBranchScore;
            }
        }
    }

    // convert the NATPredictions in the bestRecentBranch into dicts
    NSMutableArray *bestRecentBranchAsDict = [NSMutableArray array];
    for (NATPrediction *prediction in bestRecentBranch) {
        [bestRecentBranchAsDict addObject:[prediction asDict]];
    }
    return bestRecentBranchAsDict;
}

- (void)setupVision {
    NSURL *modelUrl = [NSURL fileURLWithPath:self.modelPath];
    if (!modelUrl) {
        [self.delegate classifierError:@"no file for optimized model"];
        return;
    }
    
    NSError *loadError = nil;
    MLModel *model = [MLModel modelWithContentsOfURL:modelUrl
                                               error:&loadError];
    if (loadError) {
        NSString *errString = [NSString stringWithFormat:@"error loading model: %@",
                               loadError.localizedDescription];
        [self.delegate classifierError:errString];
        return;
    }
    if (!model) {
        [self.delegate classifierError:@"unable to make model"];
        return;

    }
    
    NSError *modelError = nil;
    VNCoreMLModel *visionModel = [VNCoreMLModel modelForMLModel:model
                                                          error:&modelError];
    if (modelError) {
        NSString *errString = [NSString stringWithFormat:@"error making vision model: %@",
                               modelError.localizedDescription];
        [self.delegate classifierError:errString];
        return;
    }
    if (!visionModel) {
        [self.delegate classifierError:@"unable to make vision model"];
        return;
    }
    self.visionModel = visionModel;
    
    
    VNCoreMLRequest *objectRec = [[VNCoreMLRequest alloc] initWithModel:visionModel];
    
    
    VNRequestCompletionHandler handler = ^(VNRequest * _Nonnull request, NSError * _Nullable error) {
        VNCoreMLFeatureValueObservation *firstResult = request.results.firstObject;
        MLFeatureValue *firstFV = firstResult.featureValue;
        MLMultiArray *mm = firstFV.multiArrayValue;
        
        // evaluate the best branch
        NSArray *bestBranch = [self.taxonomy inflateTopBranchFromClassification:mm];
        // add this to the end of the recent top branches array
        [self.recentTopBranches addObject:bestBranch];
        // trim stuff from the beginning
        while (self.recentTopBranches.count > NUM_RECENT_PREDICTIONS) {
            [self.recentTopBranches removeObjectAtIndex:0];
        }
        
        // evaluate the top prediction
        NATPrediction *topPrediction = [self.taxonomy inflateTopPredictionFromClassification:mm
                                                                         confidenceThreshold:self.threshold];
        // add this top prediction to the recent top predictions array
        [self.recentTopPredictions addObject:topPrediction];
        // trim stuff from the beginning
        while (self.recentTopPredictions.count > NUM_RECENT_PREDICTIONS) {
            [self.recentTopPredictions removeObjectAtIndex:0];
        }
        
        // find the recent prediction with the most specific rank
        NATPrediction *bestRecentPrediction = [self.recentTopPredictions lastObject];
        for (NATPrediction *candidateRecentPrediction in [self.recentTopPredictions reverseObjectEnumerator]) {
            if (candidateRecentPrediction.rank < bestRecentPrediction.rank) {
                bestRecentPrediction = candidateRecentPrediction;
            }
        }
        
        [self.delegate topClassificationResult:[bestRecentPrediction asDict]];
    };
    
    VNCoreMLRequest *objectRecognition = [[VNCoreMLRequest alloc] initWithModel:visionModel
                                                              completionHandler:handler];
    objectRecognition.imageCropAndScaleOption = VNImageCropAndScaleOptionCenterCrop;
    self.requests = @[objectRecognition];
}

- (void)classifyFrame:(CVImageBufferRef)pixelBuf orientation:(CGImagePropertyOrientation)exifOrientation {
    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCVPixelBuffer:pixelBuf
                                                                              orientation:exifOrientation
                                                                                  options:@{}];
    NSError *requestError = nil;
    [handler performRequests:self.requests
                       error:&requestError];
    if (requestError) {
        NSString *errString = [NSString stringWithFormat:@"got a request error: %@",
                               requestError.localizedDescription];
        [self.delegate classifierError:errString];
    }
}

-(void)classifyImageData:(NSData *)data orientation:(CGImagePropertyOrientation)orientation handler:(BranchClassificationHandler)predictionCompletion {
    
    VNImageRequestHandler *imageRequestHandler = [[VNImageRequestHandler alloc] initWithData:data
                                                                                 orientation:orientation
                                                                                     options:@{}];
    
    VNRequestCompletionHandler requestHandler = ^(VNRequest * _Nonnull request, NSError * _Nullable error) {
        VNCoreMLFeatureValueObservation *firstResult = request.results.firstObject;
        MLFeatureValue *firstFV = firstResult.featureValue;
        MLMultiArray *mm = firstFV.multiArrayValue;
        NSArray *topBranch = [self.taxonomy inflateTopBranchFromClassification:mm];
        
        NSMutableArray *topBranchDicts = [NSMutableArray arrayWithCapacity:topBranch.count];
        for (NATPrediction *branch in topBranch) {
            [topBranchDicts addObject:[branch asDict]];
        }
        
        predictionCompletion(topBranchDicts, nil);
    };
    
    VNCoreMLRequest *objectRecognition = [[VNCoreMLRequest alloc] initWithModel:self.visionModel
                                                              completionHandler:requestHandler];
    objectRecognition.imageCropAndScaleOption = VNImageCropAndScaleOptionCenterCrop;
    NSError *requestError = nil;
    [imageRequestHandler performRequests:@[objectRecognition]
                                   error:&requestError];
    if (requestError) {
        predictionCompletion(nil, requestError);
    }
    NSAssert(requestError == nil, @"got a request error: %@", requestError.localizedDescription);
}

- (void)classifyImageData:(NSData *)data handler:(BranchClassificationHandler)predictionCompletion {
    
    VNImageRequestHandler *imageRequestHandler = [[VNImageRequestHandler alloc] initWithData:data
                                                                                     options:@{ }];
    
    VNRequestCompletionHandler requestHandler = ^(VNRequest * _Nonnull request, NSError * _Nullable error) {
        VNCoreMLFeatureValueObservation *firstResult = request.results.firstObject;
        MLFeatureValue *firstFV = firstResult.featureValue;
        MLMultiArray *mm = firstFV.multiArrayValue;
        NSArray *topBranch = [self.taxonomy inflateTopBranchFromClassification:mm];
        
        NSMutableArray *topBranchDicts = [NSMutableArray arrayWithCapacity:topBranch.count];
        for (NATPrediction *branch in topBranch) {
            [topBranchDicts addObject:[branch asDict]];
        }
        
        predictionCompletion(topBranchDicts, nil);
    };
    
    VNCoreMLRequest *objectRecognition = [[VNCoreMLRequest alloc] initWithModel:self.visionModel
                                                              completionHandler:requestHandler];
    objectRecognition.imageCropAndScaleOption = VNImageCropAndScaleOptionCenterCrop;
    NSError *requestError = nil;
    [imageRequestHandler performRequests:@[objectRecognition]
                                   error:&requestError];
    if (requestError) {
        predictionCompletion(nil, requestError);
    }
    NSAssert(requestError == nil, @"got a request error: %@", requestError.localizedDescription);

}

@end
