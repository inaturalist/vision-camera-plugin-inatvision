package com.visioncameraplugininatvision;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.SystemClock;
import android.util.Log;

import androidx.annotation.NonNull;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableNativeMap;
import com.facebook.react.module.annotations.ReactModule;

import java.io.IOException;
import java.util.List;
import java.util.Map;
import java.util.Objects;

import timber.log.Timber;

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
    public static final String OPTION_CROP_RATIO = "cropRatio";
    public static final String OPTION_USE_GEOMODEL = "useGeomodel";
    public static final String OPTION_GEOMODEL_PATH = "geomodelPath";
    public static final String OPTION_LOCATION = "location";
    public static final String OPTION_MODE = "mode";
    public static final String LATITUDE = "latitude";
    public static final String LONGITUDE = "longitude";
    public static final String ELEVATION = "elevation";

    public static final double DEFAULT_CROP_RATIO = 1.0;

    @ReactMethod
    public void getPredictionsForImage(ReadableMap options, Promise promise) {
        long startTime = SystemClock.uptimeMillis();
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
        String mode = options.hasKey(OPTION_MODE) ? options.getString(OPTION_MODE) : null;
        double cropRatio = options.hasKey(OPTION_CROP_RATIO) ? options.getDouble(OPTION_CROP_RATIO) : DEFAULT_CROP_RATIO;

        // Destructure geomodel parameters. Those can be null
        Boolean useGeomodel = options.hasKey(OPTION_USE_GEOMODEL) ? options.getBoolean(OPTION_USE_GEOMODEL) : null;
        String geomodelPath = options.hasKey(OPTION_GEOMODEL_PATH) ? options.getString(OPTION_GEOMODEL_PATH) : null;
        ReadableMap location = options.hasKey(OPTION_LOCATION) ? options.getMap(OPTION_LOCATION) : null;

        // Initialize and use geomodel if requested
        GeoClassifier geoClassifier = null;
        float[][] geomodelScores = null;
        if (useGeomodel != null && useGeomodel) {
            if (geomodelPath == null) {
              throw new RuntimeException("Geomodel scoring requested but path is null");
            }
            if (location == null) {
              throw new RuntimeException("Geomodel scoring requested but location is null");
            }
            Double latitude = location.hasKey(LATITUDE) ? location.getDouble(LATITUDE) : null;
            Double longitude = location.hasKey(LONGITUDE) ? location.getDouble(LONGITUDE) : null;
            Double elevation = location.hasKey(ELEVATION) ? location.getDouble(ELEVATION) : null;
            if (latitude == null || longitude == null || elevation == null) {
              throw new RuntimeException("Geomodel scoring requested but latitude, longitude, or elevation is null");
            }

            // Geomodel classifier initialization with model and taxonomy files
            Timber.tag(TAG).d("Initializing geo classifier: " + geomodelPath + " / " + taxonomyFilename);
            try {
              geoClassifier = new GeoClassifier(geomodelPath, taxonomyFilename, version);
            } catch (IOException e) {
              e.printStackTrace();
              throw new RuntimeException("Failed to initialize a geomodel classifier: " + e.getMessage());
            } catch (OutOfMemoryError e) {
              e.printStackTrace();
              throw new RuntimeException("Out of memory");
            } catch (Exception e) {
              e.printStackTrace();
              Timber.tag(TAG).w("Other type of exception - Device not supported - classifier failed to load - " + e);
              throw new RuntimeException("Android version is too old - needs to be at least 6.0");
            }
            geomodelScores = geoClassifier.predictionsForLocation(latitude, longitude, elevation);
        } else {
            Timber.tag(TAG).d("Not using geomodel.");
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
            Log.d(TAG, "originalBitmap: " + bitmap + ": " + bitmap.getWidth() + " x " + bitmap.getHeight());
            // Crop the center square of the frame with the given crop ratio
            int minDim = (int) Math.round(Math.min(bitmap.getWidth(), bitmap.getHeight()) * cropRatio);
            int cropX = (bitmap.getWidth() - minDim) / 2;
            int cropY = (bitmap.getHeight() - minDim) / 2;
            Log.d(TAG, "croppingParams: " + minDim + "; " + cropX + "; " + cropY);
            Bitmap croppedBitmap = Bitmap.createBitmap(bitmap, cropX, cropY, minDim, minDim);

            // Resize to expected classifier input size
            Bitmap rescaledBitmap = Bitmap.createScaledBitmap(
                    croppedBitmap,
                    ImageClassifier.DIM_IMG_SIZE_X,
                    ImageClassifier.DIM_IMG_SIZE_Y,
                    true);
            bitmap.recycle();
            bitmap = rescaledBitmap;
            Log.d(TAG, "rescaledBitmap: " + bitmap + ": " + bitmap.getWidth() + " x " + bitmap.getHeight());
        } catch (Exception e) {
            e.printStackTrace();
            promise.reject("E_IO_EXCEPTION", "Couldn't read input file: " + uri.toString() + "; Exception: " + e);
            return;
        }

        classifier.setGeomodelScores(geomodelScores);
        Boolean commonAncestorMode = Objects.equals(mode, "COMMON_ANCESTOR");
        // Does not set a taxonomyRollupCutoff here, i.e. uses the default value (top score * 0.001)
        List<Prediction> predictions = classifier.classifyBitmap(bitmap, null, commonAncestorMode);
        bitmap.recycle();

        WritableArray cleanedPredictions = Arguments.createArray();
        for (Prediction prediction : predictions) {
            Map map = Taxonomy.nodeToMap(prediction);
            if (map == null) continue;
            // Transform the Map to a ReadableMap
            ReadableMap readableMap = Arguments.makeNativeMap(map);
            cleanedPredictions.pushMap(readableMap);
        }

        long endTime = SystemClock.uptimeMillis();
        WritableMap resultMap = Arguments.createMap();
        resultMap.putArray("predictions", cleanedPredictions);
        resultMap.putMap("options", options);
        // Time elapsed on the native side; in seconds
        resultMap.putDouble("timeElapsed", (endTime - startTime) / 1000.0);
        promise.resolve(resultMap);
    }

  @ReactMethod
  public void getPredictionsForLocation(ReadableMap options, Promise promise) {
        long startTime = SystemClock.uptimeMillis();
        // Destructure the model path from the options map
        String geomodelPath = options.getString(OPTION_GEOMODEL_PATH);
        String taxonomyPath = options.getString(OPTION_TAXONOMY_PATH);
        ReadableMap location = options.getMap(OPTION_LOCATION);

        double latitude = location.getDouble(LATITUDE);
        double longitude = location.getDouble(LONGITUDE);
        double elevation = location.getDouble(ELEVATION);

        GeoClassifier classifier = null;
        try {
            classifier = new GeoClassifier(geomodelPath, taxonomyPath, "2.13");
        } catch (IOException e) {
            e.printStackTrace();
            promise.reject("E_CLASSIFIER", "Failed to initialize a geomodel mClassifier: " + e.getMessage());
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

        List<Prediction> predictions = classifier.expectedNearby(latitude, longitude, elevation);

        WritableArray cleanedPredictions = Arguments.createArray();
        for (Prediction prediction : predictions) {
            Map map = Taxonomy.nodeToMap(prediction);
            if (map == null) continue;
            // Transform the Map to a ReadableMap
            ReadableMap readableMap = Arguments.makeNativeMap(map);
            cleanedPredictions.pushMap(readableMap);
        }

        long endTime = SystemClock.uptimeMillis();
        WritableMap resultMap = Arguments.createMap();
        resultMap.putArray("predictions", cleanedPredictions);
        resultMap.putMap("options", options);
        // Time elapsed on the native side; in seconds
        resultMap.putDouble("timeElapsed", (endTime - startTime) / 1000.0);
        promise.resolve(resultMap);
  }
}
