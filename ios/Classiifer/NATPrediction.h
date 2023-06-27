//
//  NATPrediction.h
//  RNTestLibrary
//
//  Created by Alex Shepard on 3/13/19.
//  Copyright © 2019 California Academy of Sciences. All rights reserved.
//

@import Foundation;

@class NATNode;

@interface NATPrediction : NSObject

@property NATNode *node;
@property double score;
@property NSInteger rank;

- (instancetype)initWithNode:(NATNode *)node score:(double)score;

- (NSDictionary *)asDict;

@end
