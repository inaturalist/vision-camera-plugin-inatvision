import React, { useEffect, useState } from 'react';
import { StyleSheet, View, ActivityIndicator } from 'react-native';
import { useSharedValue } from 'react-native-reanimated';
import {
  Camera,
  useCameraDevices,
  useFrameProcessor,
} from 'react-native-vision-camera';
import RNFS from 'react-native-fs';

import { inatVision } from 'vision-camera-plugin-inatvision';

import { Label } from './components/Label';

const modelFilename = 'small_inception_tf1.tflite';
const taxonomyFilename = 'small_export_tax.csv';

export default function App() {
  const [hasPermission, setHasPermission] = useState(false);
  const currentLabel = useSharedValue('');

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
      const prediction = results.predictions[0];
      const rank = Object.keys(prediction)[0];
      const predictionDetails = prediction[rank];
      currentLabel.value = rank + ": " + predictionDetails[0]?.name;
    },
    [currentLabel]
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
          <Label sharedValue={currentLabel} />
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
});
