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

describe('getPredictionsForImage', () => {
  it('should not throw an error when options are valid', () => {
    const options = {
      confidenceThreshold: '0.5',
    };

    expect(() => getPredictionsForImage(options)).not.toThrowError(
      'getPredictionsForImage option confidenceThreshold must be a string for a number between 0 and 1.'
    );
  });

  it('should throw an error when confidenceThreshold is not a number', () => {
    const options = {
      confidenceThreshold: 'invalid',
    };

    expect(() => getPredictionsForImage(options)).toThrowError(
      'getPredictionsForImage option confidenceThreshold must be a string for a number between 0 and 1.'
    );
  });

  it('should throw an error when confidenceThreshold is less than 0', () => {
    const options = {
      confidenceThreshold: '-0.5',
    };

    expect(() => getPredictionsForImage(options)).toThrowError(
      'getPredictionsForImage option confidenceThreshold must be a string for a number between 0 and 1.'
    );
  });

  it('should throw an error when confidenceThreshold is greater than 1', () => {
    const options = {
      confidenceThreshold: '1.5',
    };

    expect(() => getPredictionsForImage(options)).toThrowError(
      'getPredictionsForImage option confidenceThreshold must be a string for a number between 0 and 1.'
    );
  });
});
