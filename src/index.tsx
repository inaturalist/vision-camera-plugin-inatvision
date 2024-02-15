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
  iconic_class_id?: number;
  spatial_class_id?: number;
}

export interface Prediction {
  [rank: string]: PredictionDetails[];
}

enum SupportedVersions {
  V1_0 = '1.0',
  V2_3 = '2.3',
  V2_4 = '2.4',
}

interface Options {
  // Required
  version: SupportedVersions;
  modelPath: string;
  taxonomyPath: string;
  // Optional
  confidenceThreshold?: string;
  filterByTaxonId?: null | string;
  negativeFilter?: null | boolean;
}

/**
 * Returns an array of matching `ImageLabel`s for the given frame. *
 */
export function inatVision(frame: Frame, options: Options): Prediction[] {
  'worklet';
  if (!Object.values(SupportedVersions).includes(options.version)) {
    throw new Error('This model version is not supported.');
  }
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

class INatVisionError extends Error {}
Object.defineProperty(INatVisionError.prototype, 'name', {
  value: 'INatVisionError',
});

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
  // Required
  uri: string;
  version: SupportedVersions;
  modelPath: string;
  taxonomyPath: string;
  // Optional
  confidenceThreshold?: string;
}

function optionsForImageAreValid(options: OptionsForImage) {
  if (options.confidenceThreshold) {
    const confidenceThreshold = parseFloat(options.confidenceThreshold);
    if (
      isNaN(confidenceThreshold) ||
      confidenceThreshold < 0 ||
      confidenceThreshold > 1
    ) {
      throw new INatVisionError(
        'getPredictionsForImage option confidenceThreshold must be a string for a number between 0 and 1.'
      );
    }
  }
  return true;
}

/**
 * Function to call the computer vision model with a image from disk
 */
export function getPredictionsForImage(options: OptionsForImage) {
  optionsForImageAreValid(options);
  return VisionCameraPluginInatVision.getPredictionsForImage(options);
}
