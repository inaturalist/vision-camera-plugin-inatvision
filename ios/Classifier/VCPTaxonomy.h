//
//  VCPTaxonomy.h
//  RNTestLibrary
//
//  Created by Alex Shepard on 3/13/19.
//  Copyright © 2023 iNaturalist. All rights reserved.
//

@import Foundation;
@import CoreML;

@class VCPPrediction;

@interface VCPTaxonomy : NSObject

@property BOOL linneanPredictionsOnly;

- (instancetype)initWithTaxonomyFile:(NSString *)taxaFile;
- (VCPPrediction *)inflateTopPredictionFromClassification:(MLMultiArray *)classification confidenceThreshold:(float)threshold;
- (NSArray *)inflateTopBranchFromClassification:(MLMultiArray *)classification;
- (void)setTaxonomyRollupCutoff:(float)taxonomyRollupCutoff;

@end
