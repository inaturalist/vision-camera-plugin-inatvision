import type { HybridObject } from 'react-native-nitro-modules';
import type { Frame } from 'react-native-vision-camera';

export interface InatVision extends HybridObject<{
  ios: 'swift';
  android: 'kotlin';
}> {
  call(frame: Frame): void;
}
