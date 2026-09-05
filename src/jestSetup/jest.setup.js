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
}));

jest.mock('react-native-nitro-modules', () => ({
  NitroModules: {
    createHybridObject: jest.fn(() => ({
      call: jest.fn(),
    })),
  },
}));

jest.mock('react-native-worklets', () => ({
  createSynchronizable: (initial) => {
    let value = initial;
    return {
      getBlocking: () => value,
      getDirty: () => value,
      setBlocking: (next) => {
        value = typeof next === 'function' ? next(value) : next;
      },
      lock: () => {},
      unlock: () => {},
    };
  },
}));

jest.mock('react-native', () => ({
  Platform: {
    OS: 'ios',
    select: jest.fn(),
  },
  NativeModules: {
    VisionCameraPluginInatVision: {
      getPredictionsForImage: jest.fn(() =>
        Promise.resolve({
          predictions: [],
        }),
      ),
      getPredictionsForLocation: jest.fn(),
    },
  },
}));
