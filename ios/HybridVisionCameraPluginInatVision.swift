import AVFoundation
import NitroModules
import VisionCamera

class HybridVisionCameraPluginInatVision: HybridVisionCameraPluginInatVisionSpec {
  private let plugin = VisionCameraPluginInatVisionPlugin()

  func call(frame: any HybridFrameSpec, options: VisionCameraPluginInatVisionOptions) throws -> AnyMap {

    let sampleBuffer = try sampleBuffer(from: frame)
    let pixelBuffer = try pixelBuffer(from: sampleBuffer)

    let args = options.toDictionary()
    let response = plugin.callback(
      pixelBuffer,
      withArguments: args as [String: Any]
    )
    let dict = jsonSafe(response) as? [String: Any] ?? [:]
    return AnyMap.fromDictionaryIgnoreIncompatible(
      dict.mapValues { $0 as Any? }
    )
  }

  private func jsonSafe(_ value: Any?) -> Any? {
    switch value {
    case nil, is NSNull:
      return nil
    case let dict as NSDictionary:
      var out: [String: Any] = [:]
      for (key, nested) in dict {
        if let key = key as? String, let safe = jsonSafe(nested) {
          out[key] = safe
        }
      }
      return out
    case let arr as NSArray:
      return arr.compactMap { jsonSafe($0) }
    default:
      return value
    }
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
