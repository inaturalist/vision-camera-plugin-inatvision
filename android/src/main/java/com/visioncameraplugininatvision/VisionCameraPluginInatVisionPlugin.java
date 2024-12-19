package com.visioncameraplugininatvision;

import android.graphics.Bitmap;
import android.media.Image;
import android.os.SystemClock;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.mrousavy.camera.core.FrameInvalidError;
import com.mrousavy.camera.frameprocessors.Frame;
import com.mrousavy.camera.frameprocessors.FrameProcessorPlugin;
import com.mrousavy.camera.frameprocessors.VisionCameraProxy;

import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import timber.log.Timber;

public class VisionCameraPluginInatVisionPlugin extends FrameProcessorPlugin {
  VisionCameraPluginInatVisionPlugin(@NonNull VisionCameraProxy proxy, @Nullable Map<String, Object> options) {
    super();
    Log.d("VisionCameraPluginInatVisionPlugin", "initialized with options: " + options);
  }

  private final static String TAG = "VisionCameraPluginInatVisionPlugin";

  private ImageClassifier mImageClassifier = null;
  private GeoClassifier mGeoClassifier = null;

  private Integer mFilterByTaxonId = null; // If null -> no filter by taxon ID defined
  public void setFilterByTaxonId(Integer taxonId) {
      mFilterByTaxonId = taxonId;
      if (mImageClassifier != null) {
          mImageClassifier.setFilterByTaxonId(mFilterByTaxonId);
      }
  }

  private boolean mNegativeFilter = false;
  public void setNegativeFilter(boolean negativeFilter) {
      mNegativeFilter = negativeFilter;
      if (mImageClassifier != null) {
        mImageClassifier.setNegativeFilter(mNegativeFilter);
      }
  }

  private double mCropRatio = 1.0;
  public void setCropRatio(double cropRatio) {
      mCropRatio = cropRatio;
  }

