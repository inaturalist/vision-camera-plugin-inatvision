import { NativeEventEmitter, NativeModules, Platform } from 'react-native';
import type { EmitterSubscription } from 'react-native';
import { VisionCameraProxy } from 'react-native-vision-camera';
import type { Frame } from 'react-native-vision-camera';
import { Worklets } from 'react-native-worklets-core';
import type { ISharedValue } from 'react-native-worklets-core';

import { lookUpLocation } from './lookUpLocation';
import type { LocationLookup } from './lookUpLocation';

const plugin = VisionCameraProxy.initFrameProcessorPlugin('inatVision', {});

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

class INatVisionError extends Error {}
Object.defineProperty(INatVisionError.prototype, 'name', {
  value: 'INatVisionError',
});

interface State {
  eventListener: null | EmitterSubscription;
  storedResults: ISharedValue<Result[]>;
}

const state: State = {
  eventListener: null,
  storedResults: Worklets.createSharedValue([]),
};

/**
 *  Reset the stored results to an empty array
 */
export function resetStoredResults(): void {
  state.storedResults.value = [];
}

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

export interface Prediction {
  name: string;
  rank_level: RANK_LEVEL; // Android has
  score: number;
  combined_score: number;
  vision_score: number;
  geo_score: number | null;
  // Only present if taxonomy files have geo_thresholds
  geo_threshold?: number;
  taxon_id: number;
  ancestor_ids: number[];
  // TODO: this is only present in __inatVision iOS and Android, and getPredictionsForImage on Android
  rank?: RANK;
  // Only present for models of v2
  iconic_class_id?: number;
  // Only present for models of v2
  spatial_class_id?: number;
  // Only present in leaf predictions
  leaf_id?: number;
}

export interface ResultForImage {
  options: OptionsForImage;
  predictions: Prediction[];
  timeElapsed?: number; //iOS only
  commonAncestor?: Prediction;
}

export interface Result {
  options: Options;
  predictions: Prediction[];
  timestamp: number;
  /**
   *
   * The time spent on the native side for this prediction.
   * In seconds.
   */
  timeElapsed?: number; //iOS only
}

const supportedVersions = ['1.0', '2.3', '2.4', '2.13', '2.20', 'small_2'];

function locationIsValid(location: Location): boolean {
  'worklet';
  if (!location || !location.latitude || !location.longitude) {
    // have not used INatVisionError here because I can not test it due to issue #36
    throw new Error('location must have latitude and longitude set.');
  }
  return true;
}

function optionsAreValid(options: Options | OptionsForImage): boolean {
  'worklet';
  if (!supportedVersions.includes(options.version)) {
    throw new Error('This model version is not supported.');
  }
  if (options.confidenceThreshold) {
    if (
      isNaN(options.confidenceThreshold) ||
      options.confidenceThreshold < 0 ||
      options.confidenceThreshold > 100
    ) {
      // have not used INatVisionError here because I can not test it due to issue #36
      throw new Error(
        'confidenceThreshold must be a number between 0 and 100.'
      );
    }
  }
  if (options.cropRatio) {
    if (
      isNaN(options.cropRatio) ||
      options.cropRatio < 0 ||
      options.cropRatio > 1
    ) {
      // have not used INatVisionError here because I can not test it due to issue #36
      throw new Error('cropRatio must be a number between 0 and 1.');
    }
  }
  if (options.useGeomodel) {
    if (!options.location) {
      // have not used INatVisionError here because I can not test it due to issue #36
      throw new Error('location must be set when useGeomodel is true.');
    }
    locationIsValid(options.location);
  }
  return true;
}

function optionsAreValidForFrame(options: Options): boolean {
  'worklet';
  if (options.taxonomyRollupCutoff) {
    if (
      isNaN(options.taxonomyRollupCutoff) ||
      options.taxonomyRollupCutoff < 0 ||
      options.taxonomyRollupCutoff > 1
    ) {
      // have not used INatVisionError here because I can not test it due to issue #36
      throw new Error('taxonomyRollupCutoff must be a number between 0 and 1.');
    }
  }
  return optionsAreValid(options);
}

