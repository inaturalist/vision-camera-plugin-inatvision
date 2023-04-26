/* globals __inatVision */
import type { Frame } from 'react-native-vision-camera';

interface PredictionDetails {
  ancestor_ids: number[];
  name: string;
  rank: number;
  score: number;
  taxon_id: number;
}

interface Prediction {
  [rank: string]: PredictionDetails[];
}

/**
 * Returns an array of matching `ImageLabel`s for the given frame. *
 */
export function inatVision(
  frame: Frame,
  modelPath: string,
  taxonomyPath: string,
  // TODO: make this an optional parameter here and in the native code
  confidenceThreshold: string,
  filterByTaxonId: null | string,
  negativeFilter: null | boolean
): Prediction[] {
  'worklet';
  // @ts-expect-error Frame Processors are not typed.
  return __inatVision(
    frame,
    modelPath,
    taxonomyPath,
    confidenceThreshold,
    filterByTaxonId,
    negativeFilter
  );
}
