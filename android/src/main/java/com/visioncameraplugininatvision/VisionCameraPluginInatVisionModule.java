package com.visioncameraplugininatvision;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.module.annotations.ReactModule;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.Arguments;

import timber.log.Timber;

@ReactModule(name = VisionCameraPluginInatVisionModule.NAME)
public class VisionCameraPluginInatVisionModule extends ReactContextBaseJavaModule {
    public static final String NAME = "VisionCameraPluginInatVision";
    private ReactApplicationContext mContext;
    private int mListenerCount = 0;

    public VisionCameraPluginInatVisionModule(ReactApplicationContext reactContext) {
        super(reactContext);
        mContext = reactContext;
    }

    public Context getContext(){
        return mContext;
    }

    @Override
    @NonNull
    public String getName() {
        return NAME;
    }

    @ReactMethod
    public void addListener(String eventName) {
      if (mListenerCount == 0) {
        Timber.plant(new LogEventTree(mContext, eventName));
      }
      mListenerCount += 1;
    }

    @ReactMethod
    public void removeListeners(Integer count) {
      mListenerCount -= count;
      if (mListenerCount == 0) {
        Timber.uprootAll();
      }
    }
}