function optionsAreValidForImage(options: OptionsForImage): boolean {
  'worklet';
  return optionsAreValid(options);
}

/**
 * Scales certain score fields by 100
 * @param prediction A prediction object
 * @returns A copy of the prediction object with scaled scores
 */
function scalePrediction(p: Prediction): Prediction {
  'worklet';

  const prediction = { ...p };
  prediction.score = prediction.score * 100;
  // Duplicate the score into same key as iNatVisionAPI
  prediction.combined_score = prediction.score;
  prediction.vision_score = prediction.vision_score * 100;
  if (prediction.geo_score !== null) {
    prediction.geo_score = prediction.geo_score * 100;
  }
  if (
    prediction?.geo_threshold !== null &&
    prediction?.geo_threshold !== undefined
  ) {
    prediction.geo_threshold = prediction.geo_threshold * 100;
  }
  return prediction;
}

function handleResult(result: any, options: Options): Result {
  'worklet';

  // Add the options to the result
  result.options = options;
  // Add timestamp to the result
  result.timestamp = new Date().getTime();
  // Add the rank to the predictions if not present
  result.predictions = result.predictions.map((prediction: Prediction) => {
    // If there is ancestor_ids set, i.e. currently Android only use it
    let ancestorIds = prediction.ancestor_ids;
    // If not, get the ancestor ids for this prediction
    if (!ancestorIds) {
      ancestorIds = result.predictions
        // Filter to all predictions with higher rank level
        .filter((p: Prediction) => p.rank_level > prediction.rank_level)
        // Map their taxon_id
        .map((p: Prediction) => Number(p.taxon_id));
    }
    return {
      ...prediction,
      rank: prediction.rank
        ? prediction.rank
        : mapLevelToRank[prediction.rank_level],
      ancestor_ids: ancestorIds,
    };
  });

  // Store the result to module-wide state
  state.storedResults.value.push(result);
  const maxNumStoredResults = options.numStoredResults || 5;
  while (state.storedResults.value.length > maxNumStoredResults) {
    state.storedResults.value.shift();
  }

  let current: Result = result;
  const currentLastPrediction =
    current.predictions[current.predictions.length - 1];
  let currentScore = currentLastPrediction?.score || 0;

  const penaltyIncrement = 0.5 / (maxNumStoredResults - 1);
  // Select the best result from the stored results
  for (let i = state.storedResults.value.length - 1; i >= 0; i--) {
    const candidateResult = state.storedResults.value[i];
    if (!candidateResult) {
      break;
    }
    const candidateLastPrediction =
      candidateResult.predictions[candidateResult.predictions.length - 1];
    const candidateScore = candidateLastPrediction?.score || 0;

    const penalty =
      1 - penaltyIncrement * (state.storedResults.value.length - 1 - i);

    if (candidateScore * penalty > currentScore) {
      current = candidateResult;
      currentScore = candidateScore;
    }
  }

  const predictions = current.predictions
    // only KPCOFGS ranks qualify as "top" predictions
    // in the iNat taxonomy, KPCOFGS ranks are 70,60,50,40,30,20,10
    .filter((prediction) => prediction.rank_level % 10 === 0)
    .map((prediction) => scalePrediction(prediction))
    .filter(
      (prediction) => prediction.score > (options.confidenceThreshold || 0)
    );
  const handledResult = {
    ...current,
    predictions,
  };
  return handledResult;
}

export interface Location {
  /**
   *
   * The latitude of the location.
   */
  latitude: number;
  /**
   *
   * The longitude of the location.
   */
  longitude: number;
  /**
   *
   * The elevation of the location.
   */
  elevation?: number;
}

