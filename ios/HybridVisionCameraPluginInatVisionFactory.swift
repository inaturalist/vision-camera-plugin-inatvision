//
//  HybridVisionCameraPluginInatVisionFactory.swift
//
//  Created by Johannes Klein on 06.09.26.
//

import AVFoundation
import NitroModules

class HybridVisionCameraPluginInatVisionFactory: HybridVisionCameraPluginInatVisionFactorySpec {
  func createVisionCameraPluginInatVision(options: VisionCameraPluginInatVisionOptions) throws -> Promise<any HybridVisionCameraPluginInatVisionSpec> {
    return Promise.async {
      // Initialize our inference pipeline asynchronously
      return try HybridVisionCameraPluginInatVision(options: options)
    }
  }
}
