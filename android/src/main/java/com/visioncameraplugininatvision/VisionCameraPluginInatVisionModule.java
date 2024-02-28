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

import java.io.IOException;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import com.facebook.react.bridge.ReadableMap;
import java.util.List;
import com.facebook.react.bridge.WritableArray;
import android.net.Uri;

@ReactModule(name = VisionCameraPluginInatVisionModule.NAME)
public class VisionCameraPluginInatVisionModule extends ReactContextBaseJavaModule {
    public static final String NAME = "VisionCameraPluginInatVision";
    private final static String TAG = "VisionCameraPluginInatVisionModule";
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

    public static final String OPTION_URI = "uri";
    public static final String OPTION_VERSION = "version";
    public static final String OPTION_MODEL_PATH = "modelPath";
    public static final String OPTION_TAXONOMY_PATH = "taxonomyPath";
    public static final String OPTION_CONFIDENCE_THRESHOLD = "confidenceThreshold";

    public static final float DEFAULT_CONFIDENCE_THRESHOLD = 0.7f;
    private float mConfidenceThreshold = DEFAULT_CONFIDENCE_THRESHOLD;
    public void setConfidenceThreshold(float confidence) {
        mConfidenceThreshold = confidence;
    }

    @ReactMethod
    public void getPredictionsForImage(ReadableMap options, Promise promise) {
        Log.d(TAG, "getPredictionsForImage: options:" + options);
        // Required options
        if (!options.hasKey(OPTION_URI) || !options.hasKey(OPTION_MODEL_PATH) || !options.hasKey(OPTION_TAXONOMY_PATH)|| !options.hasKey(OPTION_VERSION)) {
            promise.reject("E_MISSING_ARGS", String.format("Missing one or more arguments: %s, %s, %s, %s", OPTION_URI, OPTION_MODEL_PATH, OPTION_TAXONOMY_PATH, OPTION_VERSION));
            return;
        }

        Uri uri = Uri.parse(options.getString(OPTION_URI));
        String modelFilename = options.getString(OPTION_MODEL_PATH);
        String taxonomyFilename = options.getString(OPTION_TAXONOMY_PATH);
        String version = options.getString(OPTION_VERSION);
        // Destructure optional parameters and set values
        if (options.hasKey(OPTION_CONFIDENCE_THRESHOLD)) {
          String confidenceThreshold = options.getString(OPTION_CONFIDENCE_THRESHOLD);
          if (confidenceThreshold == null) {
            confidenceThreshold = String.valueOf(DEFAULT_CONFIDENCE_THRESHOLD);
          }
          setConfidenceThreshold(Float.parseFloat(confidenceThreshold));
        }

        ImageClassifier classifier = null;

        try {
            classifier = new ImageClassifier(modelFilename, taxonomyFilename, version);
        } catch (IOException e) {
            e.printStackTrace();
            promise.reject("E_CLASSIFIER", "Failed to initialize an image mClassifier: " + e.getMessage());
            return;
        } catch (OutOfMemoryError e) {
            e.printStackTrace();
            Timber.tag(TAG).w("Out of memory - Device not supported - classifier failed to load - " + e);
            promise.reject("E_OUT_OF_MEMORY", "Out of memory");
            return;
        } catch (Exception e) {
            e.printStackTrace();
            Timber.tag(TAG).w("Other type of exception - Device not supported - classifier failed to load - " + e);
            promise.reject("E_UNSUPPORTED_DEVICE", "Android version is too old - needs to be at least 6.0");
            return;
        }

        // Get predictions for that image
        Bitmap bitmap = null;

        try {
            // Read bitmap file
            bitmap = BitmapFactory.decodeFile(uri.getPath());
            if (bitmap == null) {
                String msg = String.format("Couldn't read image '%s'", uri.toString());
                Timber.tag(TAG).w(msg);
                promise.reject("E_IO_EXCEPTION", msg);
            }

            // Crop the center square of the image
            int minDim = Math.min(bitmap.getWidth(), bitmap.getHeight());
            int cropX = (bitmap.getWidth() - minDim) / 2;
            int cropY = (bitmap.getHeight() - minDim) / 2;
            Bitmap croppedBitmap = Bitmap.createBitmap(bitmap, cropX, cropY, minDim, minDim);

            // Resize to expected classifier input size
            Bitmap rescaledBitmap = Bitmap.createScaledBitmap(
                    croppedBitmap,
                    ImageClassifier.DIM_IMG_SIZE_X,
                    ImageClassifier.DIM_IMG_SIZE_Y,
                    true);
            bitmap.recycle();
            bitmap = rescaledBitmap;
        } catch (Exception e) {
            e.printStackTrace();
            promise.reject("E_IO_EXCEPTION", "Couldn't read input file: " + uri.toString() + "; Exception: " + e);
            return;
        }

        List<Prediction> predictions = classifier.classifyFrame(bitmap);
        bitmap.recycle();


        WritableArray cleanedPredictions = Arguments.createArray();
        for (Prediction prediction : predictions) {
            // only KPCOFGS ranks qualify as "top" predictions
            // in the iNat taxonomy, KPCOFGS ranks are 70,60,50,40,30,20,10
            if (prediction.rank % 10 != 0) {
              continue;
            }
            if (prediction.probability > mConfidenceThreshold) {
                WritableMap map = Taxonomy.nodeToMap(prediction);
                if (map == null) continue;
                cleanedPredictions.pushMap(map);
            }
        }

        WritableMap resultMap = Arguments.createMap();
        resultMap.putArray("predictions", cleanedPredictions);
        promise.resolve(resultMap);
    }
}
