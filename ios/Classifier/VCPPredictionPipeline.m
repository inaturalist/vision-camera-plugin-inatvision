#import "VCPPredictionPipeline.h"

#import "VCPMLUtils.h"
#import "VCPTaxonomy.h"
#import "VCPPrediction.h"

@implementation VCPPredictionPipeline

+ (NSArray *)predictionDictionariesForVisionScores:(MLMultiArray *)visionScores
                                     geomodelPreds:(MLMultiArray *)geomodelPreds
                                          taxonomy:(VCPTaxonomy *)taxonomy
                              taxonomyRollupCutoff:(NSNumber *)taxonomyRollupCutoff
                                              mode:(NSString *)mode {
    MLMultiArray *results = nil;

    if (geomodelPreds != nil) {
        NSError *err = nil;
        results = [VCPMLUtils combineVisionScores:visionScores with:geomodelPreds error:&err];
        results = [VCPMLUtils normalizeMultiArray:results error:&err];
    } else {
        results = visionScores;
    }

    [taxonomy deriveTopScoreRatioCutoff:results];
    if (taxonomyRollupCutoff) {
        [taxonomy setTaxonomyRollupCutoff:taxonomyRollupCutoff.floatValue];
    }

    NSMutableArray *predictions = [NSMutableArray array];
    if ([mode isEqualToString:@"COMMON_ANCESTOR"]) {
      NSArray *commonAncestor = [taxonomy inflateCommonAncestorFromClassification:results visionScores:visionScores geoScores:geomodelPreds];
      for (VCPPrediction *prediction in commonAncestor) {
        [predictions addObject:[prediction asDict]];
      }
    } else {
      NSArray *bestBranch = [taxonomy inflateTopBranchFromClassification:results visionScores:visionScores geoScores:geomodelPreds];
      for (VCPPrediction *prediction in bestBranch) {
          // convert the VCPPredictions in the bestBranch into dicts
          [predictions addObject:[prediction asDict]];
      }
    }
    return predictions;
}

@end
