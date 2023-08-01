/* globals __inatVision */
import { NativeEventEmitter, NativeModules, Platform } from 'react-native';
import type { EmitterSubscription } from 'react-native';
import type { Frame } from 'react-native-vision-camera';

interface PredictionDetails {
  ancestor_ids: number[];
  name: string;
  rank: number;
  score: number;
  taxon_id: number;
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
  // TODO: make this an optional parameter here and in the native code
  confidenceThreshold?: string;
  filterByTaxonId?: null | string;
  negativeFilter?: null | boolean;
}

/**
 * Returns an array of matching `ImageLabel`s for the given frame. *
 */
export function inatVision(frame: Frame, options: Options): Prediction[] {
  'worklet';
  // @ts-expect-error Frame Processors are not typed.
  return __inatVision(frame, options);
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
