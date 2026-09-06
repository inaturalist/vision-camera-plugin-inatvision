import type { AnyMap, HybridObject } from 'react-native-nitro-modules';
import type { Frame } from 'react-native-vision-camera';
import type { VisionCameraPluginInatVisionOptions } from './VisionCameraPluginInatVisionFactory.nitro';

export interface VisionCameraPluginInatVision extends HybridObject<{
  ios: 'swift';
  android: 'kotlin';
}> {
  call(frame: Frame, options: VisionCameraPluginInatVisionOptions): AnyMap;
}
