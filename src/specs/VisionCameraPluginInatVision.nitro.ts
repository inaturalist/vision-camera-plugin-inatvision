import type { AnyMap, HybridObject } from 'react-native-nitro-modules';
import type { Frame } from 'react-native-vision-camera';

export interface VisionCameraPluginInatVision extends HybridObject<{
  ios: 'swift';
  android: 'kotlin';
}> {
  call(frame: Frame, options: AnyMap): void;
}
