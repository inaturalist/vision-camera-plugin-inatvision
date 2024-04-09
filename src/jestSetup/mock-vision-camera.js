import React from 'react';
import { View } from 'react-native';

export class mockCamera extends React.PureComponent {
  static async getAvailableCameraDevices() {
    return [
      {
        position: 'back',
      },
    ];
  }

  async takePhoto() {
    return { path: 'some-path' };
  }

  render() {
    return <View />;
  }
}

export const mockSortDevices = (_left, _right) => 1;

export const mockUseCameraDevice = (_deviceType) => {
  const device = {
    devices: ['wide-angle-camera'],
    hasFlash: true,
    hasTorch: true,
    id: '1',
    isMultiCam: true,
    maxZoom: 12.931958198547363,
    minZoom: 1,
    name: 'front (1)',
    neutralZoom: 1,
    position: 'front',
    supportsDepthCapture: false,
    supportsFocus: true,
    supportsLowLightBoost: false,
    supportsParallelVideoProcessing: true,
    supportsRawCapture: true,
  };
  return device;
};
