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

@end

NS_ASSUME_NONNULL_END
