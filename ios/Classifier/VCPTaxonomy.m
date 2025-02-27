//
//  VCPTaxonomy.m
//  RNTestLibrary
//
//  Created by Alex Shepard on 3/13/19.
//  Copyright © 2023 iNaturalist. All rights reserved.
//
@import Accelerate;
@import CoreGraphics;

#import "VCPTaxonomy.h"
#import "VCPNode.h"
#import "VCPPrediction.h"

@interface VCPTaxonomy ()
@property NSArray *nodes;
@property NSDictionary *nodesByTaxonId;
// this is a convenience array for testing
@property NSArray *leaves;
@property VCPNode *life;
@property float excludedLeafCombinedScoresSum;
@property float excludedLeafVisionScoresSum;
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

        self.taxonomyRollupCutoff = 0.0;
    }

    return self;
}

- (void)dealloc {
    self.life = nil;
    self.leaves = nil;
    self.nodes = nil;
    self.nodesByTaxonId = nil;
}

- (NSArray *)expectedNearbyFromClassification:(MLMultiArray *)classification {
    NSMutableArray *scores = [NSMutableArray array];
    NSMutableArray *filteredOutScores = [NSMutableArray array];

    for (VCPNode *leaf in self.leaves) {
        NSNumber *geoScore = [classification objectAtIndexedSubscript:leaf.leafId.integerValue];
        VCPPrediction *prediction = [[VCPPrediction alloc] initWithNode:leaf
                                                                  score:0
                                                                  visionScore:0
                                                            geoScore:geoScore.floatValue];
        // If geoScore is higher than geoThreshold it means the taxon is "expected nearby"
        if (leaf.geoThreshold) {
          if (geoScore.floatValue >= leaf.geoThreshold.floatValue) {
            [scores addObject:prediction];
          } else {
            [filteredOutScores addObject:prediction];
          }
        } else {
          [scores addObject:prediction];
        }
    }

    // Log length of scores
    NSLog(@"Length of scores: %lu", (unsigned long)scores.count);
    NSLog(@"Length of filteredOutScores: %lu", (unsigned long)filteredOutScores.count);

    return [NSArray arrayWithArray:scores];
}

- (void)deriveTopScoreRatioCutoff:(MLMultiArray *)classification {
    // Get a pointer to the raw data
    float *dataPointer = (float *)classification.dataPointer;
    NSUInteger count = classification.count;
    // Use vDSP to find the maximum value
    float topCombinedScore;
    vDSP_maxv(dataPointer, 1, &topCombinedScore, count);
    // define some cutoff based on a percentage of the top combined score. Taxa with
    // scores below the cutoff will be ignored when aggregating scores up the taxonomy
    float scoreRatioCutoff = 0.001;
    float cutoff = topCombinedScore * scoreRatioCutoff;
    // Set the taxonomyRollupCutoff to the cutoff
    [self setTaxonomyRollupCutoff:cutoff];
}

- (NSArray *)inflateCommonAncestorFromClassification:(MLMultiArray *)classification visionScores:(MLMultiArray *)visionScores geoScores:(MLMultiArray *)geoScores {
    NSDictionary *aggregatedScores = [self aggregateAndNormalizeScores:classification visionScores:visionScores geoScores:geoScores];
    NSDictionary *combinedScoresDict = aggregatedScores[@"aggregatedCombinedScores"];
    NSDictionary *visionScoresDict = aggregatedScores[@"aggregatedVisionScores"];
    NSDictionary *geoScoresDict = aggregatedScores[@"aggregatedGeoScores"];
    NSDictionary *geoThresholdsDict = aggregatedScores[@"aggregatedGeoThresholds"];
    // Log number of nodes in combinedScoresDict
    NSLog(@"Number of nodes in combinedScoresDict: %lu", (unsigned long)combinedScoresDict.count);
    NSMutableArray *scoresArray = [NSMutableArray array];
    for (NSNumber *taxonId in combinedScoresDict.allKeys) {
        VCPNode *node = self.nodesByTaxonId[taxonId];
        NSNumber *combinedScore = combinedScoresDict[taxonId];
        NSNumber *visionScore = visionScoresDict[taxonId];
        NSNumber *geoScore = geoScoresDict[taxonId];
        NSNumber *geoThreshold = geoThresholdsDict[taxonId];
        node.geoThreshold = geoThreshold;
        VCPPrediction *prediction = [[VCPPrediction alloc] initWithNode:node
                                                                  score:combinedScore.floatValue
                                                                  visionScore:visionScore.floatValue
                                                                  geoScore:geoScore.floatValue];
        [scoresArray addObject:prediction];
    }
    return [NSArray arrayWithArray:scoresArray];
}

- (NSArray *)inflateTopBranchFromClassification:(MLMultiArray *)classification visionScores:(MLMultiArray *)visionScores geoScores:(MLMultiArray *)geoScores {
    NSDictionary *aggregatedScores = [self aggregateAndNormalizeScores:classification visionScores:visionScores geoScores:geoScores];
    return [self buildBestBranchFromScores:aggregatedScores];
}

