import React, { useEffect, useState } from 'react';
import {
  StyleSheet,
  View,
  ActivityIndicator,
  Text,
  Platform,
} from 'react-native';
import { runOnJS } from 'react-native-reanimated';
import {
  Camera,
  useCameraDevices,
  useFrameProcessor,
} from 'react-native-vision-camera';
import RNFS from 'react-native-fs';

import * as InatVision from 'vision-camera-plugin-inatvision';

const modelFilenameAndroid = 'small_inception_tf1.tflite';
const taxonomyFilenameAndroid = 'small_export_tax.csv';
const modelFilenameIOS = 'small_inception_tf1.mlmodelc';
const taxonomyFilenameIOS = 'small_export_tax.json';

export default function App() {
  const [hasPermission, setHasPermission] = useState(false);
  const [results, setResult] = useState([]);
  const [filterByTaxonId, setFilterByTaxonId] = useState(null);
  const [negativeFilter, setNegativeFilter] = useState(null);

  const devices = useCameraDevices();
  const device = devices.back;

  const confidenceThreshold = '0.7';

  const toggleNegativeFilter = () => {
    setNegativeFilter(!negativeFilter);
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
      const status = await Camera.requestCameraPermission();
      setHasPermission(status === 'authorized');
    })();
  }, []);

  useEffect(() => {
    if (Platform.OS === 'ios') {
      return;
    }

    InatVision.addLogListener((event) => {
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
        const cvResults = InatVision.inatVision(
          frame,
          modelPath,
          taxonomyPath,
          confidenceThreshold,
          filterByTaxonId,
          negativeFilter
        );
        console.log('cvResults :>> ', cvResults);
        let predictions = [];
        if (Platform.OS === 'ios') {
          predictions = cvResults;
        } else {
          predictions = cvResults.map((result) => {
            const rank = Object.keys(result)[0];
            const prediction = result[rank][0];
            prediction.rank = rank;
            return prediction;
          });
        }
        runOnJS(setResult)(predictions);
      } catch (classifierError) {
        // TODO: needs to throw Exception in the native code for it to work here?
        console.log(`Error: ${classifierError}`);
      }
    },
    [confidenceThreshold, filterByTaxonId, negativeFilter]
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
            frameProcessorFps={1}
          />
          <Text style={styles.text} onPress={toggleNegativeFilter}>
            {negativeFilter ? 'Negative Filter' : 'Positive Filter'}
          </Text>
          <Text style={styles.text} onPress={changeFilterByTaxonId}>
            {filterByTaxonId ? 'Plant filter' : 'No filter'}
          </Text>
          {results.map((result: { rank: string; name: string }) => {
            return (
              <Text key={result.rank} style={[styles.text, styles.label]}>
                {result.name}
              </Text>
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
  text: {
    padding: 4,
    marginHorizontal: 20,
    backgroundColor: '#000000',
    fontSize: 26,
    color: 'white',
    textAlign: 'center',
  },
  label: {
    position: 'absolute',
    top: 48,
  },
});
