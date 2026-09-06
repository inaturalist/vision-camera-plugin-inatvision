package com.margelo.nitro.visioncameraplugininatvision

// import android.media.Image
// import androidx.camera.core.ExperimentalGetImage
import com.margelo.nitro.camera.HybridFrameSpec
// import com.margelo.nitro.camera.public.NativeFrame
import com.margelo.nitro.core.AnyMap

// import com.visioncameraplugininatvision.VisionCameraPluginInatVisionPlugin

class HybridVisionCameraPluginInatVision : HybridVisionCameraPluginInatVisionSpec() {
  // private val plugin = VisionCameraPluginInatVisionPlugin()

  override fun call(frame: HybridFrameSpec, options: AnyMap): AnyMap {
    // val image = image(from = frame)
    // val response = plugin.callback(image, options.toHashMap())
    // val dict = jsonSafe(response) as? Map<String, Any> ?: emptyMap()
    // return AnyMap.fromMap(dict, true)
    return options;
  }

//  private fun image(from: HybridFrameSpec): Image {
//    val nativeFrame =
//      from as? NativeFrame
//        ?: throw Error("The given Frame is not of type `NativeFrame`!")
//    val image =
//      nativeFrame.image.image
//        ?: throw Error("The given Frame's `image` is no longer valid!")
//    return image
//  }

//  private fun jsonSafe(value: Any?): Any? {
//    if (value == null) {
//      return null
//    }
//    return when (value) {
//      is Map<*, *> -> {
//        val out = LinkedHashMap<String, Any>()
//        for ((key, nested) in value) {
//          if (key is String) {
//            jsonSafe(nested)?.let { out[key] = it }
//          }
//        }
//        out
//      }
//      is List<*> -> value.mapNotNull { jsonSafe(it) }
//      else -> value
//    }
//  }
}