  @Override
  public Object callback(@NonNull Frame frame, @Nullable Map<String, Object> arguments) throws FrameInvalidError {
    long startTime = SystemClock.uptimeMillis();
    Image image = frame.getImage();
    // This should give the orientation of the passed in frame, as of vision-camera v3.2.2 this is not working though
    // instead we use a string passed in via the arguments to signify the device orientation
    // String orientation = frame.getOrientation();
    Log.d(TAG, "1: " + image.getWidth() + " x " + image.getHeight() + " Image with format #" + image.getFormat() + ". Logging " + arguments.size());

    for (String key : arguments.keySet()) {
        Object value = arguments.get(key);
        Log.d(TAG, "2: " + "  -> " + (value == null ? "(null)" : value + " (" + value.getClass().getName() + ")"));
    }

    if (arguments == null) {
      throw new RuntimeException("Options object is null");
    };
    // Destructure the version from the arguments map
    String version = (String)arguments.get("version");
    if (version == null) {
      throw new RuntimeException("Version is null");
    };
    // Destructure the model path from the arguments map
    String modelPath = (String)arguments.get("modelPath");
    if (modelPath == null) {
      throw new RuntimeException("Model path is null");
    };
    // Destructure the taxonomy path from the arguments map
    String taxonomyPath = (String)arguments.get("taxonomyPath");
    if (taxonomyPath == null) {
      throw new RuntimeException("Taxonomy path is null");
    };

    String patchedOrientationAndroid = (String)arguments.get("patchedOrientationAndroid");
    if (patchedOrientationAndroid == null) {
      throw new RuntimeException("patchedOrientationAndroid must be a string passing in the current device orientation");
    }

    // Destructure optional parameters and set values
    String filterByTaxonId = (String)arguments.get("filterByTaxonId");
    setFilterByTaxonId(filterByTaxonId != null ? Integer.valueOf(filterByTaxonId) : null);

    Boolean negativeFilter = (Boolean)arguments.get("negativeFilter");
    if (negativeFilter != null) {
      setNegativeFilter(negativeFilter);
    }

    Double taxonomyRollupCutoff = (Double)arguments.get("taxonomyRollupCutoff");

    Double cropRatio = (Double)arguments.get("cropRatio");
    if (cropRatio != null) {
      setCropRatio(cropRatio);
    }

    // Destructure geomodel parameters. Those can be null
    Boolean useGeomodel = (Boolean)arguments.get("useGeomodel");
    String geomodelPath = (String)arguments.get("geomodelPath");
    Map<String, Double> location = (Map<String, Double>)arguments.get("location");

    // Initialize and use geomodel if requested
    float[][] geomodelScores = null;
    if (useGeomodel != null && useGeomodel) {
        if (geomodelPath == null) {
          throw new RuntimeException("Geomodel scoring requested but path is null");
        }
        if (location == null) {
          throw new RuntimeException("Geomodel scoring requested but location is null");
        }
        Double latitude = location.get("latitude");
        Double longitude = location.get("longitude");
        Double elevation = location.get("elevation");

        // Geomodel classifier initialization with model and taxonomy files
        if (mGeoClassifier == null) {
          Timber.tag(TAG).d("Initializing geo classifier: " + geomodelPath + " / " + taxonomyPath);
          try {
            mGeoClassifier = new GeoClassifier(geomodelPath, taxonomyPath, version);
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
        }
        geomodelScores = mGeoClassifier.classify(latitude, longitude, elevation);
    } else {
        Timber.tag(TAG).d("Not using geomodel for this frame.");
    }

    // Image classifier initialization with model and taxonomy files
    if (mImageClassifier == null) {
      Timber.tag(TAG).d("Initializing classifier: " + modelPath + " / " + taxonomyPath);

      try {
        mImageClassifier = new ImageClassifier(modelPath, taxonomyPath, version);
        setFilterByTaxonId(mFilterByTaxonId);
        setNegativeFilter(mNegativeFilter);
      } catch (IOException e) {
        e.printStackTrace();
        throw new RuntimeException("Failed to initialize an image mClassifier: " + e.getMessage());
      } catch (OutOfMemoryError e) {
        e.printStackTrace();
        Timber.tag(TAG).w("Out of memory - Device not supported - classifier failed to load - " + e);
        throw new RuntimeException("Out of memory");
      } catch (Exception e) {
        e.printStackTrace();
        Timber.tag(TAG).w("Other type of exception - Device not supported - classifier failed to load - " + e);
        throw new RuntimeException("Android version is too old - needs to be at least 6.0");
      }
    }

    List<Map> cleanedPredictions = new ArrayList<>();
    if (mImageClassifier != null) {
      mImageClassifier.setGeomodelScores(geomodelScores);
      Bitmap bmp = BitmapUtils.getBitmap(image, patchedOrientationAndroid);
      Log.d(TAG, "originalBitmap: " + bmp + ": " + bmp.getWidth() + " x " + bmp.getHeight());
      // Crop the center square of the frame
      int minDim = (int) Math.round(Math.min(bmp.getWidth(), bmp.getHeight()) * mCropRatio);
      int cropX = (bmp.getWidth() - minDim) / 2;
      int cropY = (bmp.getHeight() - minDim) / 2;
      Log.d(TAG, "croppingParams: " + minDim + "; " + cropX + "; " + cropY);
      Bitmap croppedBitmap = Bitmap.createBitmap(bmp, cropX, cropY, minDim, minDim);

      // Resize to expected classifier input size
      Bitmap rescaledBitmap = Bitmap.createScaledBitmap(
        croppedBitmap,
        ImageClassifier.DIM_IMG_SIZE_X,
        ImageClassifier.DIM_IMG_SIZE_Y,
        true);
      bmp.recycle();
      bmp = rescaledBitmap;
      Log.d(TAG, "rescaledBitmap: " + bmp + ": " + bmp.getWidth() + " x " + bmp.getHeight());
      List<Prediction> predictions = mImageClassifier.classifyBitmap(bmp, taxonomyRollupCutoff);
      bmp.recycle();
      croppedBitmap.recycle();

      Log.d(TAG, "Predictions: " + predictions.size());

      for (Prediction prediction : predictions) {
        Map map = Taxonomy.nodeToMap(prediction);
        if (map == null) continue;
        cleanedPredictions.add(map);
      }
    }

    long endTime = SystemClock.uptimeMillis();
    Map<String, Object> resultMap = new HashMap<>();
    resultMap.put("predictions", cleanedPredictions);
    // Time elapsed on the native side; in seconds
    resultMap.put("timeElapsed", (endTime - startTime) / 1000.0);
    return resultMap;
  }
}
