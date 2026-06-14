import { lookUpLocation } from '../lookUpLocation';

describe('lookUpLocation', () => {
  it('preserves sea-level elevation of 0 instead of using the not-found sentinel', () => {
    // H3 cell 8410931… has elevation 0 in elevation_r4_5m.json (key "10931")
    const result = lookUpLocation({
      latitude: 49.45518417139883,
      longitude: 50.10020979726967,
    });

    expect(result.elevation).toBe(0);
  });

  it('uses the not-found sentinel when the H3 cell is missing from the lookup table', () => {
    const result = lookUpLocation({
      latitude: 89.9,
      longitude: 179.9,
    });

    expect(result.elevation).toBe(-32768.0);
  });
});
