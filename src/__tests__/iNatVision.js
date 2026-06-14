import { inatVision } from '../index';

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
describe('inatVision', () => {
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
