//
//  NATTaxonomy.m
//  RNTestLibrary
//
//  Created by Alex Shepard on 3/13/19.
//  Copyright © 2019 California Academy of Sciences. All rights reserved.
//

#import "NATTaxonomy.h"
#import "NATNode.h"
#import "NATPrediction.h"

@interface NATTaxonomy ()
@property NSArray *nodes;
@property NSDictionary *nodesByTaxonId;
// this is a convenience array for testing
@property NSArray *leaves;
@property NATNode *life;
@end

@implementation NATTaxonomy

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
        
        self.life =  [[NATNode alloc] init];
        self.life.taxonId = @(48460);
        self.life.rank = @(100);
        self.life.name = @"Life";
                
        // extract nodes from taxa json object
        NSMutableArray *allNodes = [NSMutableArray arrayWithCapacity:taxa.count];
        // overcounting capacity but it's much faster
        NSMutableArray *allLeaves = [NSMutableArray arrayWithCapacity:taxa.count];
        
        for (NSDictionary *taxonDict in taxa) {
            NATNode *node = [[NATNode alloc] initWithDictionary:taxonDict];
            [allNodes addObject:node];
            if (node.leafId) {
                [allLeaves addObject:node];
            }
        }
        self.nodes = [NSArray arrayWithArray:allNodes];
        self.leaves = [NSArray arrayWithArray:allLeaves];

        // make lookup helper dict
        NSMutableDictionary *allNodesByTaxonId = [NSMutableDictionary dictionaryWithCapacity:taxa.count];
        for (NATNode *node in self.nodes) {
            allNodesByTaxonId[node.taxonId] = node;
        }
        self.nodesByTaxonId = [NSDictionary dictionaryWithDictionary:allNodesByTaxonId];

        // build parentage
        for (NATNode *node in self.nodes) {
            if (node.parentTaxonId) {
                NATNode *parent = [self.nodesByTaxonId objectForKey:node.parentTaxonId];
                node.parent = parent;
                [parent addChild:node];
            } else {
                node.parent = self.life;
                [self.life addChild:node];
            }
        }
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
    
    for (NATNode *leaf in self.leaves) {
        NSNumber *score = [classification objectAtIndexedSubscript:leaf.leafId.integerValue];
        scores[leaf.taxonId] = score;
    }
    
    return [NSDictionary dictionaryWithDictionary:scores];
}

- (NSArray *)inflateTopBranchFromClassification:(MLMultiArray *)classification {
    NSDictionary *scores = [self aggregateScores:classification];
    return [self buildBestBranchFromScores:scores];
}

- (NATPrediction *)inflateTopPredictionFromClassification:(MLMultiArray *)classification confidenceThreshold:(float)threshold {
    NSDictionary *scores = [self aggregateScores:classification];
    NSArray *bestBranch = [self buildBestBranchFromScores:scores];
    
    for (NATPrediction *prediction in [bestBranch reverseObjectEnumerator]) {
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
- (NSDictionary *)aggregateScores:(MLMultiArray *)classification currentNode:(NATNode *)node {
    if (node.children.count > 0) {
        // we'll populate this and return it
        NSMutableDictionary *allScores = [NSMutableDictionary dictionary];
        
        for (NATNode *child in node.children) {
            NSDictionary *childScores = [self aggregateScores:classification currentNode:child];
            [allScores addEntriesFromDictionary:childScores];
        }
        
        float thisScore = 0.0f;
        for (NATNode *child in node.children) {
            thisScore += [allScores[child.taxonId] floatValue];
        }
        
        allScores[node.taxonId] = @(thisScore);
        
        return [NSDictionary dictionaryWithDictionary:allScores];
    } else {
        // base case, no children
        return @{
            node.taxonId: [classification objectAtIndexedSubscript:node.leafId.integerValue]
        };
    }
}

- (NSDictionary *)aggregateScores:(MLMultiArray *)classification {
    return [self aggregateScores:classification currentNode:self.life];
}

- (NSArray *)buildBestBranchFromScores:(NSDictionary *)allScoresDict {
    NSMutableArray *bestBranch = [NSMutableArray array];

    // start from life
    NATNode *currentNode = self.life;
    NSNumber *lifeScore = allScoresDict[currentNode.taxonId];
    NATPrediction *lifePrediction = [[NATPrediction alloc] initWithNode:currentNode
                                                                  score:lifeScore.floatValue];
    [bestBranch addObject:lifePrediction];
    
    NSArray *currentNodeChildren = currentNode.children;
    // loop while the last current node (the previous best child node) has more children
    while (currentNodeChildren.count > 0) {
        // find the best child of the current node
        NATNode *bestChild = nil;
        float bestChildScore = -1;
        for (NATNode *child in currentNodeChildren) {
            float childScore = [allScoresDict[child.taxonId] floatValue];
            if (childScore > bestChildScore) {
                bestChildScore = childScore;
                bestChild = child;
            }
        }
        
        if (bestChild) {
            NATPrediction *bestChildPrediction = [[NATPrediction alloc] initWithNode:bestChild
                                                                               score:bestChildScore];
            [bestBranch addObject:bestChildPrediction];
        }
        
        currentNode = bestChild;
        currentNodeChildren = currentNode.children;
    }
    
    return [NSArray arrayWithArray:bestBranch];
}

@end
