//
//  VCPNode.m
//  RNTestLibrary
//
//  Created by Alex Shepard on 3/13/19.
//  Copyright © 2023 iNaturalist. All rights reserved.
//

@import Foundation;

@interface VCPNode : NSObject

@property NSNumber *taxonId;
@property NSString *name;
@property NSNumber *rank;
@property NSNumber *leafId;
@property NSNumber *parentTaxonId;
// Information available in model v2.3
@property NSNumber *iconicId;
@property NSNumber *spatialId;
@property NSNumber *geoThreshold;

@property (weak) VCPNode *parent;
@property NSMutableArray <VCPNode *> *children;

- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (void)addChild:(VCPNode *)child;
- (NSDictionary *)asDict;

@end
