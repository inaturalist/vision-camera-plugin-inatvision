package com.margelo.nitro.camera.barcodescanner.extensions

import android.media.Image
import androidx.annotation.OptIn
import androidx.camera.core.ExperimentalGetImage
import com.margelo.nitro.camera.HybridFrameSpec
import com.margelo.nitro.camera.public.NativeFrame

@OptIn(ExperimentalGetImage::class)
fun HybridFrameSpec.toImage(): Image {
  val frame =
    this as? NativeFrame
      ?: throw Error("Frame is not of type `NativeFrame`!")

  val mediaImage =
    frame.image.image
      ?: throw Error("Frame does not have an underlying `Image`!")
  return mediaImage
}
