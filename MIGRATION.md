# Migrating from 6.x to 7.0

Version 7.0 is currently in alpha on the `version-7` branch. Install it with:

```json
"vision-camera-plugin-inatvision": "github:inaturalist/vision-camera-plugin-inatvision#version-7"
```

## Peer dependency changes

| Package | 6.x | 7.0 |
|---------|-----|-----|
| `react-native-vision-camera` | `>=4.1.0` | `>=5.0.0 <5.2.3` |
| Worklets | `react-native-worklets-core` | `react-native-worklets` |
| Nitro | — | `react-native-nitro-modules` (required for frames) |
| Node.js | `>=20` | `>=22.11.0` |

Also install `react-native-vision-camera-worklets` alongside Vision Camera 5.

## Babel plugin

Replace the worklets-core plugin with the new worklets plugin:

```diff
 module.exports = {
   presets: ['module:@react-native/babel-preset'],
-  plugins: ['react-native-worklets-core/plugin'],
+  plugins: ['react-native-worklets/plugin'],
 };
```

## Camera API: `useFrameProcessor` → `useFrameOutput`

Vision Camera 5 replaces frame processors with frame outputs.

**Before (6.x / Vision Camera 4):**

```tsx
import { useFrameProcessor } from 'react-native-vision-camera';
import { inatVision } from 'vision-camera-plugin-inatvision';

const frameProcessor = useFrameProcessor((frame) => {
  'worklet';
  const result = inatVision(frame, {
    version: 'small_2',
    modelPath,
    taxonomyPath,
  });
  runOnJS(setPredictions)(result.predictions);
}, []);

<Camera frameProcessor={frameProcessor} />
```

**After (7.0 / Vision Camera 5):**

```tsx
import { useFrameOutput } from 'react-native-vision-camera';
import { scheduleOnRN } from 'react-native-worklets';
import * as InatVision from 'vision-camera-plugin-inatvision';

const frameOutput = useFrameOutput({
  pixelFormat: 'yuv',
  onFrame(frame) {
    'worklet';
    const result = InatVision.inatVision(frame, {
      version: 'small_2',
      modelPath,
      taxonomyPath,
    });
    scheduleOnRN(setPredictions, result.predictions);
    frame.dispose();
  },
});

<Camera outputs={[frameOutput]} />
```

Key differences:

- Use `useFrameOutput` with `outputs={[frameOutput]}` instead of `frameProcessor`
- Call `frame.dispose()` when done processing each frame
- Use `scheduleOnRN` from `react-native-worklets` instead of `runOnJS` from worklets-core

## Unchanged APIs

These work the same as in 6.x:

- `getPredictionsForImage`
- `getPredictionsForLocation`
- `getCellLocation`
- `resetStoredResults`
- `addLogListener` / `removeLogListener`
