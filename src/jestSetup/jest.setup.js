/* eslint-disable no-undef */
import {
  mockCamera,
  mockSortDevices,
  mockUseCameraDevice,
} from './mock-vision-camera';

jest.mock('react-native-vision-camera', () => ({
  Camera: mockCamera,
  sortDevices: mockSortDevices,
  useCameraDevice: mockUseCameraDevice,
  VisionCameraProxy: {
    initFrameProcessorPlugin: jest.fn(() => ({
      call: jest.fn(),
    })),
  },
}));

jest.mock('react-native-worklets-core', () => ({
  Worklets: {
    createRunInJsFn: jest.fn(),
  },
}));

jest.mock('react-native', () => ({
  Platform: {
    OS: 'ios',
    select: jest.fn(),
  },
  NativeModules: {
    VisionCameraPluginInatVision: {
      getPredictionsForImage: jest.fn(),
    },
  },
}));
