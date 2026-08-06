import { NativeModules } from 'react-native';

import { getPredictionsForImage, MODE } from '../index';

const correctOptions = {
  uri: 'file:///test/photo.jpg',
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

describe('uri', () => {
  it('should not throw for a file:// uri', () => {
    const options = { ...correctOptions, uri: 'file:///foo/bar.jpg' };

    expect(() => getPredictionsForImage(options)).not.toThrowError();
  });

  it('should not throw for a ph:// uri', () => {
    const options = {
      ...correctOptions,
      uri: 'ph://CC95F08C-88C3-4012-9D6D-64A413D254B3',
    };

    expect(() => getPredictionsForImage(options)).not.toThrowError();
  });

  it('should throw an error when uri is missing', () => {
    const { uri, ...options } = correctOptions;

    expect(() => getPredictionsForImage(options)).toThrowError(
      'uri must be a non-empty string.',
    );
  });

  it('should throw an error when uri is an empty string', () => {
    const options = { ...correctOptions, uri: '   ' };

    expect(() => getPredictionsForImage(options)).toThrowError(
      'uri must be a non-empty string.',
    );
  });

  it('should throw an error when uri is not a string', () => {
    const options = { ...correctOptions, uri: 42 };

    expect(() => getPredictionsForImage(options)).toThrowError(
      'uri must be a non-empty string.',
    );
  });

  it('should throw an error when uri is a bare path without a scheme', () => {
    const options = { ...correctOptions, uri: '/foo/bar.jpg' };

    expect(() => getPredictionsForImage(options)).toThrowError(
      'uri must include a scheme',
    );
  });

  it('should throw an error when uri is a relative path without a scheme', () => {
    const options = { ...correctOptions, uri: 'testUri' };

    expect(() => getPredictionsForImage(options)).toThrowError(
      'uri must include a scheme',
    );
  });
});

describe('getPredictionsForImage result handling', () => {
  const baseOptions = {
    uri: 'file:///test/photo.jpg',
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

  it('returns common-ancestor results in common ancestor mode', async () => {
    NativeModules.VisionCameraPluginInatVision.getPredictionsForImage.mockResolvedValueOnce(
      {
        predictions: [
          {
            leaf_id: 1,
            rank_level: 10,
            score: 0.8,
            vision_score: 0.8,
            taxon_id: 101,
            ancestor_ids: [20],
          },
          {
            rank_level: 20,
            score: 0,
            vision_score: 0,
            taxon_id: 20,
            ancestor_ids: [],
          },
        ],
      },
    );

    const result = await getPredictionsForImage({
      ...baseOptions,
      mode: MODE.COMMON_ANCESTOR,
    });

    expect(result.predictions[0].score).toBe(80);
    expect(result.commonAncestor?.taxon_id).toBe(20);
  });
});
