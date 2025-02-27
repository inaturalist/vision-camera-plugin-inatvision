//
//  VCPPrediction.h
//  RNTestLibrary
//
//  Created by Alex Shepard on 3/13/19.
//  Copyright © 2023 iNaturalist. All rights reserved.
//

@import Foundation;

@class VCPNode;

@interface VCPPrediction : NSObject

@property VCPNode *node;
@property double score;
@property double visionScore;
@property double geoScore;
@property NSArray *ancestorIds;

- (instancetype)initWithNode:(VCPNode *)node score:(double)score visionScore:(double)visionScore geoScore:(double)geoScore;

- (NSDictionary *)asDict;

@end
