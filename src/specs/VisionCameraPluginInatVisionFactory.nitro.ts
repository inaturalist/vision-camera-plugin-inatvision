import type { HybridObject } from 'react-native-nitro-modules';
import type { VisionCameraPluginInatVision } from './VisionCameraPluginInatVision.nitro';

interface Location {
  latitude: number;
  longitude: number;
  elevation?: number;
}

interface VisionCameraPluginInatVisionOptions {
  version: string;
  modelPath: string;
  taxonomyPath: string;
  cropRatio?: number;
  useGeomodel?: boolean;
  location?: Location;
  geomodelPath?: string;
  taxonomyRollupCutoff?: number;
  filterByTaxonId?: null | string;
  negativeFilter?: null | boolean;
}

export interface VisionCameraPluginInatVisionFactory extends HybridObject<{
  ios: 'swift';
  android: 'c++';
}> {
  createVisionCameraPluginInatVision(
    options: VisionCameraPluginInatVisionOptions,
  ): Promise<VisionCameraPluginInatVision>;
}