interface BaseOptions {
  // Required
  /**
   * The version of the model to use.
   */
  version: string;
  /**
   * The path to the computer vision model file.
   */
  modelPath: string;
  /**
   * The path to the taxonomy file.
   */
  taxonomyPath: string;
  // Optional
  /**
   * The confidence threshold for the predictions.
   *
   * From 0 - 100.
   */
  confidenceThreshold?: number;
  /**
   * *Android only.*
   *
   * Ratio to crop the center square.
   *
   * As a fraction of 1. E.g. 0.8 will crop the center 80% of the frame before sending it to the cv model.
   */
  cropRatio?: number;
  /**
   *
   * Whether to use the geomodel.
   */
  useGeomodel?: boolean;
  /**
   *
   * The location object used for geomodel prediction.
   */
  location?: Location;
  /**
   *
   * The path to the geomodel file.
   */
  geomodelPath?: string;
}

/**
 * Represents the options for a call to use the plugin to predict on a frame.
 */
interface Options extends BaseOptions {
  // Optional
  /**
   * The number of results to keep stored internally.
   *
   * Specifies the integer number of results to store internally that the plugin serves the best out of.
   * E.g. if the plugin is called with this number set to 5, the plugin will serve the best result out of the 5 stored previous results.
   * Setting this number to 0 or 1 will always return the current result (i.e. none or only one frame result will be stored at a time).
   */
  numStoredResults?: number;
  /**
   * A taxonomy rollup cutoff threshold.
   * This is supposed to be used mainly for testing purposes. The frame processor pipeline has an inbuilt
   * cutoff of combined top score * 0.001. Setting a value here will override the inbuilt cutoff.
   * As a fraction of 1. After computer vision predictions are returned, this value filters out all nodes with
   * a lower score for the calculation of the best branch or top predictions.
   */
  taxonomyRollupCutoff?: number;
  /**
   * *Android only.*
   *
   * The iconic taxon id to filter by.
   */
  filterByTaxonId?: null | string;
  /**
   * *Android only.*
   *
   * Wether to exclude the taxon set by filterByTaxonId or to only include it (and exclude all other).
   */
  negativeFilter?: null | boolean;
  // Patches
  /**
   * Currently, using react-native-vision-camera v3.9.1, Android does not support orientation changes.
   * So, we have to patch the orientation on Android. This takes in a string of the current device orientation
   * and then rotates the frame accordingly before it is used for processing.
   */
  patchedOrientationAndroid?: string;
}

export function getCellLocation(location: Location): LocationLookup {
  return lookUpLocation(location);
}

/**
 * Function to call the computer vision model with a frame from the camera
 * @param frame The frame to predict on.
 * @param options The options for the prediction.
 */
export function inatVision(frame: Frame, options: Options): Result {
  'worklet';
  if (plugin === undefined) {
    throw new INatVisionError("Couldn't find the 'inatVision' plugin.");
  }
  optionsAreValidForFrame(options);
  // @ts-expect-error Frame Processors are not typed.
  const result = plugin.call(frame, options);
  const handledResult: Result = handleResult(result, options);
  return handledResult;
}

export enum MODE {
  BEST_BRANCH = 'BEST_BRANCH',
  COMMON_ANCESTOR = 'COMMON_ANCESTOR',
}

export enum COMMON_ANCESTOR_RANK_TYPE {
  MAJOR = 'major',
  UNRESTRICTED = 'unrestricted',
}

interface OptionsForImage extends BaseOptions {
  /**
   * The uri of the image to predict on.
   */
  uri: string;
  /**
   * Mode of compiling the results.
   */
  mode?: MODE;
  /**
   * Experimental: The type of common ancestor rank to return.
   * Only used when mode is set to COMMON_ANCESTOR.
   */
  commonAncestorRankType?: COMMON_ANCESTOR_RANK_TYPE;
}

