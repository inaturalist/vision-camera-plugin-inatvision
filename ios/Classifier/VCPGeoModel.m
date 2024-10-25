//
//  VCPGeoModel.m
//  VisionCameraPluginInatVision
//
//  Created by Alex Shepard on 10/18/24.
//  Copyright © 2024 iNaturalist. All rights reserved.
//

#import "VCPGeoModel.h"

@interface VCPGeoModel ()

@property (nonatomic, strong) MLMultiArray *cachedGeoResult;
@property (nonatomic) float cachedLatitude;
@property (nonatomic) float cachedLongitude;
@property (nonatomic) float cachedElevation;


@end

@implementation VCPGeoModel

- (instancetype _Nullable)initWithModelPath:(NSString *)modelPath {
    if (self = [super init]) {
        NSURL *geoModelUrl = [NSURL fileURLWithPath:modelPath];
        if (!geoModelUrl) {
            NSLog(@"no file for geo model");
            return nil;
        }
        
        NSError *loadError = nil;
        self.geoModel = [MLModel modelWithContentsOfURL:geoModelUrl error:&loadError];
        if (loadError) {
            NSString *errString = [NSString stringWithFormat:@"error loading geo model: %@",
                                   loadError.localizedDescription];
            NSLog(@"%@", errString);
            return nil;
        }
        if (!self.geoModel) {
            NSLog(@"unable to make geo model");
            return nil;
        }
        
        // default location change threshold
        self.locationChangeThreshold = -0.001;

    }
    
    return self;
}

/*
 * iNat geo model input normalization documented here:
 * https://github.com/inaturalist/inatGeoModelTraining/tree/main#input-normalization
 */
- (NSArray *)normAndEncodeLat:(float)latitude lng:(float)longitude elevation:(float)elevation {
    float normLat = latitude / 90.0;
    float normLng = longitude / 180.0;
    float normElev = 0.0;
    if (elevation > 0) {
        normElev = elevation / 5705.63;
    } else {
        normElev = elevation / 32768.0;
    }
    float a = sin(M_PI * normLng);
    float b = sin(M_PI * normLat);
    float c = cos(M_PI * normLng);
    float d = cos(M_PI * normLat);
    
    return @[ @(a), @(b), @(c), @(d), @(normElev) ];
}

- (MLMultiArray *)predictionsForLat:(float)latitude lng:(float)longitude elevation:(float)elevation {
    if (!self.cachedGeoResult ||
        fabs(latitude - self.cachedLatitude) > self.locationChangeThreshold ||
        fabs(longitude - self.cachedLongitude) > self.locationChangeThreshold ||
        fabs(elevation - self.cachedElevation) > self.locationChangeThreshold)
    {        
        self.cachedGeoResult = [self geoModelPredictionsForLat:latitude lng:longitude elevation:elevation];
        self.cachedLatitude = latitude;
        self.cachedLongitude = longitude;
        self.cachedElevation = elevation;
    }

    return self.cachedGeoResult;
}

- (MLMultiArray *)geoModelPredictionsForLat:(float)latitude lng:(float)longitude elevation:(float)elevation {
    NSArray *geoModelInputs = [self normAndEncodeLat:latitude
                                                 lng:longitude
                                           elevation:elevation];
    
    NSError *err = nil;
    MLMultiArray *mlInputs = [[MLMultiArray alloc] initWithShape:@[@1, @5]
                                                        dataType:MLMultiArrayDataTypeDouble
                                                           error:&err];
    for (int i = 0; i < 5; i++) {
        mlInputs[i] = geoModelInputs[i];
    }
    MLFeatureValue *fv = [MLFeatureValue featureValueWithMultiArray:mlInputs];
    
    NSError *fpError = nil;
    NSDictionary *fpDict = @{ @"input_1": fv };
    MLDictionaryFeatureProvider *fp = [[MLDictionaryFeatureProvider alloc] initWithDictionary:fpDict
                                                                                        error:&fpError];
    
    NSError *predError = nil;
    id <MLFeatureProvider> results = [self.geoModel predictionFromFeatures:fp error:&predError];
    MLFeatureValue *result = [results featureValueForName:@"Identity"];
    MLMultiArray *geoModelScores = result.multiArrayValue;
        
    return geoModelScores;
}

@end
