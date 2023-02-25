package com.visioncameraplugininatvision;

import androidx.annotation.NonNull;

import com.facebook.react.ReactPackage;
import com.facebook.react.bridge.NativeModule;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.uimanager.ViewManager;
import com.mrousavy.camera.frameprocessor.FrameProcessorPlugin;
import com.visioncameraplugininatvision.visioncameraplugininatvision.VisionCameraPluginInatvisionPlugin;

import java.util.Collections;
import java.util.List;

public class VisionCameraPluginInatvisionPackage implements ReactPackage {
  @NonNull
  @Override
  public List<NativeModule> createNativeModules(@NonNull ReactApplicationContext reactContext) {
    FrameProcessorPlugin.register(new VisionCameraPluginInatvisionPlugin());
    return Collections.emptyList();
  }

  @NonNull
  @Override
  public List<ViewManager> createViewManagers(@NonNull ReactApplicationContext reactContext) {
    return Collections.emptyList();
  }
}