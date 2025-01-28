//
//  VCPPrediction.m
//  RNTestLibrary
//
//  Created by Alex Shepard on 3/13/19.
//  Copyright © 2023 iNaturalist. All rights reserved.
//

#import "VCPPrediction.h"
#import "VCPNode.h"

@implementation VCPPrediction

- (instancetype)initWithNode:(VCPNode *)node score:(double)score visionScore:(double)visionScore geoScore:(double)geoScore {
    if (self = [super init]) {
        self.node = node;
        self.score = score;
        self.visionScore = visionScore;
        self.geoScore = geoScore;
        // Walk through all parents of this node and collect their ids until we reach the life node
        NSMutableArray *ancestorIds = [NSMutableArray array];
        VCPNode *currentNode = node;
        while (currentNode.parent != nil) {
            [ancestorIds addObject:currentNode.parent.taxonId];
            currentNode = currentNode.parent;
        }
        // Reverse the array so that the life node is the first element
        self.ancestorIds = [[ancestorIds reverseObjectEnumerator] allObjects];
    }

    return self;
}

- (NSDictionary *)asDict {
    NSMutableDictionary *mutableNodeDict = [[self.node asDict] mutableCopy];
    mutableNodeDict[@"score"] = @(self.score);
    mutableNodeDict[@"vision_score"] = @(self.visionScore);
    mutableNodeDict[@"geo_score"] = (self.geoScore ? @(self.geoScore) : [NSNull null]);
    mutableNodeDict[@"ancestor_ids"] = self.ancestorIds;
    return [NSDictionary dictionaryWithDictionary:mutableNodeDict];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%ld - %@ - %f",
            (long)self.node.rank.integerValue, self.node.name, self.score];
}

@end
