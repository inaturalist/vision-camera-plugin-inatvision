package com.visioncameraplugininatvision;

import android.graphics.Bitmap;
import android.util.Log;

import androidx.camera.core.ImageProxy;

import com.facebook.react.bridge.ReadableNativeMap;
import com.facebook.react.bridge.WritableNativeArray;
import com.facebook.react.bridge.WritableNativeMap;
import com.mrousavy.camera.frameprocessor.FrameProcessorPlugin;

import org.jetbrains.annotations.NotNull;

import java.io.IOException;
import java.util.List;

import timber.log.Timber;

public class VisionCameraPluginInatVisionPlugin extends FrameProcessorPlugin {
  private final static String TAG = "VisionCameraPluginInatVisionPlugin";

  private ImageClassifier mImageClassifier = null;

  public static final float DEFAULT_CONFIDENCE_THRESHOLD = 0.7f;
  private float mConfidenceThreshold = DEFAULT_CONFIDENCE_THRESHOLD;
  public void setConfidenceThreshold(float confidence) {
      mConfidenceThreshold = confidence;
  }

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

  @Override
  public Object callback(@NotNull ImageProxy frame, @NotNull Object[] params) {
    Log.d(TAG, "2: " + frame.getWidth() + " x " + frame.getHeight() + " frame with format #" + frame.getFormat() + ". Logging " + params.length + " parameters:" + params.length);
    for (Object param : params) {
      Log.d(TAG, "  -> " + (param == null ? "(null)" : param.toString() + " (" + param.getClass().getName() + ")"));
    }

    // The first parameter is the options object
    ReadableNativeMap options = (ReadableNativeMap)params[0];
    if (options == null) {
      throw new RuntimeException("Options object is null");
    };
    // Destructure the version from the options map
    String version = options.getString("version");
    if (version == null) {
      throw new RuntimeException("Version is null");
    };
    // Destructure the model path from the options map
    String modelPath = options.getString("modelPath");
    if (modelPath == null) {
      throw new RuntimeException("Model path is null");
    };
    // Destructure the taxonomy path from the options map
    String taxonomyPath = options.getString("taxonomyPath");
    if (taxonomyPath == null) {
      throw new RuntimeException("Taxonomy path is null");
    };

    // Destructure optional parameters and set values
    if (options.hasKey("confidenceThreshold")) {
      String confidenceThreshold = options.getString("confidenceThreshold");
      if (confidenceThreshold == null) {
        confidenceThreshold = String.valueOf(DEFAULT_CONFIDENCE_THRESHOLD);
      }
      setConfidenceThreshold(Float.parseFloat(confidenceThreshold));
    }
    if (options.hasKey("filterByTaxonId")) {
      String filterByTaxonId = options.getString("filterByTaxonId");
      setFilterByTaxonId(filterByTaxonId != null ? Integer.valueOf(filterByTaxonId) : null);
    }
    if (options.hasKey("negativeFilter")) {
      Boolean negativeFilter = options.getBoolean("negativeFilter");
      setNegativeFilter(negativeFilter != null ? negativeFilter : false);
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

    WritableNativeArray cleanedPredictions = new WritableNativeArray();
    if (mImageClassifier != null) {
      Bitmap bmp = BitmapUtils.getBitmap(frame);
      // Crop the center square of the frame
      int minDim = Math.min(bmp.getWidth(), bmp.getHeight());
      int cropX = (bmp.getWidth() - minDim) / 2;
      int cropY = (bmp.getHeight() - minDim) / 2;
      Bitmap croppedBitmap = Bitmap.createBitmap(bmp, cropX, cropY, minDim, minDim);

      // Resize to expected classifier input size
      Bitmap rescaledBitmap = Bitmap.createScaledBitmap(
        croppedBitmap,
        ImageClassifier.DIM_IMG_SIZE_X,
        ImageClassifier.DIM_IMG_SIZE_Y,
        true);
      bmp.recycle();
      bmp = rescaledBitmap;
      Log.d(TAG, "getBitmap: " + bmp + ": " + bmp.getWidth() + " x " + bmp.getHeight());
      List<Prediction> predictions = mImageClassifier.classifyFrame(bmp);
      bmp.recycle();
      Log.d(TAG, "Predictions: " + predictions.size());

      for (Prediction prediction : predictions) {
        // only KPCOFGS ranks qualify as "top" predictions
        // in the iNat taxonomy, KPCOFGS ranks are 70,60,50,40,30,20,10
        if (prediction.rank % 10 != 0) {
          continue;
        }
        if (prediction.probability > mConfidenceThreshold) {
          WritableNativeMap map = Taxonomy.nodeToMap(prediction);
          if (map == null) continue;
          cleanedPredictions.pushMap(map);
        }
      }
    }

    WritableNativeMap resultMap = new WritableNativeMap();
    resultMap.putArray("predictions", cleanedPredictions);
    return resultMap;
  }

  public VisionCameraPluginInatVisionPlugin() {
    super("inatVision");
  }
}