- (NSDictionary *)aggregateScores:(MLMultiArray *)classification visionScores:(MLMultiArray *)visionScores geoScores:(MLMultiArray *)geoScores currentNode:(VCPNode *)node {
    NSMutableDictionary *aggregatedCombinedScores = [NSMutableDictionary dictionary];
    NSMutableDictionary *aggregatedVisionScores = [NSMutableDictionary dictionary];
    NSMutableDictionary *aggregatedGeoScores = [NSMutableDictionary dictionary];
    NSMutableDictionary *aggregatedGeoThresholds = [NSMutableDictionary dictionary];
    bool hasGeoScores = geoScores != nil;
    if (node.children.count > 0) {
        float thisCombinedScore = 0.0f;
        float thisVisionScore = 0.0f;
        float thisGeoScore = 0.0f;
        float thisGeoThreshold = INFINITY;
        for (VCPNode *child in node.children) {
            NSDictionary *childScores = [self aggregateScores:classification visionScores:visionScores geoScores:geoScores currentNode:child];
            NSDictionary *aggregatedChildCombinedScores = childScores[@"aggregatedCombinedScores"];
            NSNumber *childCombinedScore = aggregatedChildCombinedScores[child.taxonId];
            if ([childCombinedScore floatValue] >= self.taxonomyRollupCutoff) {
                [aggregatedCombinedScores addEntriesFromDictionary:aggregatedChildCombinedScores];
                thisCombinedScore += [childCombinedScore floatValue];
                NSDictionary *aggregatedChildVisionScores = childScores[@"aggregatedVisionScores"];
                [aggregatedVisionScores addEntriesFromDictionary:aggregatedChildVisionScores];
                thisVisionScore += [aggregatedChildVisionScores[child.taxonId] floatValue];
                if (hasGeoScores) {
                  NSDictionary *aggregatedChildGeoScores = childScores[@"aggregatedGeoScores"];
                  [aggregatedGeoScores addEntriesFromDictionary:aggregatedChildGeoScores];
                  // Aggregated geo score is the max of descendant geo scores
                  thisGeoScore = MAX(thisGeoScore, [aggregatedChildGeoScores[child.taxonId] floatValue]);
                }
                NSDictionary *aggregatedChildGeoThresholds = childScores[@"aggregatedGeoThresholds"];
                [aggregatedGeoThresholds addEntriesFromDictionary:aggregatedChildGeoThresholds];
                NSNumber *childGeoThreshold = aggregatedChildGeoThresholds[child.taxonId];
                if (childGeoThreshold != nil) {
                  // Aggregated geo_threshold is the min of descendant geo_thresholds
                  thisGeoThreshold = MIN(thisGeoThreshold, [childGeoThreshold floatValue]);
                }
            }
        }
        if (thisCombinedScore > 0) {
          aggregatedCombinedScores[node.taxonId] = @(thisCombinedScore);
          aggregatedVisionScores[node.taxonId] = @(thisVisionScore);
          if (hasGeoScores) {
            aggregatedGeoScores[node.taxonId] = @(thisGeoScore);
          } else {
            aggregatedGeoScores[node.taxonId] = nil;
          }
          if (thisGeoThreshold != INFINITY) {
            aggregatedGeoThresholds[node.taxonId] = @(thisGeoThreshold);
          } else {
            aggregatedGeoThresholds[node.taxonId] = nil;
          }
        }
    } else {
        // base case, no children
        NSAssert(node.leafId, @"node with taxonId %@ has no children but also has no leafId", node.taxonId);
        NSNumber *combinedScore = [classification objectAtIndexedSubscript:node.leafId.integerValue];
        NSNumber *visionScore = [visionScores objectAtIndexedSubscript:node.leafId.integerValue];
        NSAssert(combinedScore, @"node with leafId %@ has no score", node.leafId);

        if ([combinedScore floatValue] >= self.taxonomyRollupCutoff) {
            aggregatedCombinedScores[node.taxonId] = combinedScore;
            aggregatedVisionScores[node.taxonId] = visionScore;
            if (hasGeoScores) {
              NSNumber *geoScore = [geoScores objectAtIndexedSubscript:node.leafId.integerValue];
              aggregatedGeoScores[node.taxonId] = geoScore;
            } else {
              aggregatedGeoScores[node.taxonId] = nil;
            }
            aggregatedGeoThresholds[node.taxonId] = node.geoThreshold;
        } else {
            self.excludedLeafCombinedScoresSum += combinedScore.floatValue;
            self.excludedLeafVisionScoresSum += visionScore.floatValue;
        }
    }
    return @{
      @"aggregatedCombinedScores": [aggregatedCombinedScores copy],
      @"aggregatedVisionScores": [aggregatedVisionScores copy],
      @"aggregatedGeoScores": [aggregatedGeoScores copy],
      @"aggregatedGeoThresholds": [aggregatedGeoThresholds copy]
    };
}

