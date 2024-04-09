import { getPredictionsForImage } from '../index';

jest.mock('react-native', () => ({
  Platform: {
    OS: 'ios',
    select: jest.fn(),
  },
  NativeModules: {
    VisionCameraPluginInatVision: {
      getPredictionsForImage: jest.fn(),
    },
  },
}));

const correctOptions = {
  version: '1.0',
  confidenceThreshold: 0.5,
  cropRatio: 0.8,
};

describe('getPredictionsForImage', () => {
  it('should not throw an error when options are valid', () => {
    const options = correctOptions;

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
      'getPredictionsForImage option confidenceThreshold must be a string for a number between 0 and 1.'
    );
  });

  it('should throw an error when confidenceThreshold is less than 0', () => {
    const options = {
      ...correctOptions,
      confidenceThreshold: -0.5,
    };

    expect(() => getPredictionsForImage(options)).toThrowError(
      'getPredictionsForImage option confidenceThreshold must be a string for a number between 0 and 1.'
    );
  });

  it('should throw an error when confidenceThreshold is greater than 1', () => {
    const options = {
      ...correctOptions,
      confidenceThreshold: 1.5,
    };

    expect(() => getPredictionsForImage(options)).toThrowError(
      'getPredictionsForImage option confidenceThreshold must be a string for a number between 0 and 1.'
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
      'option cropRatio must be a number between 0 and 1.'
    );
  });

  it('should throw an error when cropRatio is less than 0', () => {
    const options = {
      ...correctOptions,
      cropRatio: -0.5,
    };

    expect(() => getPredictionsForImage(options)).toThrowError(
      'option cropRatio must be a number between 0 and 1.'
    );
  });

  it('should throw an error when cropRatio is greater than 1', () => {
    const options = {
      ...correctOptions,
      cropRatio: 1.5,
    };

    expect(() => getPredictionsForImage(options)).toThrowError(
      'option cropRatio must be a number between 0 and 1.'
    );
  });
});