const HUMAN_TAXON_ID = 43584;
function limitLeafPredictionsThatIncludeHumans(
  predictions: Prediction[]
): Prediction[] {
  // If only one prediction, return original array
  if (predictions.length === 1) {
    return predictions;
  }
  // Find human prediction
  const humanIndex = predictions.findIndex(
    (p) => p.taxon_id === HUMAN_TAXON_ID
  );
  // If no humans, return original array
  // (also returns here if predictions is an empty array)
  if (humanIndex === -1) {
    return predictions;
  }

  // At this point there are multiple results and humans is one of them
  // If humans is first and has substantially higher score than next prediction
  // return only humans
  if (humanIndex === 0) {
    // TS complains about the object possibly being undefined, but we know it's not
    // @ts-ignore
    const humanPrediction: Prediction = predictions[0];
    const humanScore = humanPrediction.score;
    // TS complains about the object possibly being undefined, but we know it's not
    // @ts-ignore
    const nextScore = predictions[1].score;
    const humanScoreMargin = humanScore / nextScore;

    if (humanScoreMargin > 1.5) {
      return [humanPrediction];
    }
  }

  // Otherwise return empty array
  return [];
}

function commonAncestorFromPredictions(
  predictions: Prediction[],
  top15Leaves: Prediction[],
  commonAncestorRankType: COMMON_ANCESTOR_RANK_TYPE | undefined
): Prediction | undefined {
  // Get the top 15 leaf nodes with scores higher than top combined score * 0.01
  const topCombinedScore = top15Leaves[0]?.score || 0;
  const top15Cutoff = topCombinedScore * 0.01;
  // Filter out all leaf nodes with scores lower than top combined score * 0.01
  const top15FilteredLeaves = top15Leaves.filter((p) => p.score >= top15Cutoff);
  // Get quotient to normalize the top 15 scores
  const scoreSumOfTop15 = top15FilteredLeaves.reduce(
    (acc, p) => acc + p.score,
    0
  );
  const parentIds = new Set();
  top15FilteredLeaves.forEach((p) => {
    p.ancestor_ids.forEach((id) => parentIds.add(id));
  });
  const top15Parents = predictions.filter((p) => parentIds.has(p.taxon_id));
  // Normalize the top 15 scores
  // max 15 (s > ts * 0.01), normalized, leafs
  const top15FilteredLeavesNormalized = top15FilteredLeaves.map((p) => ({
    ...p,
    score: p.score / scoreSumOfTop15,
  }));
  // Normalize the top 15's parents by reaggregating the scores of their children
  // Map to store newly aggregated scores of parent nodes
  const aggregatedScores: {
    [key: number]: number;
  } = {};
  top15Parents.map((p) => {
    aggregatedScores[p.taxon_id] = 0;
  });
  // Re-aggregate the sum of scores for non-leaf nodes by summing the scores of their children
  top15FilteredLeavesNormalized.forEach((leaf) => {
    leaf.ancestor_ids.forEach((ancestorId) => {
      // @ts-ignore
      aggregatedScores[ancestorId] = aggregatedScores[ancestorId] + leaf.score;
    });
  });
  const top15ParentsNormalized = top15Parents.map((p) => ({
    ...p,
    score: aggregatedScores[p.taxon_id] || 0,
  }));
  // max 15 (s > ts * 0.01), normalized, leafs + parents
  const normalizedTop15 = [
    ...top15FilteredLeavesNormalized,
    ...top15ParentsNormalized,
  ];
  return commonAncestorFromAggregatedScores(
    normalizedTop15,
    commonAncestorRankType
  );
}

