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
      // Remove the -32768.0 values
      if (parseFloat(row.elevation) !== -32768.0) {
        acc[row.h3_04] = parseInt(row.elevation, 10);
      }
      return acc;
    }, {});
    const json = JSON.stringify(exported, null, 2);
    fs.writeFileSync('elevation_r4_5m.json', json);
  });
