import { NativeModules } from 'react-native';

import { getPredictionsForImage, MODE } from '../index';

const correctOptions = {
  uri: 'testUri',
  version: '1.0',
  modelPath: 'testModelPath',
  taxonomyPath: 'testTaxonomyPath',
  confidenceThreshold: 50,
  cropRatio: 0.8,
};

describe('getPredictionsForImage', () => {
  it('should not throw an error when options are valid', () => {
    const options = correctOptions;

    expect(() => getPredictionsForImage(options)).not.toThrowError();
  });
});

describe('common ancestor mode', () => {
  it('should not throw an error when options are valid', () => {
    const options = { ...correctOptions, mode: 'COMMON_ANCESTOR' };

    expect(() => getPredictionsForImage(options)).not.toThrowError();
  });
});

describe('best branch mode', () => {
  it('should not throw an error when options are valid', () => {
    const options = { ...correctOptions, mode: 'BEST_BRANCH' };

    expect(() => getPredictionsForImage(options)).not.toThrowError();
  });
});

describe('confidenceThreshold', () => {
  it('should throw an error when confidenceThreshold is not a number', () => {
    const options = {
      ...correctOptions,
      confidenceThreshold: 'invalid',
    };

    expect(() => getPredictionsForImage(options)).toThrowError(
      'confidenceThreshold must be a number between 0 and 100.',
    );
  });

  it('should throw an error when confidenceThreshold is less than 0', () => {
    const options = {
      ...correctOptions,
      confidenceThreshold: -50,
    };

    expect(() => getPredictionsForImage(options)).toThrowError(
      'confidenceThreshold must be a number between 0 and 100.',
    );
  });

  it('should throw an error when confidenceThreshold is greater than 100', () => {
    const options = {
      ...correctOptions,
      confidenceThreshold: 150,
    };

    expect(() => getPredictionsForImage(options)).toThrowError(
      'confidenceThreshold must be a number between 0 and 100.',
    );
  });
});

describe('cropRatio', () => {
  it('should throw an error when cropRatio is not a number', () => {
    const options = {
      ...correctOptions,
      cropRatio: 'invalid',
    };

    expect(() => getPredictionsForImage(options)).toThrowError(
      'cropRatio must be a number between 0 and 1.',
    );
  });

  it('should throw an error when cropRatio is less than 0', () => {
    const options = {
      ...correctOptions,
      cropRatio: -0.5,
    };

    expect(() => getPredictionsForImage(options)).toThrowError(
      'cropRatio must be a number between 0 and 1.',
    );
  });

  it('should throw an error when cropRatio is greater than 1', () => {
    const options = {
      ...correctOptions,
      cropRatio: 1.5,
    };

    expect(() => getPredictionsForImage(options)).toThrowError(
      'cropRatio must be a number between 0 and 1.',
    );
  });
});

describe('getPredictionsForImage result handling', () => {
  const baseOptions = {
    uri: 'testUri',
    version: '1.0',
    modelPath: 'testModelPath',
    taxonomyPath: 'testTaxonomyPath',
    confidenceThreshold: 0,
  };

  beforeEach(() => {
    NativeModules.VisionCameraPluginInatVision.getPredictionsForImage.mockReset();
  });

  it('propagates native promise rejections', async () => {
    const nativeError = new Error('native failure');
    NativeModules.VisionCameraPluginInatVision.getPredictionsForImage.mockRejectedValueOnce(
      nativeError,
    );

    await expect(getPredictionsForImage(baseOptions)).rejects.toThrow(
      'native failure',
    );
  });

  it('returns scaled best-branch predictions', async () => {
    NativeModules.VisionCameraPluginInatVision.getPredictionsForImage.mockResolvedValueOnce(
      {
        predictions: [
          {
            rank_level: 10,
            score: 0.8,
            vision_score: 0.8,
            taxon_id: '1',
          },
        ],
      },
    );

    const result = await getPredictionsForImage(baseOptions);

    expect(result.predictions).toHaveLength(1);
    expect(result.predictions[0].score).toBe(80);
  });
});
