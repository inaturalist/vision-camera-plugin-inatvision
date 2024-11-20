//
//  VCPVisionModel.h
//  VisionCameraPluginInatVision
//
//  Created by Alex Shepard on 10/18/24.
//  Copyright © 2024 iNaturalist. All rights reserved.
//

@import CoreML;
@import Vision;

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface VCPVisionModel : NSObject

- (instancetype _Nullable)initWithModelPath:(NSString *)modelPath;
- (MLMultiArray * _Nullable)visionPredictionsForPixelBuffer:(CVPixelBufferRef)pixBuf orientation:(UIImageOrientation)orient;
- (MLMultiArray * _Nullable)visionPredictionsForImageData:(NSData *)imageData orientation:(UIImageOrientation)orient;
- (MLMultiArray * _Nullable)visionPredictionsForUrl:(NSURL *)url;

@property MLModel *cvModel;
@property VNCoreMLModel *visionModel;

@property VNCoreMLRequest *classification;
@property NSArray *requests;

@end

NS_ASSUME_NONNULL_END
