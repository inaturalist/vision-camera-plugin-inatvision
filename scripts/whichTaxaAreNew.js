const fs = require('fs');
const path = require('path');
const csv = require('csv-parser');

// Step 1: Define the file path
const filePathTaxonomy = path.join(__dirname, 'taxonomy_v1.csv');
const filePathTaxonomy2 = path.join(__dirname, 'taxonomy_v2_13.csv');

// Step 2: Read the .csv files and Step 3: Parse the CSV data
let entriesTaxonomy1 = [];
fs.createReadStream(filePathTaxonomy)
  .pipe(csv())
  .on('data', (row) => {
    // Extract the row
    entriesTaxonomy1.push(row);
  })
  .on('end', () => {
    // Read taxonomy data
    console.log('entriesTaxonomy1.length', entriesTaxonomy1.length);
    const overridenEntries = entriesTaxonomy1.map((entry) => {
      entry.parent_taxon_id = parseInt(entry.parent_taxon_id, 10);
      entry.taxon_id = parseInt(entry.taxon_id, 10);
      entry.rank_level = parseInt(entry.rank_level, 10);
      entry.leaf_class_id = parseInt(entry.leaf_class_id, 10);
      return entry;
    });
    entriesTaxonomy1 = overridenEntries;
    // Read second taxonomy data
    let entriesTaxonomy2 = [];
    fs.createReadStream(filePathTaxonomy2)
      .pipe(csv())
      .on('data', (row) => {
        // Extract the row
        entriesTaxonomy2.push(row);
      })
      .on('end', () => {
        // Read taxonomy data
        console.log('entriesTaxonomy2.length', entriesTaxonomy2.length);
        const overridenEntries2 = entriesTaxonomy2.map((entry) => {
          entry.parent_taxon_id = parseInt(entry.parent_taxon_id, 10);
          entry.taxon_id = parseInt(entry.taxon_id, 10);
          entry.rank_level = parseInt(entry.rank_level, 10);
          entry.leaf_class_id = parseInt(entry.leaf_class_id, 10);
          return entry;
        });
        entriesTaxonomy2 = overridenEntries2;
        // Find new taxa
        const newTaxa = entriesTaxonomy2.filter(
          (entry2) =>
            !entriesTaxonomy1.some(
              (entry1) => entry1.taxon_id === entry2.taxon_id
            )
        );
        console.log('newTaxa', newTaxa.length);
        // Write json to file
        const json = JSON.stringify(newTaxa, null, 2);
        fs.writeFileSync('newTaxa.json', json);
        // Find taxa no longer present
        const removedTaxa = entriesTaxonomy1.filter(
          (entry1) =>
            !entriesTaxonomy2.some(
              (entry2) => entry1.taxon_id === entry2.taxon_id
            )
        );
        console.log('removedTaxa', removedTaxa.length);
        // Write json to file
        const json2 = JSON.stringify(removedTaxa, null, 2);
        fs.writeFileSync('removedTaxa.json', json2);
        // Combine all taxon_ids of removed taxa into a comma sperated long string
        const removedSpecies = removedTaxa.filter(
          (entry) => entry.rank_level === 10
        );
        console.log('removedSpecies.length', removedSpecies.length);
        const removedTaxaIds = removedSpecies.map((entry) => entry.taxon_id);
        const removedTaxaIdsString = removedTaxaIds.join(',');
        console.log('removedTaxaIdsString', removedTaxaIdsString);
      });
  });
