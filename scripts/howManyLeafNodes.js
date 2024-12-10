const fs = require('fs');
const path = require('path');
const csv = require('csv-parser');

// Step 1: Define the file path
const filePathTaxonomy = path.join(__dirname, 'taxonomy_v1.csv');

// Step 2: Read the .csv files and Step 3: Parse the CSV data
let entriesTaxonomy = [];
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
    // Count leaf nodes
    const leafNodes = entriesTaxonomy.filter(
      (entry) => !!entry.leaf_class_id
    ).length;
    console.log('leafNodes', leafNodes);
    const species = entriesTaxonomy.filter(
      (entry) => !!entry.leaf_class_id && entry.rank_level === 10
    ).length;
    console.log('species', species);
  });
