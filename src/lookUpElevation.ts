import { latLngToCell } from 'h3-js';

import type { Location } from '.';

import elevationLookupDict from './elevation_r4_5m.json';

type ElevationLookupDict = {
  [key: string]: number;
};
const elevationLookupDictTyped: ElevationLookupDict = elevationLookupDict;

export function lookUpElevation(location: Location): number {
  // Transform coordinates to h3 index
  const h3Index = latLngToCell(location.latitude, location.longitude, 4);

  // Read the elevation from the lookup table return a minus elevation if h3Index is not found
  const elevation = elevationLookupDictTyped[h3Index] || -32768;
  return elevation;
}
