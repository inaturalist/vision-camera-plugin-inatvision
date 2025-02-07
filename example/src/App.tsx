import React, { useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Button,
  Image,
  Platform,
  Pressable,
  SafeAreaView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import {
  Camera,
  useCameraDevice,
  useFrameProcessor,
  useCameraPermission,
  useLocationPermission,
  runAsync,
} from 'react-native-vision-camera';
import RNFS from 'react-native-fs';
import { launchImageLibrary } from 'react-native-image-picker';
import { useCameraRoll } from '@react-native-camera-roll/camera-roll';
import { Worklets } from 'react-native-worklets-core';
import * as InatVision from 'vision-camera-plugin-inatvision';

const testLocationEurope = {
  latitude: 54.29,
  longitude: 18.95,
  elevation: 15,
};

const testLocationEuropeNoElevation = {
  latitude: 54.29,
  longitude: 18.95,
};

const testLocationAmerica = {
  latitude: 37.87,
  longitude: -122.25,
  elevation: 15,
};

// TODO: these .tflite models do not work yet, why?
const modelFilenameAndroid = 'INatVision_Small_2_fact256_8bit.tflite';
const taxonomyFilenameAndroid = 'taxonomy.csv';
const geomodelFilenameAndroid = 'INatGeomodel_Small_2_8bit.tflite';
const modelFilenameIOS = 'INatVision_Small_2_fact256_8bit.mlmodelc';
const taxonomyFilenameIOS = 'taxonomy.json';
const geomodelFilenameIOS = 'INatGeomodel_Small_2_8bit.mlmodelc';
const modelVersion = 'small_2';

const modelPath =
  Platform.OS === 'ios'
    ? `${RNFS.DocumentDirectoryPath}/${modelFilenameIOS}`
    : `${RNFS.DocumentDirectoryPath}/${modelFilenameAndroid}`;
const geomodelPath =
  Platform.OS === 'ios'
    ? `${RNFS.DocumentDirectoryPath}/${geomodelFilenameIOS}`
    : `${RNFS.DocumentDirectoryPath}/${geomodelFilenameAndroid}`;
const taxonomyPath =
  Platform.OS === 'ios'
    ? `${RNFS.DocumentDirectoryPath}/${taxonomyFilenameIOS}`
    : `${RNFS.DocumentDirectoryPath}/${taxonomyFilenameAndroid}`;

export default function App(): React.JSX.Element {
  const { hasPermission, requestPermission } = useCameraPermission();
  const location = useLocationPermission();

  const [results, setResult] = useState<InatVision.Prediction[]>([]);
  const [filterByTaxonId, setFilterByTaxonId] = useState<
    undefined | string | null
  >(undefined);
  const [negativeFilter, setNegativeFilter] = useState(false);
  const [useGeomodel, setUseGeomodel] = useState(false);

  enum VIEW_STATUS {
    NONE,
    CAMERA,
    GALLERY,
    GEOMODEL,
  }
  const [viewStatus, setViewStatus] = useState<VIEW_STATUS>(VIEW_STATUS.NONE);
  const [confidenceThreshold, setConfidenceThreshold] = useState<number>(0.7);

  const device = useCameraDevice('back');

  const [photos, getPhotos] = useCameraRoll();

  const toggleNegativeFilter = () => {
    setNegativeFilter(!negativeFilter);
  };

  const toggleUseGeomodel = () => {
    setUseGeomodel(!useGeomodel);
  };

  const changeFilterByTaxonId = () => {
    if (!filterByTaxonId) {
      setFilterByTaxonId('47126');
    } else {
      setFilterByTaxonId(null);
    }
  };

  useEffect(() => {
    (async () => {
      requestPermission();
    })();
  }, [requestPermission]);

  useEffect(() => {
    location.requestPermission();
  }, [location]);

  useEffect(() => {
    if (Platform.OS === 'ios') {
      return;
    }

    InatVision.addLogListener((event: any) => {
      console.log('event', event);
    });

    return () => {
      InatVision.removeLogListener();
    };
  }, []);

  useEffect(() => {
    if (Platform.OS === 'ios') {
      RNFS.copyFile(
        `${RNFS.MainBundlePath}/${modelFilenameIOS}`,
        `${RNFS.DocumentDirectoryPath}/${modelFilenameIOS}`
      )
        .then((result) => {
          console.log(`moved model file from`, result);
        })
        .catch((error) => {
          console.log(`error moving model file`, error);
        });
      RNFS.copyFile(
        `${RNFS.MainBundlePath}/${geomodelFilenameIOS}`,
        `${RNFS.DocumentDirectoryPath}/${geomodelFilenameIOS}`
      )
        .then((result) => {
          console.log(`moved geomodel file from`, result);
        })
        .catch((error) => {
          console.log(`error moving geomodel file`, error);
        });
      RNFS.copyFile(
        `${RNFS.MainBundlePath}/${taxonomyFilenameIOS}`,
        `${RNFS.DocumentDirectoryPath}/${taxonomyFilenameIOS}`
      )
        .then((result) => {
          console.log(`moved file from`, result);
        })
        .catch((error) => {
          console.log(`error moving file`, error);
        });
    } else {
      (async () => {
        await RNFS.copyFileAssets(
          modelFilenameAndroid,
          `${RNFS.DocumentDirectoryPath}/${modelFilenameAndroid}`
        );
        await RNFS.copyFileAssets(
          taxonomyFilenameAndroid,
          `${RNFS.DocumentDirectoryPath}/${taxonomyFilenameAndroid}`
        );
        await RNFS.copyFileAssets(
          geomodelFilenameAndroid,
          `${RNFS.DocumentDirectoryPath}/${geomodelFilenameAndroid}`
        );
      })();
    }
  }, []);

  const handleResults = Worklets.createRunOnJS(
    (predictions: InatVision.Prediction[]) => {
      setResult(predictions);
    }
  );

  const geoModelCellLocation = InatVision.getCellLocation(
    testLocationEuropeNoElevation
  );

  const frameProcessor = useFrameProcessor(
    (frame) => {
      'worklet';
      runAsync(frame, () => {
        'worklet';
        try {
          const timeBefore = new Date().getTime();

          const cvResult: InatVision.Result = InatVision.inatVision(frame, {
            version: modelVersion,
            modelPath,
            taxonomyPath,
            confidenceThreshold,
            filterByTaxonId,
            negativeFilter,
            numStoredResults: 4,
            cropRatio: 0.9,
            useGeomodel,
            geomodelPath,
            location: {
              latitude: geoModelCellLocation.latitude,
              longitude: geoModelCellLocation.longitude,
              elevation: geoModelCellLocation.elevation,
            },
            patchedOrientationAndroid: 'portrait',
          });
          const timeAfter = new Date().getTime();
          console.log('time taken ms: ', timeAfter - timeBefore);
          console.log('age of result: ', timeAfter - cvResult.timestamp);
          console.log('cvResult.timeElapsed', cvResult.timeElapsed);
          handleResults(cvResult.predictions);
        } catch (classifierError) {
          console.log(`Error: ${classifierError}`);
        }
      });
    },
    [
      confidenceThreshold,
      filterByTaxonId,
      negativeFilter,
      handleResults,
      useGeomodel,
      geoModelCellLocation,
    ]
  );

  function selectImage() {
    launchImageLibrary(
      {
        mediaType: 'photo',
        includeBase64: false,
      },
      (response) => {
        if (response.didCancel) {
          console.log('User cancelled image picker');
        } else if (response.assets && response.assets.length > 0) {
          const asset = response.assets[0];
          const uri = asset
            ? Platform.OS === 'ios'
              ? asset.uri
              : asset.originalPath
            : '';
          console.log('Image URI: ', uri);
          if (uri) {
            predict(uri);
          } else {
            Alert.alert('No image URI');
          }
        }
      }
    );
  }

  function predict(uri: string) {
    const timeBefore = new Date().getTime();
    InatVision.getPredictionsForImage({
      uri,
      version: modelVersion,
      modelPath,
      taxonomyPath,
      confidenceThreshold,
      cropRatio: 0.88,
      useGeomodel: true,
      geomodelPath,
      location: {
        latitude: testLocationEuropeNoElevation.latitude,
        longitude: testLocationEuropeNoElevation.longitude,
      },
    })
      .then((result) => {
        const timeAfter = new Date().getTime();
        console.log('time taken ms: ', timeAfter - timeBefore);
        console.log('Result', JSON.stringify(result));
        console.log('result.timeElapsed', result.timeElapsed);
        setResult(result.predictions);
      })
      .catch((err) => {
        console.log('getPredictionsForImage Error', err);
      });
  }

  function predictLocation(location2: InatVision.Location) {
    const timeBefore = new Date().getTime();
    InatVision.getPredictionsForLocation({
      taxonomyPath,
      geomodelPath,
      location: location2,
    })
      .then((result) => {
        const timeAfter = new Date().getTime();
        console.log('time taken ms: ', timeAfter - timeBefore);
        console.log('result.timeElapsed', result.timeElapsed);
        // predictLocation sneds back a prediction for each leaf node in the taxonomy
        // we filter out the ones with a score below 0.095, this is arbitrary
        const filteredResults = result.predictions.filter(
          (p) => p.score > 0.095
        );
        setResult(filteredResults);
      })
      .catch((err) => {
        console.log('getPredictionsForLocation Error', err);
      });
  }

  const contentSwitch = () => {
    if (viewStatus === VIEW_STATUS.NONE) {
      return (
        <View style={styles.center}>
          <Button
            title="Show camera"
            onPress={() => setViewStatus(VIEW_STATUS.CAMERA)}
          />
          <Button
            title="Show gallery"
            onPress={() => setViewStatus(VIEW_STATUS.GALLERY)}
          />
          <Text style={styles.text}>Confidence threshold (0.0-1.0):</Text>
          <View style={styles.row}>
            <Button
              title="-"
              onPress={() =>
                setConfidenceThreshold(
                  Math.round((confidenceThreshold - 0.1) * 10) / 10
                )
              }
            />
            <Text style={styles.text}>{confidenceThreshold}</Text>
            <Button
              title="+"
              onPress={() =>
                setConfidenceThreshold(
                  Math.round((confidenceThreshold + 0.1) * 10) / 10
                )
              }
            />
          </View>
          <Button
            title="Reset module state"
            onPress={() => InatVision.resetStoredResults()}
          />
          <Button
            title="Show geomodel"
            onPress={() => setViewStatus(VIEW_STATUS.GEOMODEL)}
          />
        </View>
      );
    } else if (viewStatus === VIEW_STATUS.CAMERA) {
      return renderCameraView();
    } else if (viewStatus === VIEW_STATUS.GALLERY) {
      return renderGalleryView();
    } else if (viewStatus === VIEW_STATUS.GEOMODEL) {
      return renderGeomodelView();
    } else {
      return <Text>Something went wrong</Text>;
    }
  };

  const renderGeomodelView = () => (
    <>
      <Button
        onPress={() => predictLocation(testLocationEurope)}
        title="Use geomodel in Europe"
      />
      <Button
        onPress={() => predictLocation(testLocationAmerica)}
        title="Use geomodel in America"
      />
      <Button
        onPress={() => predictLocation(testLocationEuropeNoElevation)}
        title="Use geomodel without elevation"
      />
      <Button onPress={() => setViewStatus(VIEW_STATUS.NONE)} title="Close" />
      {results && (
        <View>
          <Text style={styles.text}>Leaf taxa expected nearby:</Text>
          <Text style={styles.smallLabel}>
            {results.map((r) => r.name).toString()}
          </Text>
        </View>
      )}
    </>
  );

  const renderGalleryView = () => (
    <>
      <Button onPress={selectImage} title="Select image" />
      <Button onPress={async () => await getPhotos()} title="Get photos" />
      <Button onPress={() => setViewStatus(VIEW_STATUS.NONE)} title="Close" />
      <View style={styles.row}>
        {photos &&
          photos.edges &&
          photos.edges.length > 0 &&
          photos.edges.map((photo, index) => (
            <Pressable
              key={index}
              style={styles.photo}
              onPress={() => predict(photo.node.image.uri)}
            >
              <Image
                source={{ uri: photo.node.image.uri }}
                style={styles.photo}
              />
            </Pressable>
          ))}
      </View>
    </>
  );

  const renderCameraView = () => {
    return device != null && hasPermission ? (
      <View style={styles.cameraContainer}>
        <Camera
          style={styles.camera}
          device={device}
          isActive={true}
          frameProcessor={frameProcessor}
          enableZoomGesture
          pixelFormat={'yuv'}
          resizeMode="contain"
          enableFpsGraph={true}
          photoQualityBalance="quality"
          enableLocation={location.hasPermission}
          outputOrientation="device"
          onStarted={() => console.log('Camera started!')}
          onStopped={() => console.log('Camera stopped!')}
          onOutputOrientationChanged={(o) =>
            console.log(`Output orientation changed to ${o}!`)
          }
          onPreviewOrientationChanged={(o) =>
            console.log(`Preview orientation changed to ${o}!`)
          }
        />
        <View style={styles.row}>
          <Button
            onPress={toggleNegativeFilter}
            title={negativeFilter ? 'Negative Filter' : 'Positive Filter'}
          />
          <Button
            onPress={changeFilterByTaxonId}
            title={filterByTaxonId ? 'Plant filter' : 'No plant filter'}
          />
          <Button
            onPress={() => setViewStatus(VIEW_STATUS.NONE)}
            title="Close"
          />
          <Button
            onPress={toggleUseGeomodel}
            title={useGeomodel ? 'Disable Geomodel' : 'Enable Geomodel'}
          />
        </View>
      </View>
    ) : (
      <ActivityIndicator size="large" color="white" />
    );
  };

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.contentContainer}>{contentSwitch()}</View>
      {results &&
        results.map((result) => (
          <View key={result.name} style={styles.labels}>
            <Text style={styles.text}>{result.name}</Text>
            <Text style={styles.smallLabel}>taxon_id {result.taxon_id}</Text>
            <Text style={styles.smallLabel}>score {result.score}</Text>
            {!!result.spatial_class_id && (
              <Text style={styles.smallLabel}>
                spatial_class_id {result.spatial_class_id}
              </Text>
            )}
            {!!result.iconic_class_id && (
              <Text style={styles.smallLabel}>
                iconic_class_id {result.iconic_class_id}
              </Text>
            )}
          </View>
        ))}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'black',
  },
  contentContainer: {
    flex: 1,
    justifyContent: 'center',
    width: '100%',
  },
  cameraContainer: {
    flex: 1,
    width: '100%',
    height: '100%',
  },
  camera: {
    flex: 1,
  },
  labels: {
    position: 'absolute',
    top: 30,
    padding: 4,
    marginHorizontal: 20,
    backgroundColor: '#000000',
  },
  info: {
    position: 'absolute',
    bottom: 30,
    left: 4,
    padding: 4,
    marginHorizontal: 20,
    backgroundColor: '#000000',
  },
  text: {
    fontSize: 26,
    color: 'white',
    textAlign: 'center',
  },
  smallLabel: {
    padding: 4,
    marginHorizontal: 20,
    backgroundColor: '#000000',
    fontSize: 10,
    color: 'white',
    textAlign: 'center',
  },
  center: {
    alignItems: 'center',
  },
  textInput: {
    color: 'white',
    padding: 10,
    backgroundColor: 'grey',
    textAlign: 'center',
    width: 100,
  },
  row: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'center',
  },
  photo: {
    width: 74,
    height: 74,
    margin: 2,
  },
});