const commonAncestorScoreThreshold = 0.78;
const commonAncestorRankLevelMin = 20;
const commonAncestorRankLevelMax = 33;
function commonAncestorFromAggregatedScores(
  predictions: Prediction[],
  commonAncestorRankType: COMMON_ANCESTOR_RANK_TYPE | undefined
): Prediction | undefined {
  // As in the vision API:
  // # if using combined scores to aggregate, and there are taxa expected nearby,
  // # then add a query filter to only look at nearby taxa as common ancestor candidates
  const filterForNearby = predictions.some(
    (prediction) =>
      prediction.geo_score &&
      prediction.geo_threshold &&
      prediction.geo_score >= prediction.geo_threshold
  );
  // Filter and sort candidates
  const commonAncestorCandidates = predictions
    .filter(
      (prediction) =>
        prediction.score > commonAncestorScoreThreshold &&
        prediction.rank_level >= commonAncestorRankLevelMin &&
        (commonAncestorRankType === COMMON_ANCESTOR_RANK_TYPE.MAJOR
          ? prediction.rank_level % 10 === 0
          : commonAncestorRankType !== COMMON_ANCESTOR_RANK_TYPE.UNRESTRICTED
          ? prediction.rank_level <= commonAncestorRankLevelMax
          : true) &&
        (!filterForNearby ||
          (prediction.geo_score &&
            prediction.geo_threshold &&
            prediction.geo_score >= prediction.geo_threshold))
    )
    .sort((a, b) => a.rank_level - b.rank_level);
  const commonAncestor = commonAncestorCandidates[0];
  return commonAncestor;
}

/**
 * Function to call the computer vision model with a image from disk
 */
export function getPredictionsForImage(
  options: OptionsForImage
): Promise<ResultForImage> {
  optionsAreValidForImage(options);
  const newOptions = {
    ...options,
  };
  if (options.useGeomodel && options.location) {
    const locationLookup = lookUpLocation(options.location);
    newOptions.location = locationLookup;
  }
  return new Promise((resolve, reject) => {
    VisionCameraPluginInatVision.getPredictionsForImage(newOptions)
      .then((result: ResultForImage) => {
        if (newOptions?.mode === MODE.COMMON_ANCESTOR) {
          // From native we get all predictions (leaves and ancestors) that have
          // score > top score * 0.001, score & vision score is normalized
          const leafPredictions = result.predictions
            .filter((p) => p?.leaf_id !== undefined)
            .sort((a, b) => b.score - a.score);
          // max 100 (s > ts * 0.001), not normalized, leaf only
          const top100Leaves = leafPredictions.slice(0, 100);
          const top100 = limitLeafPredictionsThatIncludeHumans(top100Leaves);
          // max 15 (s > ts * 0.001), not normalized, leaf only
          const top15Leaves = top100.slice(0, 15);
          const commonAncestor = commonAncestorFromPredictions(
            result.predictions,
            top15Leaves,
            newOptions.commonAncestorRankType
          );
          // max 10 (s > ts * 0.001), not normalized, leaf only
          const top10 = top100.slice(0, 10);
          const top10WithScaledScores: Prediction[] = top10.map((prediction) =>
            scalePrediction(prediction)
          );
          const commonAncestorWithScaledScores = commonAncestor
            ? scalePrediction(commonAncestor)
            : undefined;
          const resultWithCommonAncestor = Object.assign({}, result, {
            predictions: top10WithScaledScores,
            commonAncestor: commonAncestorWithScaledScores,
          });
          resolve(resultWithCommonAncestor);
        } else {
          const predictions = result.predictions
            // only KPCOFGS ranks qualify as "top" predictions
            // in the iNat taxonomy, KPCOFGS ranks are 70,60,50,40,30,20,10
            .filter((prediction) => prediction.rank_level % 10 === 0)
            .map((prediction) => scalePrediction(prediction))
            .filter(
              (prediction) =>
                prediction.score > (newOptions.confidenceThreshold || 70)
            );
          const handledResult = {
            ...result,
            predictions,
          };
          resolve(handledResult);
        }
      })
      .catch((error: any) => {
        reject(error);
      });
  });
}

interface OptionsForLocation {
  // Required
  taxonomyPath: string;
  geomodelPath: string;
  location: Location;
}

/**
 * Function to call the geomodel with a given location
 */
export function getPredictionsForLocation(
  options: OptionsForLocation
): Promise<Result> {
  locationIsValid(options.location);
  const locationLookup = lookUpLocation(options.location);
  const newOptions = {
    ...options,
    location: locationLookup,
  };
  return VisionCameraPluginInatVision.getPredictionsForLocation(newOptions);
}
