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

@property float taxonomyRollupCutoff;

- (instancetype)initWithTaxonomyFile:(NSString *)taxaFile;
- (NSArray *)expectedNearbyFromClassification:(MLMultiArray *)classification;
- (void)deriveTopScoreRatioCutoff:(MLMultiArray *)classification;
- (NSArray *)inflateTopBranchFromClassification:(MLMultiArray *)classification;
- (NSArray *)inflateCommonAncestorFromClassification:(MLMultiArray *)classification;

@end
