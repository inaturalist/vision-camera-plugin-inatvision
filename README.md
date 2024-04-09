# vision-camera-plugin-inatvision

A [VisionCamera](https://github.com/mrousavy/react-native-vision-camera) Frame Processor Plugin to label images using iNaturalist's computer vision model on device.

## Installation

1. Add the plugin to your package.json file directly from GitHub, because it's not published to npm:

```json
{
  "dependencies": {
    "vision-camera-plugin-inatvision": "github:inaturalist/vision-camera-plugin-inatvision"
  }
}
```

2. Install the plugin:
```sh
npm install
cd ios && pod install
```

3. Add the plugin to your `babel.config.js`:

```js
module.exports = {
  plugins: [
    ['react-native-worklets-core/plugin'],

    // ...
```

> Note: You have to restart metro-bundler for changes in the `babel.config.js` file to take effect.

## Usage

```js
import { inatVision } from "vision-camera-plugin-inatvision";

// ...

const frameProcessor = useFrameProcessor((frame) => {
  'worklet';
  const labels = inatVision(frame);
}, []);
```

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
