package com.margelo.nitro.visioncameraplugininatvision

import androidx.annotation.Keep
import com.facebook.proguard.annotations.DoNotStrip

@DoNotStrip
@Keep
class HybridVisionCameraPluginInatVisionFactory : HybridVisionCameraPluginInatVisionFactorySpec() {
  @DoNotStrip
  @Keep
  override fun createVisionCameraPluginInatVision(options: VisionCameraPluginInatVisionOptions): HybridVisionCameraPluginInatVisionSpec {
    return HybridVisionCameraPluginInatVision(options)
  }
}
