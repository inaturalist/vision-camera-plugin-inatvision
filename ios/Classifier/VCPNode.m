//
//  NATPredictionNode.m
//  RNTestLibrary
//
//  Created by Alex Shepard on 3/13/19.
//  Copyright © 2023 iNaturalist. All rights reserved.
//

#import "VCPNode.h"

@interface VCPNode ()

@end

@implementation VCPNode

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

        // Information available in model v2.3
        if ([dict valueForKey:@"iconic_class_id"] && [dict valueForKey:@"iconic_class_id"] != [NSNull null]) {
            self.iconicId = [dict valueForKey:@"iconic_class_id"];
        }

        if ([dict valueForKey:@"spatial_class_id"] && [dict valueForKey:@"spatial_class_id"] != [NSNull null]) {
            self.spatialId = [dict valueForKey:@"spatial_class_id"];
        }

        // Information available when combined with geo model thesholds file,
        // as done in scripts/createTaxonomy.js
        if ([dict valueForKey:@"spatial_threshold"] && [dict valueForKey:@"spatial_threshold"] != [NSNull null]) {
            self.spatialThreshold = [dict valueForKey:@"spatial_threshold"];
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

- (void)addChild:(VCPNode *)child {
    [self.children addObject:child];
}

- (NSDictionary *)asDict {
    NSDictionary *dict = @{
                            @"taxon_id": self.taxonId,
                            @"rank_level": self.rank,
                            };

    NSMutableDictionary *mutableDict = [dict mutableCopy];
    if (self.leafId) {
        mutableDict[@"leaf_id"] = self.leafId;
    }
    if (self.name) {
        mutableDict[@"name"] = self.name;
    }
    if (self.iconicId) {
        mutableDict[@"iconic_class_id"] = self.iconicId;
    }
    if (self.spatialId) {
        mutableDict[@"spatial_class_id"] = self.spatialId;
    }
    if (self.spatialThreshold) {
        mutableDict[@"spatial_threshold"] = self.spatialThreshold;
    }

    return [NSDictionary dictionaryWithDictionary:mutableDict];
}

- (BOOL)isEqual:(id)object {
    if ([object isKindOfClass:[VCPNode class]]) {
        return NO;
    }
    VCPNode *otherNode = (VCPNode *)object;
    return otherNode.taxonId == self.taxonId;
}

@end
