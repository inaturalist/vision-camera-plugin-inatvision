/* globals __inatVision */
import { NativeEventEmitter, NativeModules, Platform } from 'react-native';
import type { EmitterSubscription } from 'react-native';
import type { Frame } from 'react-native-vision-camera';

enum RANK {
  'stateofmatter' = 'stateofmatter',
  'kingdom' = 'kingdom',
  'subkingdom' = 'subkingdom',
  'phylum' = 'phylum',
  'subphylum' = 'subphylum',
  'superclass' = 'superclass',
  'class' = 'class',
  'subclass' = 'subclass',
  'infraclass' = 'infraclass',
  'superorder' = 'superorder',
  'order' = 'order',
  'suborder' = 'suborder',
  'infraorder' = 'infraorder',
  'parvorder' = 'parvorder',
  'zoosection' = 'zoosection',
  'zoosubsection' = 'zoosubsection',
  'superfamily' = 'superfamily',
  'epifamily' = 'epifamily',
  'family' = 'family',
  'subfamily' = 'subfamily',
  'supertribe' = 'supertribe',
  'tribe' = 'tribe',
  'subtribe' = 'subtribe',
  'genus' = 'genus',
  'subgenus' = 'subgenus',
  'section' = 'section',
  'subsection' = 'subsection',
  'species' = 'species',
  'subspecies' = 'subspecies',
}

enum RANK_LEVEL {
  'stateofmatter' = 100,
  'kingdom' = 70,
  'subkingdom' = 67,
  'phylum' = 60,
  'subphylum' = 57,
  'superclass' = 53,
  'class' = 50,
  'subclass' = 47,
  'infraclass' = 45,
  'superorder' = 43,
  'order' = 40,
  'suborder' = 37,
  'infraorder' = 35,
  'parvorder' = 34.5,
  'zoosection' = 34,
  'zoosubsection' = 33.5,
  'superfamily' = 33,
  'epifamily' = 32,
  'family' = 30,
  'subfamily' = 27,
  'supertribe' = 26,
  'tribe' = 25,
  'subtribe' = 24,
  'genus' = 20,
  'subgenus' = 15,
  'section' = 13,
  'subsection' = 12,
  'species' = 10,
  'subspecies' = 5,
}

const mapLevelToRank = {
  100: RANK.stateofmatter,
  70: RANK.kingdom,
  67: RANK.subkingdom,
  60: RANK.phylum,
  57: RANK.subphylum,
  53: RANK.superclass,
  50: RANK.class,
  47: RANK.subclass,
  45: RANK.infraclass,
  43: RANK.superorder,
  40: RANK.order,
  37: RANK.suborder,
  35: RANK.infraorder,
  34.5: RANK.parvorder,
  34: RANK.zoosection,
  33.5: RANK.zoosubsection,
  33: RANK.superfamily,
  32: RANK.epifamily,
  30: RANK.family,
  27: RANK.subfamily,
  26: RANK.supertribe,
  25: RANK.tribe,
  24: RANK.subtribe,
  20: RANK.genus,
  15: RANK.subgenus,
  13: RANK.section,
  12: RANK.subsection,
  10: RANK.species,
  5: RANK.subspecies,
};

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
