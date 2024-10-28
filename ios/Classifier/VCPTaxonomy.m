//
//  VCPTaxonomy.m
//  RNTestLibrary
//
//  Created by Alex Shepard on 3/13/19.
//  Copyright © 2023 iNaturalist. All rights reserved.
//

#import "VCPTaxonomy.h"
#import "VCPNode.h"
#import "VCPPrediction.h"

@interface VCPTaxonomy ()
@property NSArray *nodes;
@property NSDictionary *nodesByTaxonId;
// this is a convenience array for testing
@property NSArray *leaves;
@property VCPNode *life;
@property float taxonomyRollupCutoff;
@end

@implementation VCPTaxonomy

- (instancetype)initWithTaxonomyFile:(NSString *)taxaFile {
    if (self = [super init]) {
        NSAssert(taxaFile, @"taxa file required");

        NSFileManager *fm = [NSFileManager defaultManager];
        NSAssert([fm fileExistsAtPath:taxaFile], @"taxa file %@ does exist.", taxaFile);
        NSAssert([fm isReadableFileAtPath:taxaFile], @"taxa file %@ not readable", taxaFile);

        NSError *readError = nil;
        NSData *taxonomyData = [NSData dataWithContentsOfFile:taxaFile
                                                      options:0
                                                        error:&readError];
        NSAssert(readError == nil, @"error reading from %@: %@", taxaFile, readError.localizedDescription);
        NSAssert(taxonomyData, @"failed to get data from %@", taxaFile);

        NSError *jsonError = nil;
        NSArray *taxa = [NSJSONSerialization JSONObjectWithData:taxonomyData
                                                        options:0
                                                          error:&jsonError];
        NSAssert(jsonError == nil, @"error getting json from %@: %@", taxaFile, jsonError.localizedDescription);
        NSAssert(taxa, @"failed to get json from %@", taxaFile);
        NSAssert(taxa.count > 0, @"failed to get list of json from %@", taxaFile);

        self.linneanPredictionsOnly = YES;

        self.life =  [[VCPNode alloc] init];
        self.life.taxonId = @(48460);
        self.life.rank = @(100);
        self.life.name = @"Life";

        // extract nodes from taxa json object
        NSMutableArray *allNodes = [NSMutableArray arrayWithCapacity:taxa.count];
        // overcounting capacity but it's much faster
        NSMutableArray *allLeaves = [NSMutableArray arrayWithCapacity:taxa.count];

        for (NSDictionary *taxonDict in taxa) {
            VCPNode *node = [[VCPNode alloc] initWithDictionary:taxonDict];
            [allNodes addObject:node];
            if (node.leafId) {
                [allLeaves addObject:node];
            }
        }
        self.nodes = [NSArray arrayWithArray:allNodes];
        self.leaves = [NSArray arrayWithArray:allLeaves];

        // make lookup helper dict
        NSMutableDictionary *allNodesByTaxonId = [NSMutableDictionary dictionaryWithCapacity:taxa.count];
        for (VCPNode *node in self.nodes) {
            allNodesByTaxonId[node.taxonId] = node;
        }
        self.nodesByTaxonId = [NSDictionary dictionaryWithDictionary:allNodesByTaxonId];

        // build parentage
        for (VCPNode *node in self.nodes) {
            if (node.parentTaxonId) {
                VCPNode *parent = [self.nodesByTaxonId objectForKey:node.parentTaxonId];
                node.parent = parent;
                [parent addChild:node];
            } else {
                node.parent = self.life;
                [self.life addChild:node];
            }
        }

        self.taxonomyRollupCutoff = 0.01;
    }

    return self;
}

- (void)dealloc {
    self.life = nil;
    self.leaves = nil;
    self.nodes = nil;
    self.nodesByTaxonId = nil;
}

