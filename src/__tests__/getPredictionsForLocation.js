import { getPredictionsForLocation } from '../index';

const correctOptions = {
  taxonomyPath: 'testTaxonomyPath',
  geoModelPath: 'testGeoModelPath',
  location: {
    latitude: 54,
    longitude: -18,
    elevation: 12,
  },
};

describe('getPredictionsForLocation', () => {
  it('should not throw an error when options are valid', () => {
    const options = correctOptions;

    expect(() => getPredictionsForLocation(options)).not.toThrowError();
  });
});

describe('location', () => {
  it('should throw an error when location is not given', () => {
    const options = {
      ...correctOptions,
      location: undefined,
    };

    expect(() => getPredictionsForLocation(options)).toThrowError(
      'location must have latitude, longitude, and elevation set.'
    );
  });

  it('should throw an error when location is missing latitude', () => {
    const options = {
      ...correctOptions,
      location: {
        longitude: -18,
        elevation: 12,
      },
    };

    expect(() => getPredictionsForLocation(options)).toThrowError(
      'location must have latitude, longitude, and elevation set.'
    );
  });

  it('should throw an error when location is missing longitude', () => {
    const options = {
      ...correctOptions,
      location: {
        latitude: 54,
        elevation: 12,
      },
    };

    expect(() => getPredictionsForLocation(options)).toThrowError(
      'location must have latitude, longitude, and elevation set.'
    );
  });

  it('should throw an error when location is missing elevation', () => {
    const options = {
      ...correctOptions,
      location: {
        latitude: 54,
        longitude: 12,
      },
    };

    expect(() => getPredictionsForLocation(options)).toThrowError(
      'location must have latitude, longitude, and elevation set.'
    );
  });
});
