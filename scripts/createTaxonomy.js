const fs = require('fs');
const path = require('path');
const csv = require('csv-parser');

// Step 1: Define the file path
const filePathTaxonomy = path.join(__dirname, 'taxonomy_v2_13.csv');
const filePathGeoThresholds = path.join(__dirname, 'tf_env_thresh_v2_13.csv');

// Step 2: Read the .csv files and Step 3: Parse the CSV data
let entriesTaxonomy = [];
const entriesGeoThresholds = [];
fs.createReadStream(filePathTaxonomy)
  .pipe(csv())
  .on('data', (row) => {
    // Extract the row
    entriesTaxonomy.push(row);
  })
  .on('end', () => {
    // Read taxonomy data
    console.log('entriesTaxonomy.length', entriesTaxonomy.length);
    const overridenEntries = entriesTaxonomy.map((entry) => {
      entry.parent_taxon_id = parseInt(entry.parent_taxon_id, 10);
      entry.taxon_id = parseInt(entry.taxon_id, 10);
      entry.rank_level = parseInt(entry.rank_level, 10);
      entry.leaf_class_id = parseInt(entry.leaf_class_id, 10);
      entry.iconic_class_id = parseInt(entry.iconic_class_id, 10);
      entry.spatial_class_id = parseInt(entry.spatial_class_id, 10);
      return entry;
    });
    entriesTaxonomy = overridenEntries;
    // Read geo thresholds data
    fs.createReadStream(filePathGeoThresholds)
      .pipe(csv())
      .on('data', (row) => {
        // Extract the row
        entriesGeoThresholds.push({
          taxon_id: row.taxon_id,
          thres: row.thres,
        });
      })
      .on('end', () => {
        // Print or return the extracted column
        console.log('entriesGeoThresholds.length', entriesGeoThresholds.length);
        // Turn geothreshold data into dict with taxon_id as index
        const thresholdDict = {};
        entriesGeoThresholds.forEach((entry) => {
          thresholdDict[entry.taxon_id] = entry.thres;
        });
        const combinedEntries = entriesTaxonomy.map((entry) => {
          // Add the geoThreshold to the entry
          entry.spatial_threshold = thresholdDict[entry.taxon_id]
            ? parseFloat(thresholdDict[entry.taxon_id])
            : null;
          return entry;
        });
        // Write json to file
        const json = JSON.stringify(combinedEntries, null, 2);
        fs.writeFileSync('taxonomy.json', json);
      });
  });
