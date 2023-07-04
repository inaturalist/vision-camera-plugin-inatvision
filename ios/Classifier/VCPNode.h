//
//  VCPNode.m
//  RNTestLibrary
//
//  Created by Alex Shepard on 3/13/19.
//  Copyright © 2019 California Academy of Sciences. All rights reserved.
//

@import Foundation;

@interface VCPNode : NSObject

@property NSNumber *taxonId;
@property NSString *name;
@property NSNumber *rank;
@property NSNumber *leafId;
@property NSNumber *parentTaxonId;

@property (weak) VCPNode *parent;
@property NSMutableArray <VCPNode *> *children;

- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (void)addChild:(VCPNode *)child;
- (NSDictionary *)asDict;

@end
