/* globals __inatVision */
import { NativeEventEmitter, NativeModules, Platform } from 'react-native';
import type { EmitterSubscription } from 'react-native';
import type { Frame } from 'react-native-vision-camera';

enum RANK {
  'stateofmatter' = 'stateofmatter',
  'kingdom' = 'kingdom',
  'phylum' = 'phylum',
  'class' = 'class',
  'order' = 'order',
  'family' = 'family',
  'genus' = 'genus',
  'species' = 'species',
}

enum RANK_LEVEL {
  'stateofmatter' = 100,
  'kingdom' = 70,
  'phylum' = 60,
  'class' = 50,
  'order' = 40,
  'family' = 30,
  'genus' = 20,
  'species' = 10,
}

interface Prediction {
  name: string;
  rank_level: RANK_LEVEL; // Android has
  score: number;
  taxon_id: number;
  ancestor_ids?: number[]; // TODO: this is Android only atm
  rank?: RANK; // TODO: this is Android only atm
  iconic_class_id?: number;
  spatial_class_id?: number;
}

export interface Return {
  predictions: Prediction[];
  uri?: string;
}

const supportedVersions = ['1.0', '2.3', '2.4' as const];

function optionsAreValid(options: Options | OptionsForImage): boolean {
  'worklet';
  if (!supportedVersions.includes(options.version)) {
    throw new Error('This model version is not supported.');
  }
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

interface Options {
  // Required
  version: string;
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
export function inatVision(frame: Frame, options: Options): Return {
  'worklet';
  optionsAreValid(options);
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
  version: string;
  modelPath: string;
  taxonomyPath: string;
  // Optional
  confidenceThreshold?: string;
}

/**
 * Function to call the computer vision model with a image from disk
 */
export function getPredictionsForImage(
  options: OptionsForImage
): Promise<Return> {
  optionsAreValid(options);
  return VisionCameraPluginInatVision.getPredictionsForImage(options);
}
