import AVFoundation
import NitroModules
import UIKit
import VisionCamera

class HybridVisionCameraPluginInatVision: HybridVisionCameraPluginInatVisionSpec {
  private let plugin = VisionCameraPluginInatVisionPlugin()

  func call(frame: any HybridFrameSpec, options: AnyMap) throws -> AnyMap {

    let sampleBuffer = try sampleBuffer(from: frame)
    let pixelBuffer = try pixelBuffer(from: sampleBuffer)

    let response = plugin.callback(
      pixelBuffer,
      withArguments: options.toDictionary() as [String: Any]
    )
    return AnyMap.fromDictionaryIgnoreIncompatible(response as? [String: Any] ?? [:])
  }

  private func sampleBuffer(from frame: any HybridFrameSpec) throws -> CMSampleBuffer {
    guard let nativeFrame = frame as? any NativeFrame else {
      throw RuntimeError.error(withMessage: "The given Frame is not of type `NativeFrame`!")
    }
    guard let sampleBuffer = nativeFrame.sampleBuffer else {
      throw RuntimeError.error(withMessage: "The given Frame's `sampleBuffer` is no longer valid!")
    }
    return sampleBuffer
  }

  private func pixelBuffer(from sampleBuffer: CMSampleBuffer) throws -> CVPixelBuffer {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      throw RuntimeError.error(
        withMessage: "The given Frame does not contain a valid image buffer!")
    }
    return pixelBuffer
  }
}
