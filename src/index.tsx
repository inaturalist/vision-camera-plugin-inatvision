/* globals __inatVision */
import type { Frame } from 'react-native-vision-camera';

interface ImageLabel {
  /**
   * A label describing the image, in english.
   */
  label: string;
  /**
   * A floating point number from 0 to 1, describing the confidence (percentage).
   */
  confidence: number;
}

/**
 * Returns an array of matching `ImageLabel`s for the given frame. *
 */
export function inatVision( frame: Frame, modelFilename: string, taxonomyFilename: string ): ImageLabel[] {
  "worklet";
  // @ts-expect-error Frame Processors are not typed.
  return __inatVision( frame, modelFilename, taxonomyFilename );
}
