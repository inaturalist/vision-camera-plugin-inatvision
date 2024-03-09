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
  TextInput,
  View,
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
  interface Result {
    name: string;
    score: number;
    taxon_id: number;
    spatial_class_id?: number;
    iconic_class_id?: number;
  }
  const { hasPermission, requestPermission } = useCameraPermission();
  const [results, setResult] = useState<Result[]>([]);
  const [elapsed, setElapsed] = useState<number>(0);
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
  const [confidenceThreshold, setConfidenceThreshold] = useState<string>('0.7');

  const device = useCameraDevice('back');

  const [photos, getPhotos] = useCameraRoll();

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

  const handleElapsed = Worklets.createRunInJsFn((newElapsed: number) => {
    setElapsed(newElapsed);
  });

  const frameProcessor = useFrameProcessor(
    (frame) => {
      'worklet';
      try {
        const timeBefore = new Date().getTime();
        const cvResult = InatVision.inatVision(frame, {
          version: modelVersion,
          modelPath,
          taxonomyPath,
          confidenceThreshold,
          filterByTaxonId,
          negativeFilter,
          numStoredResults: 4,
          cropRatio: 0.9,
          patchedOrientationAndroid: 'portrait',
        });
        const timeAfter = new Date().getTime();
        console.log('time taken ms: ', timeAfter - timeBefore);
        console.log('age of result: ', timeAfter - cvResult.timestamp);

        handleResults(cvResult.predictions);
        handleElapsed(timeAfter - cvResult.timestamp);
      } catch (classifierError) {
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
    })
      .then((result) => {
        const timeAfter = new Date().getTime();
        console.log('time taken ms: ', timeAfter - timeBefore);
        console.log('Result', JSON.stringify(result));
        setResult(result.predictions);
      })
      .catch((err) => {
        console.log('Error', err);
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
          <TextInput
            value={confidenceThreshold?.toString() || ''}
            onChangeText={(value) => {
              const valueAsNumber = parseFloat(value);
              if (valueAsNumber < 0 || valueAsNumber > 1) {
                Alert.alert(
                  'Nope',
                  'Confidence threshold must be between 0 and 1'
                );
                setConfidenceThreshold(confidenceThreshold);
                return;
              }
              setConfidenceThreshold(value);
            }}
            style={styles.textInput}
          />
        </View>
      );
    } else if (viewStatus === VIEW_STATUS.CAMERA) {
      return renderCameraView();
    } else {
      return renderGalleryView();
    }
  };

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
          pixelFormat={Platform.OS === 'ios' ? 'native' : 'yuv'}
          resizeMode="contain"
          // As of vision-camera@3.9.0.beta.4, this seems to be necessary to avoid stuttering on Pixel
          // On Samsung this might cause some crashes though, so in production we might have to
          // selectively enable this based on the device model
          enableGpuBuffers={true}
          enableFpsGraph={true}
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
            <Text style={styles.smallLabel}>
              spatial_class_id {result.spatial_class_id}
            </Text>
            <Text style={styles.smallLabel}>
              iconic_class_id {result.iconic_class_id}
            </Text>
          </View>
        ))}
      {!!elapsed && (
        <View style={styles.info}>
          <Text style={styles.smallLabel}>
            Time since result: {Math.round(elapsed / 1000)}s
          </Text>
        </View>
      )}
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
