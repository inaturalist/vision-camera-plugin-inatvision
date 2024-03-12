import { inatVision } from '../index';

const mockFrame = {
  width: 100,
  height: 100,
  orientation: 'portrait',
  base64: 'base64',
};

describe('inatVision', () => {
  it('should not throw an error when version is supported', () => {
    const options = {
      version: '1.0',
    };

    expect(() => inatVision(mockFrame, options)).not.toThrowError(
      'This model version is not supported.'
    );
  });

  it('should throw an error when version is not supported', () => {
    const options = {
      version: '0.9',
    };

    expect(() => inatVision(mockFrame, options)).toThrowError(
      'This model version is not supported.'
    );
  });
});
