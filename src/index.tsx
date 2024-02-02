import { NativeEventEmitter, NativeModules, Platform } from 'react-native';
import type { EmitterSubscription } from 'react-native';
import { VisionCameraProxy, Frame } from 'react-native-vision-camera';
import { createResizePlugin } from 'vision-camera-resize-plugin';

const { resize } = createResizePlugin();

const plugin = VisionCameraProxy.initFrameProcessorPlugin('inatVision');

export interface PredictionDetails {
  ancestor_ids: number[];
  name: string;
  rank: number;
  score: number;
  taxon_id: number;
  iconic_class_id?: number;
  spatial_class_id?: number;
}

export interface Prediction {
  [rank: string]: PredictionDetails[];
}

interface Options {
  // Required
  version: string;
  modelPath: string;
  taxonomyPath: string;
  // Optional
  confidenceThreshold?: string;
  filterByTaxonId?: string;
  negativeFilter?: boolean;
  // Patches
  patchedOrientationAndroid?: string;
}

interface OptionsWithResizedFrame extends Options {
  resizedFrame?: Uint8Array | Float32Array | undefined;
}

/**
 * Returns an array of matching `ImageLabel`s for the given frame. *
 */
export function inatVision(frame: Frame, args: Options): any {
  'worklet';
  if (!['1.0', '2.3', '2.4'].includes(args.version)) {
    throw new Error('This model version is not supported.');
  }
  if (resize === undefined) {
    throw new Error("Couldn't find the 'vision-camera-resize-plugin' plugin.");
  }
  let resized;
  // Use a the resize plugin to resize the frame to the expected input size on Android
  // On iOS, the frame is center-cropped and resized to 299x299 in the native code using the CoreML API
  if (Platform.OS === 'android') {
    resized = resize(frame, {
      scale: {
        width: 299,
        height: 299,
      },
      pixelFormat: 'rgb',
      dataType: args.version === '1.0' ? 'float32' : 'uint8',
    });
  }

  if (plugin === undefined) {
    throw new Error("Couldn't find the 'inatVision' plugin.");
  }
  const options: OptionsWithResizedFrame = {
    ...args,
    resizedBuffer: resized?.buffer,
  };
  return plugin.call(frame, options);
}

const LINKING_ERROR =
  `The package 'vision-camera-plugin-inatvision' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' });

const VisionCameraPluginInatVision = NativeModules.VisionCameraPluginInatVision
  ? NativeModules.VisionCameraPluginInatVision
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

interface State {
  eventListener: null | EmitterSubscription;
}

const state: State = {
  eventListener: null,
};

/**
 *  Adds a listener for the camera log event
 */
export function addLogListener(callback: Function): void {
  // Remove the previous listener if it exists
  if (state.eventListener) {
    state.eventListener.remove();
  }
  // Register the listener
  const eventEmitter = new NativeEventEmitter(VisionCameraPluginInatVision);
  state.eventListener = eventEmitter.addListener('CameraLog', (event) => {
    callback(event);
  });
}

/**
 *  Removes the listener
 */
export function removeLogListener(): void {
  // Remove the listener if it exists
  if (!state.eventListener) {
    return;
  }
  state.eventListener.remove();
}

interface OptionsForImage {
  uri: string;
  version: string;
  modelPath: string;
  taxonomyPath: string;
}

/**
 * Function to call the computer vision model with a image from disk
 */
export function getPredictionsForImage(options: OptionsForImage) {
  return VisionCameraPluginInatVision.getPredictionsForImage(options);
}
