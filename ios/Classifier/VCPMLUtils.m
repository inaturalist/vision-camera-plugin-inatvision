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

@end
