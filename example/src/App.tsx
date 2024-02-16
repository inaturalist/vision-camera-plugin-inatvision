import React, { useEffect, useState } from 'react';
import {
  StyleSheet,
  View,
  ActivityIndicator,
  Text,
  Platform,
} from 'react-native';
import {
  Camera,
  useCameraDevice,
  useFrameProcessor,
  useCameraPermission,
} from 'react-native-vision-camera';
import RNFS from 'react-native-fs';
import { launchImageLibrary } from 'react-native-image-picker';
import { useCameraRoll } from '@react-native-camera-roll/camera-roll';
import { Worklets } from 'react-native-worklets-core';
import * as InatVision from 'vision-camera-plugin-inatvision';

const modelFilenameAndroid = 'small_inception_tf1.tflite';
const taxonomyFilenameAndroid = 'small_export_tax.csv';
const modelFilenameIOS = 'small_inception_tf1.mlmodelc';
const taxonomyFilenameIOS = 'small_export_tax.json';
const modelVersion = '1.0';

const modelPath =
  Platform.OS === 'ios'
    ? `${RNFS.DocumentDirectoryPath}/${modelFilenameIOS}`
    : `${RNFS.DocumentDirectoryPath}/${modelFilenameAndroid}`;
const taxonomyPath =
  Platform.OS === 'ios'
    ? `${RNFS.DocumentDirectoryPath}/${taxonomyFilenameIOS}`
    : `${RNFS.DocumentDirectoryPath}/${taxonomyFilenameAndroid}`;

