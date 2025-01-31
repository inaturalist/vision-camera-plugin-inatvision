const fs = require('fs').promises;
const path = require('path');
const download = require('download');

const binariesBaseDir =
  'https://github.com/inaturalist/model-files/releases/download/v25.01.15';

const androidExt = 'tflite';
const iosExt = 'mlmodel';
const cvModelFilename = 'INatVision_Small_2_fact256_8bit';
const geomodelFilename = 'INatGeomodel_Small_2_8bit';

const androidCV = `${binariesBaseDir}/${cvModelFilename}.${androidExt}`;
const iosCV = `${binariesBaseDir}/${cvModelFilename}.${iosExt}`;
const androidGeo = `${binariesBaseDir}/${geomodelFilename}.${androidExt}`;
const iosGeo = `${binariesBaseDir}/${geomodelFilename}.${iosExt}`;
const taxonomyCSV = `${binariesBaseDir}/taxonomy.csv`;
const taxonomyJSON = `${binariesBaseDir}/taxonomy.json`;

const androidDestination = path.join(
  __dirname,
  '..',
  'example',
  'android',
  'app',
  'src',
  'main',
  'assets'
);
const iosDestination = path.join(__dirname, '..', 'example', 'ios');

const androidModel = path.join(
  androidDestination,
  `${cvModelFilename}.${androidExt}`
);
const iosModel = path.join(iosDestination, `${cvModelFilename}.${iosExt}`);

(async () => {
  console.log('Checking android model files...');
  let exist = true;
  try {
    await fs.access(androidModel);
  } catch (_) {
    exist = false;
  }

  if (exist) {
    console.log('Android model exist!');
    return;
  }

  console.log(
    `Android model files missing, downloading from '${binariesBaseDir}'...`
  );

  await download(androidCV, androidDestination);
  await download(androidGeo, androidDestination);
  await download(taxonomyCSV, androidDestination);
  console.log('Done!');
})();

(async () => {
  console.log('Checking ios model files...');
  let exist = true;
  try {
    await fs.access(iosModel);
  } catch (_) {
    exist = false;
  }

  if (exist) {
    console.log('ios model exist!');
    return;
  }

  console.log(
    `iOS Model files missing, downloading from '${binariesBaseDir}'...`
  );

  await download(iosCV, iosDestination);
  await download(iosGeo, iosDestination);
  await download(taxonomyJSON, iosDestination);
  console.log('Done!');
})();
