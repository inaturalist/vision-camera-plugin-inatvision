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

interface ImageLabel {
  predictions: Prediction[];
}

/**
 * Returns an array of matching `ImageLabel`s for the given frame. *
 */
export function inatVision( frame: Frame, modelPath: string, taxonomyPath: string ): ImageLabel[] {
  "worklet";
  // @ts-expect-error Frame Processors are not typed.
  return __inatVision( frame, modelPath, taxonomyPath );
}
