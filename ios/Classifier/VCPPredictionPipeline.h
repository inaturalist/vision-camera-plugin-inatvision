#import <Foundation/Foundation.h>
@import CoreML;

@class VCPTaxonomy;

NS_ASSUME_NONNULL_BEGIN

@interface VCPPredictionPipeline : NSObject

+ (NSArray *)predictionDictionariesForVisionScores:(MLMultiArray *)visionScores
                                     geomodelPreds:(MLMultiArray * _Nullable)geomodelPreds
                                          taxonomy:(VCPTaxonomy *)taxonomy
                              taxonomyRollupCutoff:(NSNumber * _Nullable)taxonomyRollupCutoff
                                              mode:(NSString * _Nullable)mode;

@end

NS_ASSUME_NONNULL_END
