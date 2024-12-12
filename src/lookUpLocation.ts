import { cellToLatLng, latLngToCell } from 'h3-js';

import type { Location } from '.';

import elevationLookupDict from './elevation_r4_5m.json';

type ElevationLookupDict = {
  [key: string]: number;
};
const elevationLookupDictTyped: ElevationLookupDict = elevationLookupDict;

interface LocationLookup {
  latitude: number;
  longitude: number;
  elevation: number;
}

export function lookUpLocation(location: Location): LocationLookup {
  // # lookup the H3 cell this lat lng occurs in
  const h3Index = latLngToCell(location.latitude, location.longitude, 4);
  const h3CellCentroid = cellToLatLng(h3Index);

  // # get the average elevation of the above H3 cell
  // Read the elevation from the lookup table return a minus elevation if h3Index is not found
  const elevation = elevationLookupDictTyped[h3Index] || -32768.0;
  const locationLookup = {
    latitude: h3CellCentroid[0],
    longitude: h3CellCentroid[1],
    elevation: elevation,
  };
  return locationLookup;
}
