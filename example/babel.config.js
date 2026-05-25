const path = require('path');
const { getConfig } = require('react-native-builder-bob/babel-config');
const pak = require('../package.json');

const root = path.resolve(__dirname, '..');

module.exports = getConfig(
  {
    presets: ['module:@react-native/babel-preset'],
    plugins: [
      // TODO: drop once the workspace conversion gives us a real
      // node_modules/vision-camera-plugin-inatvision symlink.
      [
        'module-resolver',
        {
          extensions: ['.tsx', '.ts', '.js', '.json'],
          alias: {
            [pak.name]: path.join(__dirname, '..', pak.source),
          },
        },
      ],
      ['react-native-worklets-core/plugin'],
    ],
  },
  { root, pkg: pak },
);
