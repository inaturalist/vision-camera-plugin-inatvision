#import "VCPMLUtils.h"
#import <Accelerate/Accelerate.h>

@implementation VCPMLUtils

+ (MLMultiArray * _Nullable)normalizeMultiArray:(MLMultiArray *)mlArray error:(NSError **)error {
    NSInteger count = mlArray.count;
    float *mlData = (float *)mlArray.dataPointer;

    float sum = 0.0;
    vDSP_sve(mlData, 1, &sum, count);

    if (sum != 0) {
        vDSP_vsdiv(mlData, 1, &sum, mlData, 1, count);
    } else {
        NSDictionary *userInfo = @{
            NSLocalizedDescriptionKey: @"Sum of elements is zero, normalization not possible."
        };
        *error = [NSError errorWithDomain:@"MLMultiArrayErrorDomain"
                                     code:3
                                 userInfo:userInfo];
        return nil;
    }

    return mlArray;
}

+ (MLMultiArray * _Nullable)combineVisionScores:(MLMultiArray *)visionScores
                                           with:(MLMultiArray *)geoScores
                                          error:(NSError **)error {
    // Ensure both arrays have the same shape
    if (![visionScores.shape isEqualToArray:geoScores.shape]) {
        NSDictionary *userInfo = @{
            NSLocalizedDescriptionKey: @"Arrays must have the same shape",
        };
        *error = [NSError errorWithDomain:@"MLMultiArrayErrorDomain"
                                     code:1
                                 userInfo:userInfo];
        return nil;
    }

    // Create a result MLMultiArray with the same shape as the input arrays
    MLMultiArray *combinedArray = [[MLMultiArray alloc] initWithShape:visionScores.shape
                                                             dataType:MLMultiArrayDataTypeFloat32
                                                                error:error];
    if (!combinedArray) {
        NSDictionary *userInfo = @{
            NSLocalizedDescriptionKey: @"Failed to make combined array",
        };
        *error = [NSError errorWithDomain:@"MLMultiArrayErrorDomain"
                                     code:2
                                 userInfo:userInfo];
        return nil;
    }

    // Get the data pointers
    float *visionData = (float *)visionScores.dataPointer;
    float *geoData = (float *)geoScores.dataPointer;
    float *combinedData = (float *)combinedArray.dataPointer;

    // Get the number of elements
    NSInteger count = visionScores.count;

    // Perform element-wise multiplication using vDSP_vmul
    vDSP_vmul(visionData, 1, geoData, 1, combinedData, 1, count);

    return combinedArray;
}

@end
