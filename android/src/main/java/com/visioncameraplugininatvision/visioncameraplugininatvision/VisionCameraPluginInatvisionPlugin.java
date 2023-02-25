package com.visioncameraplugininatvision.visioncameraplugininatvision;

import androidx.camera.core.ImageProxy;
import com.facebook.react.bridge.WritableNativeArray;
import com.mrousavy.camera.frameprocessor.FrameProcessorPlugin;

public class VisionCameraPluginInatvisionPlugin extends FrameProcessorPlugin {
  @Override
  public Object callback(ImageProxy image, Object[] params) {
    // code goes here
    WritableNativeArray array = new WritableNativeArray();
    return array;
  }

  public VisionCameraPluginInatvisionPlugin() {
    super("inatVision");
  }
}