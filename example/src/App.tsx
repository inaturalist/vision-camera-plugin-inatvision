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
import { Worklets } from 'react-native-worklets-core';
import * as InatVision from 'vision-camera-plugin-inatvision';

const modelFilenameAndroid = 'small_inception_tf1.tflite';
const taxonomyFilenameAndroid = 'small_export_tax.csv';
const modelFilenameIOS = 'small_inception_tf1.mlmodelc';
const taxonomyFilenameIOS = 'small_export_tax.json';
const modelVersion = '1.0';

export default function App() {
  const { hasPermission, requestPermission } = useCameraPermission();

  const [results, setResult] = useState<any[]>([]);
  const [filterByTaxonId, setFilterByTaxonId] = useState<undefined | string>(
    undefined
  );
  const [negativeFilter, setNegativeFilter] = useState(false);

  const device = useCameraDevice('back');

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
      const modelPath =
        Platform.OS === 'ios'
          ? `${RNFS.DocumentDirectoryPath}/${modelFilenameIOS}`
          : `${RNFS.DocumentDirectoryPath}/${modelFilenameAndroid}`;
      const taxonomyPath =
        Platform.OS === 'ios'
          ? `${RNFS.DocumentDirectoryPath}/${taxonomyFilenameIOS}`
          : `${RNFS.DocumentDirectoryPath}/${taxonomyFilenameAndroid}`;
      try {
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

  return (
    <View style={styles.container}>
      {device != null && hasPermission ? (
        <>
          <Camera
            style={styles.camera}
            device={device}
            isActive={true}
            frameProcessor={frameProcessor}
            enableZoomGesture
            pixelFormat={Platform.OS === 'ios' ? 'native' : 'yuv'}
          />
          <Text style={styles.text} onPress={toggleNegativeFilter}>
            {negativeFilter ? 'Negative Filter' : 'Positive Filter'}
          </Text>
          <Text style={styles.text} onPress={changeFilterByTaxonId}>
            {filterByTaxonId ? 'Plant filter' : 'No filter'}
          </Text>
          {results.map((result) => {
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
        </>
      ) : (
        <ActivityIndicator size="large" color="white" />
      )}
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