- (NSDictionary *)leafScoresFromClassification:(MLMultiArray *)classification {
    NSMutableDictionary *scores = [NSMutableDictionary dictionary];

    for (VCPNode *leaf in self.leaves) {
        NSNumber *score = [classification objectAtIndexedSubscript:leaf.leafId.integerValue];
        scores[leaf.taxonId] = score;
    }

    return [NSDictionary dictionaryWithDictionary:scores];
}

- (NSArray *)inflateTopBranchFromClassification:(MLMultiArray *)classification {
    NSDictionary *scores = [self aggregateScores:classification];
    return [self buildBestBranchFromScores:scores];
}

- (VCPPrediction *)inflateTopPredictionFromClassification:(MLMultiArray *)classification confidenceThreshold:(float)threshold {
    NSDictionary *scores = [self aggregateScores:classification];
    NSArray *bestBranch = [self buildBestBranchFromScores:scores];

    for (VCPPrediction *prediction in [bestBranch reverseObjectEnumerator]) {
        if (self.linneanPredictionsOnly) {
            // only KPCOFGS ranks qualify as "top" predictions
            // in the iNat taxonomy, KPCOFGS ranks are 70,60,50,40,30,20,10
            if (prediction.rank % 10 != 0) { continue; }
        }

        if (prediction.score > threshold) {
            return prediction;
        }
    }

    return nil;
}

// following
// https://github.com/inaturalist/inatVisionAPI/blob/multiclass/inferrers/multi_class_inferrer.py#L136
- (NSDictionary *)aggregateScores:(MLMultiArray *)classification currentNode:(VCPNode *)node {
    NSMutableDictionary *allScores = [NSMutableDictionary dictionary];

    if (node.children.count > 0) {
        float thisScore = 0.0f;
        for (VCPNode *child in node.children) {
            NSDictionary *childScores = [self aggregateScores:classification currentNode:child];
            NSNumber *childScore = childScores[child.taxonId];

            if ([childScore floatValue] > self.taxonomyRollupCutoff) {
                [allScores addEntriesFromDictionary:childScores];
                thisScore += [childScore floatValue];
            }
        }
        allScores[node.taxonId] = @(thisScore);

    } else {
        // base case, no children
        NSAssert(node.leafId, @"node with taxonId %@ has no children but also has no leafId", node.taxonId);
        NSNumber *leafScore = [classification objectAtIndexedSubscript:node.leafId.integerValue];
        NSAssert(leafScore, @"node with leafId %@ has no score", node.leafId);

        if ([leafScore floatValue] > self.taxonomyRollupCutoff) {
            allScores[node.taxonId] = leafScore;
        }
    }

    return [allScores copy];
}

- (NSDictionary *)aggregateScores:(MLMultiArray *)classification {
    return [self aggregateScores:classification currentNode:self.life];
}

- (NSArray *)buildBestBranchFromScores:(NSDictionary *)allScoresDict {
    NSMutableArray *bestBranch = [NSMutableArray array];

    // start from life
    VCPNode *currentNode = self.life;
    NSNumber *lifeScore = allScoresDict[currentNode.taxonId];
    VCPPrediction *lifePrediction = [[VCPPrediction alloc] initWithNode:currentNode
                                                                  score:lifeScore.floatValue];
    [bestBranch addObject:lifePrediction];

    NSArray *currentNodeChildren = currentNode.children;
    // loop while the last current node (the previous best child node) has more children
    while (currentNodeChildren.count > 0) {
        // find the best child of the current node
        VCPNode *bestChild = nil;
        float bestChildScore = -1;
        for (VCPNode *child in currentNodeChildren) {
            float childScore = [allScoresDict[child.taxonId] floatValue];
            if (childScore > bestChildScore) {
                bestChildScore = childScore;
                bestChild = child;
            }
        }

        if (bestChild) {
            VCPPrediction *bestChildPrediction = [[VCPPrediction alloc] initWithNode:bestChild
                                                                               score:bestChildScore];
            [bestBranch addObject:bestChildPrediction];
        }

        currentNode = bestChild;
        currentNodeChildren = currentNode.children;
    }

    return [NSArray arrayWithArray:bestBranch];
}

@end
