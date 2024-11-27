import { createReadStream } from 'fs';
import * as path from 'path';
import csv from 'csv-parser';

import type { Location } from '.';

export function lookUpElevation(location: Location): number {
  //const h3LookupTable =
  setupElevationDataFrame();

  // // Transform coordinates to h3 index
  // const h3Index = geoToH3(location.latitude, location.longitude, resolution);

  // // Read the elevation from the lookup table
  // const elevation = h3LookupTable[h3Index];

  // return elevation;
  return location.latitude;
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

let geoElevationCells: Record<string, number>;
// let geoElevationCellIndices: Record<string, number>;

async function setupElevationDataFrame() {
  const filePath = path.join(__dirname, 'elevation_r4_5m.csv');
  const results: any[] = [];

  createReadStream(filePath)
    .pipe(csv())
    .on('data', (data) => results.push(data))
    .on('end', () => {
      results.sort((a, b) => a.h3_04.localeCompare(b.h3_04));
      geoElevationCells = results.reduce((acc, row) => {
        acc[row.h3_04] = row;
        return acc;
      }, {});
      console.log('geoElevationCells', geoElevationCells);
      // geoElevationCellIndices = results.reduce((acc, row, idx) => {
      //   acc[row.h3_04] = idx;
      //   return acc;
      // }, {});
    });
}

// function geoToH3(latitude: number, longitude: number, resolution: number) {
//   // Placeholder function to transform coordinates to h3 index
//   // Replace with actual implementation
//   return 'h3Index';
// }
