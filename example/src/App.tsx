import React, { useEffect, useState } from 'react';
import { StyleSheet, View, ActivityIndicator, Text } from 'react-native';
import { runOnJS } from 'react-native-reanimated';
import {
  Camera,
  useCameraDevices,
  useFrameProcessor,
} from 'react-native-vision-camera';
import RNFS from 'react-native-fs';

import { inatVision } from 'vision-camera-plugin-inatvision';

const modelFilename = 'small_inception_tf1.tflite';
const taxonomyFilename = 'small_export_tax.csv';

export default function App() {
  const [hasPermission, setHasPermission] = useState(false);
  const [results, setResult] = useState([]);

  const devices = useCameraDevices();
  const device = devices.back;

  useEffect(() => {
    (async () => {
      const status = await Camera.requestCameraPermission();
      setHasPermission(status === 'authorized');
    })();
  }, []);

  useEffect(() => {
    (async () => {
      await RNFS.copyFileAssets(
        modelFilename,
        `${RNFS.DocumentDirectoryPath}/${modelFilename}`,
      );
      await RNFS.copyFileAssets(
        taxonomyFilename,
        `${RNFS.DocumentDirectoryPath}/${taxonomyFilename}`,
      );
    })();
  }, []);

  const frameProcessor = useFrameProcessor(
    (frame) => {
      'worklet';
      const modelPath = `${RNFS.DocumentDirectoryPath}/${modelFilename}`;
      const taxonomyPath = `${RNFS.DocumentDirectoryPath}/${taxonomyFilename}`;

      const results = inatVision(frame, modelPath, taxonomyPath);
      const predictions = results.map((result) => {
        const rank = Object.keys(result)[0];
        const prediction = result[rank][0];
        prediction.rank = rank;
        return prediction;
      });
      runOnJS(setResult)(predictions);
    },
    []
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
            frameProcessorFps={3}
          />
          {results.map((result: { rank: string, name: string}) => {
            return (
              <Text
                key={result.rank}
                style={styles.text}
              >
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
    position: 'absolute',
    top: 48,
    padding: 4,
    marginHorizontal: 20,
    backgroundColor: '#000000',
    fontSize: 26,
    color: 'white',
    textAlign: 'center',
  },
});
