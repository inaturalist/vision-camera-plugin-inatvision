//
//  VCPTaxonomy.h
//  RNTestLibrary
//
//  Created by Alex Shepard on 3/13/19.
//  Copyright © 2019 California Academy of Sciences. All rights reserved.
//

@import Foundation;
@import CoreML;

@class VCPPrediction;

@interface VCPTaxonomy : NSObject

@property BOOL linneanPredictionsOnly;

- (instancetype)initWithTaxonomyFile:(NSString *)taxaFile;
- (VCPPrediction *)inflateTopPredictionFromClassification:(MLMultiArray *)classification confidenceThreshold:(float)threshold;
- (NSArray *)inflateTopBranchFromClassification:(MLMultiArray *)classification;

@end
