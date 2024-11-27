import type { Location } from '.';

import elevationLookupDict from './elevation_r4_5m.json';

export function lookUpElevation(location: Location): number {
  //const h3LookupTable =
  // setupElevationDataFrame();

  // // Transform coordinates to h3 index
  // const h3Index = geoToH3(location.latitude, location.longitude, resolution);

  // // Read the elevation from the lookup table
  // const elevation = h3LookupTable[h3Index];

  // return elevation;
  return elevationLookupDict['8400281ffffffff'] * location.latitude;
}

// def setup_elevation_dataframe(self):
//     self.geo_elevation_cells = None
//     if "elevation_h3_r4" not in self.config:
//         return

//     # load elevation data stored at H3 resolution 4
//     self.geo_elevation_cells = pd.read_csv(self.config["elevation_h3_r4"]). \
//         sort_values("h3_04").set_index("h3_04").sort_index()
//     self.geo_elevation_cells = InatInferrer.add_lat_lng_to_h3_geo_dataframe(
//         self.geo_elevation_cells
//     )
//     self.geo_elevation_cell_indices = {
//         index: idx for idx, index in enumerate(self.geo_elevation_cells.index)
//     }

// function geoToH3(latitude: number, longitude: number, resolution: number) {
//   // Placeholder function to transform coordinates to h3 index
//   // Replace with actual implementation
//   return 'h3Index';
// }