- (NSDictionary *)aggregateAndNormalizeScores:(MLMultiArray *)classification visionScores:(MLMultiArray *)visionScores geoScores:(MLMultiArray *)geoScores {
    // Reset the sum of removed leaf scores
    self.excludedLeafCombinedScoresSum = 0.0;
    self.excludedLeafVisionScoresSum = 0.0;
    NSDictionary *aggregatedScores = [self aggregateScores:classification visionScores:visionScores geoScores:geoScores currentNode:self.life];
    NSDictionary *aggregatedCombinedScores = aggregatedScores[@"aggregatedCombinedScores"];
    NSDictionary *aggregatedVisionScores = aggregatedScores[@"aggregatedVisionScores"];
    // Re-normalize combined scores with the sum of the remaining leaf scores
    NSMutableDictionary *normalizedCombinedScores = [NSMutableDictionary dictionaryWithCapacity:aggregatedCombinedScores.count];
    for (NSNumber *taxonId in aggregatedCombinedScores.allKeys) {
        NSNumber *score = aggregatedCombinedScores[taxonId];
        normalizedCombinedScores[taxonId] = @(score.floatValue / (1.0 - self.excludedLeafCombinedScoresSum));
    }
    // Re-normalize vision scores with the sum of the remaining leaf scores
    NSMutableDictionary *normalizedVisionScores = [NSMutableDictionary dictionaryWithCapacity:aggregatedVisionScores.count];
    for (NSNumber *taxonId in aggregatedVisionScores.allKeys) {
        NSNumber *score = aggregatedVisionScores[taxonId];
        normalizedVisionScores[taxonId] = @(score.floatValue / (1.0 - self.excludedLeafVisionScoresSum));
    }

    return @{
      @"aggregatedCombinedScores": [normalizedCombinedScores copy],
      @"aggregatedVisionScores": [normalizedVisionScores copy],
      @"aggregatedGeoScores": aggregatedScores[@"aggregatedGeoScores"],
      @"aggregatedGeoThresholds": aggregatedScores[@"aggregatedGeoThresholds"]
    };
}

- (NSArray *)buildBestBranchFromScores:(NSDictionary *)allScoresDict {
    NSMutableArray *bestBranch = [NSMutableArray array];

    NSDictionary *combinedScores = allScoresDict[@"aggregatedCombinedScores"];
    NSDictionary *visionScores = allScoresDict[@"aggregatedVisionScores"];
    NSDictionary *geoScores = allScoresDict[@"aggregatedGeoScores"];
    NSDictionary *geoThresholds = allScoresDict[@"aggregatedGeoThresholds"];
    // Log number of nodes in combinedScores
    NSLog(@"Number of nodes in combinedScores: %lu", (unsigned long)combinedScores.count);

    // start from life
    VCPNode *currentNode = self.life;
    NSNumber *lifeCombinedScore = combinedScores[currentNode.taxonId];
    NSNumber *lifeVisionScore = visionScores[currentNode.taxonId];
    NSNumber *lifeGeoScore = geoScores[currentNode.taxonId];
    NSNumber *lifeGeoThreshold = geoThresholds[currentNode.taxonId];
    currentNode.geoThreshold = lifeGeoThreshold;
    VCPPrediction *lifePrediction = [[VCPPrediction alloc] initWithNode:currentNode
                                                                  score:lifeCombinedScore.floatValue
                                                                  visionScore:lifeVisionScore.floatValue
                                                                  geoScore:lifeGeoScore.floatValue];
    [bestBranch addObject:lifePrediction];

    NSArray *currentNodeChildren = currentNode.children;
    // loop while the last current node (the previous best child node) has more children
    while (currentNodeChildren.count > 0) {
        // find the best child of the current node
        VCPNode *bestChild = nil;
        float bestChildScore = -1;
        for (VCPNode *child in currentNodeChildren) {
            float childScore = [combinedScores[child.taxonId] floatValue];
            if (childScore > bestChildScore) {
                bestChildScore = childScore;
                bestChild = child;
            }
        }

        if (bestChild) {
            NSNumber *bestChildVisionScore = visionScores[bestChild.taxonId];
            NSNumber *bestChildGeoScore = geoScores[bestChild.taxonId];
            NSNumber *bestChildGeoThreshold = geoThresholds[bestChild.taxonId];
            bestChild.geoThreshold = bestChildGeoThreshold;
            VCPPrediction *bestChildPrediction = [[VCPPrediction alloc] initWithNode:bestChild
                                                                               score:bestChildScore
                                                                               visionScore:bestChildVisionScore.floatValue
                                                                               geoScore:bestChildGeoScore.floatValue];
            [bestBranch addObject:bestChildPrediction];
        }

        currentNode = bestChild;
        currentNodeChildren = currentNode.children;
    }

    return [NSArray arrayWithArray:bestBranch];
}

@end
