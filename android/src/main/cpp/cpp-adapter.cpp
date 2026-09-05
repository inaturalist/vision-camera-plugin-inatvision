#include <fbjni/fbjni.h>
#include "VisionCameraPluginInatVisionOnLoad.hpp"

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
  return facebook::jni::initialize(vm, []() {
    margelo::nitro::com::visioncameraplugininatvision::registerAllNatives();
  });
}