export default function App() {
  const { hasPermission, requestPermission } = useCameraPermission();

  const [results, setResult] = useState<any[]>([]);
  const [filterByTaxonId, setFilterByTaxonId] = useState<undefined | string>(
    undefined
  );
  const [negativeFilter, setNegativeFilter] = useState(false);

  enum VIEW_STATUS {
    NONE,
    CAMERA,
    GALLERY,
  }
  const [viewStatus, setViewStatus] = useState<VIEW_STATUS>(VIEW_STATUS.NONE);

  const device = useCameraDevice('back');

  const [photos, getPhotos] = useCameraRoll();

  const confidenceThreshold = '0.7';

  const toggleNegativeFilter = () => {
    setNegativeFilter(!negativeFilter);
  };

  const changeFilterByTaxonId = () => {
    if (!filterByTaxonId) {
      setFilterByTaxonId('47126');
    } else {
      setFilterByTaxonId(undefined);
    }
  };

  useEffect(() => {
    (async () => {
      requestPermission();
    })();
  }, [requestPermission]);

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
          console.log(`error moving model file from`, error);
        });
      RNFS.copyFile(
        `${RNFS.MainBundlePath}/${taxonomyFilenameIOS}`,
        `${RNFS.DocumentDirectoryPath}/${taxonomyFilenameIOS}`
      )
        .then((result) => {
          console.log(`moved file from`, result);
        })
        .catch((error) => {
          console.log(`error moving file from`, error);
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
      })();
    }
  }, []);

  const handleResults = Worklets.createRunInJsFn((predictions: any[]) => {
    setResult(predictions);
  });

  const frameProcessor = useFrameProcessor(
    (frame) => {
      'worklet';
      try {
        const timeNow = new Date().getTime();
        const cvResults: InatVision.Prediction[] | undefined =
          InatVision.inatVision(frame, {
            version: modelVersion,
            modelPath,
            taxonomyPath,
            confidenceThreshold,
            filterByTaxonId,
            negativeFilter,
            patchedOrientationAndroid: 'portrait',
          });
        const timeAfter = new Date().getTime();
        console.log('time taken ms: ', timeAfter - timeNow);
        console.log('cvResults :>> ', cvResults);
        if (!cvResults) {
          return;
        }
        let predictions = [];
        if (Platform.OS === 'ios') {
          predictions = cvResults;
        } else {
          predictions = cvResults.map((result) => {
            const rank = Object.keys(result)[0];
            if (!rank || !result[rank]) {
              return result;
            }
            const rankPredictions: any = result[rank];
            const prediction = rankPredictions[0];
            prediction.rank = rank;
            return prediction;
          });
        }
        handleResults(predictions);
      } catch (classifierError) {
        // TODO: needs to throw Exception in the native code for it to work here?
        console.log(`Error: ${classifierError}`);
      }
    },
    [confidenceThreshold, filterByTaxonId, negativeFilter, handleResults]
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
          const uri = Platform.OS === 'ios' ? asset.uri : asset.originalPath;
          console.log('Image URI: ', uri);
          predict(uri);
        }
      }
    );
  }

  function predict(uri: string) {
    InatVision.getPredictionsForImage({
      uri,
      version: modelVersion,
      modelPath,
      taxonomyPath,
    })
      .then((result) => {
        console.log('Result', JSON.stringify(result));
        setResult(Platform.OS === 'android' ? result.predictions : result);
      })
      .catch((err) => {
        console.log('Error', err);
      });
  }

  const contentSwitch = () => {
    if (viewStatus === VIEW_STATUS.NONE) {
      return (
        <>
          <Text
            style={styles.text}
            onPress={() => setViewStatus(VIEW_STATUS.CAMERA)}
          >
            {'Show camera'}
          </Text>
          <Text
            style={styles.text}
            onPress={() => setViewStatus(VIEW_STATUS.GALLERY)}
          >
            {'Show gallery'}
          </Text>
        </>
      );
    } else if (viewStatus === VIEW_STATUS.CAMERA) {
      return renderCameraView();
    } else {
      return renderGalleryView();
    }
  };

  const renderGalleryView = () => {
    return (
      <>
        <Text style={styles.text} onPress={selectImage}>
          {'Select image'}
        </Text>
        <Text style={styles.text} onPress={async () => await getPhotos()}>
          {'Get Photos'}
        </Text>
        {photos &&
          photos.edges &&
          photos.edges.length > 0 &&
          photos.edges.map((photo, index) => (
            <Text
              key={index}
              style={styles.text}
              onPress={() => predict(photo.node.image.uri)}
            >
              {index}
            </Text>
          ))}
      </>
    );
  };

  const renderCameraView = () => {
    return device != null && hasPermission ? (
      <>
        <Camera
          style={styles.camera}
          device={device}
          isActive={true}
          frameProcessor={frameProcessor}
          enableZoomGesture
          pixelFormat={Platform.OS === 'ios' ? 'native' : 'yuv'}
          resizeMode="contain"
          // As of vision-camera@3.9.0.beta.4, this seems to be necessary to avoid stuttering on Pixel
          // On Samsung this might cause some crashes though, so in production we might have to
          // selectively enable this based on the device model
          enableGpuBuffers={true}
          enableFpsGraph={true}
        />
        <Text style={styles.text} onPress={toggleNegativeFilter}>
          {negativeFilter ? 'Negative Filter' : 'Positive Filter'}
        </Text>
        <Text style={styles.text} onPress={changeFilterByTaxonId}>
          {filterByTaxonId ? 'Plant filter' : 'No filter'}
        </Text>
      </>
    ) : (
      <ActivityIndicator size="large" color="white" />
    );
  };

  return (
    <View style={styles.container}>
      {contentSwitch()}
      {results &&
        results.map((result: InatVision.Prediction) => {
          return (
            <View key={result.rank} style={styles.labels}>
              <Text style={styles.text}>{result.name}</Text>
              <Text style={styles.smallLabel}>
                spatial_class_id {result.spatial_class_id}
              </Text>
              <Text style={styles.smallLabel}>
                iconic_class_id {result.iconic_class_id}
              </Text>
            </View>
          );
        })}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'black',
  },
  camera: {
    flex: 1,
    width: '100%',
  },
  labels: {
    position: 'absolute',
    top: 30,
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
});
