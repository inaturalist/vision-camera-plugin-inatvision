# vision-camera-plugin-inatvision

A [VisionCamera](https://github.com/margelo/react-native-vision-camera) Frame Processor Plugin to label images using iNaturalist's computer vision model on device.

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

### Babel

Add the worklets plugin to your app's `babel.config.js`:

```js
import { inatVision } from "vision-camera-plugin-inatvision";
module.exports = {
  presets: ['module:@react-native/babel-preset'],
  plugins: ['react-native-worklets/plugin'],
};
```

## Usage

```js
// ...
const frameOutput = useFrameOutput({
  onFrame(frame) {
    'worklet';
    const labels = inatVision(frame, options);
  }
});
```

## Migration

See [MIGRATION.md](./MIGRATION.md) for a checklist when upgrading from 6.x to 7.0.

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
