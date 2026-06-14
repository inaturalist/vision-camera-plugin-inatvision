import { VisionCameraProxy } from 'react-native-vision-camera';

import { inatVision, resetStoredResults } from '../index';

const mockFrame = {
  width: 100,
  height: 100,
  orientation: 'portrait',
  base64: 'base64',
};

const baseOptions = {
  version: '1.0',
  modelPath: '/model',
  taxonomyPath: '/taxonomy',
  confidenceThreshold: 0,
};

const pluginCall = () =>
  VisionCameraProxy.initFrameProcessorPlugin.mock.results[0].value.call;

const mockNativeResult = (score) => ({
  predictions: [
    {
      name: 'Test species',
      rank_level: 10,
      score,
      vision_score: score,
      geo_score: null,
      taxon_id: 1,
      ancestor_ids: [],
    },
  ],
});

function runTwoFrames(numStoredResults) {
  pluginCall()
    .mockReturnValueOnce(mockNativeResult(0.9))
    .mockReturnValueOnce(mockNativeResult(0.1));

  inatVision(mockFrame, { ...baseOptions, numStoredResults });
  return inatVision(mockFrame, { ...baseOptions, numStoredResults });
}

describe('inatVision', () => {
  beforeEach(() => {
    resetStoredResults();
  });

  it('should not throw an error when version is supported', () => {
    pluginCall().mockReturnValue(mockNativeResult(0.5));

    expect(() => inatVision(mockFrame, baseOptions)).not.toThrowError(
      'This model version is not supported.',
    );
  });

  it('should throw an error when version is not supported', () => {
    expect(() =>
      inatVision(mockFrame, { ...baseOptions, version: '0.9' }),
    ).toThrowError('This model version is not supported.');
  });
});

describe('numStoredResults', () => {
  beforeEach(() => {
    resetStoredResults();
  });

  it.each([0, 1])(
    'returns the current frame when numStoredResults is %i, even if a prior frame scored higher',
    (numStoredResults) => {
      const result = runTwoFrames(numStoredResults);

      expect(result.predictions[0].score).toBe(10);
    },
  );

  it('applies temporal smoothing when numStoredResults is 5', () => {
    const result = runTwoFrames(5);

    // Prior high-confidence frame (0.9) beats the current weak frame (0.1) after penalty
    expect(result.predictions[0].score).toBe(90);
  });
});
