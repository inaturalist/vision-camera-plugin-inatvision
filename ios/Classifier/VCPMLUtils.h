#import <Foundation/Foundation.h>
@import CoreML;

NS_ASSUME_NONNULL_BEGIN

@interface VCPMLUtils : NSObject

/**
 * Normalizes the values in an MLMultiArray by dividing each element by the sum of all elements.
 * @param mlArray The MLMultiArray to normalize
 * @param error Pointer to an NSError object that will be set if an error occurs
 * @return The normalized MLMultiArray, or nil if an error occurred
 */
+ (MLMultiArray * _Nullable)normalizeMultiArray:(MLMultiArray *)mlArray error:(NSError **)error;

/**
 * Combines two MLMultiArray objects by element-wise multiplication.
 * @param visionScores The first MLMultiArray (typically vision model scores)
 * @param geoScores The second MLMultiArray (typically geo model scores)
 * @param error Pointer to an NSError object that will be set if an error occurs
 * @return The combined MLMultiArray, or nil if an error occurred
 */
+ (MLMultiArray * _Nullable)combineVisionScores:(MLMultiArray *)visionScores
                                           with:(MLMultiArray *)geoScores
                                          error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
