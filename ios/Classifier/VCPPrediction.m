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

- (instancetype)initWithNode:(VCPNode *)node score:(double)score {
    if (self = [super init]) {
        self.node = node;
        self.score = score;
        self.rank = node.rank.integerValue;
    }

    return self;
}

- (NSDictionary *)asDict {
    NSMutableDictionary *mutableNodeDict = [[self.node asDict] mutableCopy];
    mutableNodeDict[@"score"] = @(self.score);
    return [NSDictionary dictionaryWithDictionary:mutableNodeDict];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%ld - %@ - %f",
            (long)self.rank, self.node.name, self.score];
}

@end
