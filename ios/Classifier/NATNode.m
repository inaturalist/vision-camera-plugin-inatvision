//
//  NATPredictionNode.m
//  RNTestLibrary
//
//  Created by Alex Shepard on 3/13/19.
//  Copyright © 2019 California Academy of Sciences. All rights reserved.
//

#import "NATNode.h"

@interface NATNode ()

@end

@implementation NATNode

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if (self = [super init]) {
        if ([dict valueForKey:@"parent_taxon_id"] && [dict valueForKey:@"parent_taxon_id"] != [NSNull null]) {
            self.parentTaxonId = [dict valueForKey:@"parent_taxon_id"];
        }
        
        if ([dict valueForKey:@"taxon_id"] && [dict valueForKey:@"taxon_id"] != [NSNull null]) {
            self.taxonId = [dict valueForKey:@"taxon_id"];
        }
        
        if ([dict valueForKey:@"rank_level"] && [dict valueForKey:@"rank_level"] != [NSNull null]) {
            self.rank = [dict valueForKey:@"rank_level"];
        }
        
        if ([dict valueForKey:@"leaf_class_id"] && [dict valueForKey:@"leaf_class_id"] != [NSNull null]) {
            self.leafId = [dict valueForKey:@"leaf_class_id"];
        }
        
        if ([dict valueForKey:@"name"] && [dict valueForKey:@"name"] != [NSNull null]) {
            self.name = [dict valueForKey:@"name"];
        }
        
        self.children = [NSMutableArray array];
    }
    
    return self;
}

- (instancetype)init {
    if (self = [super init]) {
        self.children = [NSMutableArray array];
    }
    return self;
}

- (void)addChild:(NATNode *)child {
    [self.children addObject:child];
}

- (NSDictionary *)asDict {
    NSDictionary *dict = @{
                           @"taxon_id": self.taxonId,
                           @"rank": self.rank,
                           };
    
    NSMutableDictionary *mutableDict = [dict mutableCopy];
    if (self.leafId) {
        mutableDict[@"leaf_id"] = self.leafId;
    }
    if (self.name) {
        mutableDict[@"name"] = self.name;
    }
    
    return [NSDictionary dictionaryWithDictionary:mutableDict];
}

- (BOOL)isEqual:(id)object {
    if ([object isKindOfClass:[NATNode class]]) {
        return NO;
    }
    NATNode *otherNode = (NATNode *)object;
    return otherNode.taxonId == self.taxonId;
}

@end
