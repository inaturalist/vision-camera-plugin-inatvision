package com.visioncameraplugininatvision;

import android.graphics.Bitmap;
import android.util.Log;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Collection;
import androidx.camera.core.ImageProxy;
import com.facebook.react.bridge.WritableNativeArray;
import com.facebook.react.bridge.WritableNativeMap;
import com.mrousavy.camera.frameprocessor.FrameProcessorPlugin;
import org.jetbrains.annotations.NotNull;
import timber.log.*;
import java.io.IOException;

public class VisionCameraPluginInatVisionPlugin extends FrameProcessorPlugin {
  private ImageClassifier mImageClassifier = null;

  public static final float DEFAULT_CONFIDENCE_THRESHOLD = 0.7f;
  private float mConfidenceThreshold = DEFAULT_CONFIDENCE_THRESHOLD;

  private final static String TAG = "VisionCameraPluginInatVisionPlugin";

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

  public void setNegativeFilter(boolean negative) {
      mNegativeFilter = negative;
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

    // The third parameter is the confidence threshold
    String confidenceThreshold = (String)params[2];
    // The fourth parameter is the taxon ID to filter by
    String filterByTaxonId = (String)params[3];
    // The fifth parameter is negative filter
    Boolean negative = (Boolean)params[4];
    setConfidenceThreshold(Float.parseFloat(confidenceThreshold));
    setFilterByTaxonId(filterByTaxonId != null ? Integer.valueOf(filterByTaxonId) : null);
    setNegativeFilter(negative != null ? negative : false);

    // Image classifier initialization with model and taxonomy files
    if (mImageClassifier == null) {
      String modelPath = (String)params[0];
      String taxonomyPath = (String)params[1];
      Timber.tag(TAG).d("Initializing classifier: " + modelPath + " / " + taxonomyPath);

      try {
        mImageClassifier = new ImageClassifier(modelPath, taxonomyPath);
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

    WritableNativeArray results = new WritableNativeArray();

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
        false);
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
          WritableNativeMap map = Taxonomy.predictionToMap(prediction);
          if (map == null) continue;
          results.pushMap(map);
        }
      }
    }

    return results;
  }

  public VisionCameraPluginInatVisionPlugin() {
    super("inatVision");
  }
}
