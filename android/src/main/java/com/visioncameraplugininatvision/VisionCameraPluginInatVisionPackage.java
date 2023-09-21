package com.visioncameraplugininatvision;

import com.facebook.react.ReactPackage;
import com.facebook.react.bridge.NativeModule;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.uimanager.ViewManager;
import com.mrousavy.camera.frameprocessor.FrameProcessorPluginRegistry;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import javax.annotation.Nonnull;
public class VisionCameraPluginInatVisionPackage implements ReactPackage {
  @Nonnull
  @Override
  public List<NativeModule> createNativeModules(@Nonnull ReactApplicationContext reactContext) {
    List<NativeModule> modules = new ArrayList<>();
    VisionCameraPluginInatVisionModule module = new VisionCameraPluginInatVisionModule(reactContext);
    modules.add(module);
    FrameProcessorPluginRegistry.addFrameProcessorPlugin("inatVision", options -> new VisionCameraPluginInatVisionPlugin());
    return modules;
  }

  @Nonnull
  @Override
  public List<ViewManager> createViewManagers(@Nonnull ReactApplicationContext reactContext) {
    return Collections.emptyList();
  }
}
