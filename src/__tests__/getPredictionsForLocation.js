import { getPredictionsForLocation } from '../index';

const correctOptions = {
  taxonomyPath: 'testTaxonomyPath',
  geoModelPath: 'testGeoModelPath',
  location: {
    latitude: 54,
    longitude: -18,
  },
};

describe('getPredictionsForLocation', () => {
  it('should not throw an error when options are valid', () => {
    const options = correctOptions;

    expect(() => getPredictionsForLocation(options)).not.toThrowError();
  });
});

describe('location', () => {
  it('should not throw an error when elevation which is optional is given', () => {
    const options = correctOptions;
    options.location.elevation = 12.123;

    expect(() => getPredictionsForLocation(options)).not.toThrowError();
  });

  it('should throw an error when location is not given', () => {
    const options = {
      ...correctOptions,
      location: undefined,
    };

    expect(() => getPredictionsForLocation(options)).toThrowError(
      'location must have latitude and longitude set.'
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
      'location must have latitude and longitude set.'
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
      'location must have latitude and longitude set.'
    );
  });
});
