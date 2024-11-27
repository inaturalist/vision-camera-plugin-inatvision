const fs = require('fs');
const path = require('path');
const csv = require('csv-parser');

const filePath = path.join(__dirname, 'elevation_r4_5m.csv');
let entries = [];
fs.createReadStream(filePath)
  .pipe(csv())
  .on('data', (data) => {
    entries.push(data);
  })
  .on('end', () => {
    entries.sort((a, b) => a.h3_04.localeCompare(b.h3_04));
    const exported = entries.reduce((acc, row) => {
      // If elevation is positive, add it to the dictionary
      if (parseFloat(row.elevation) > 0) {
        acc[row.h3_04] = parseFloat(row.elevation);
      }
      return acc;
    }, {});
    const json = JSON.stringify(exported, null, 2);
    fs.writeFileSync('elevation_r4_5m.json', json);
  });
