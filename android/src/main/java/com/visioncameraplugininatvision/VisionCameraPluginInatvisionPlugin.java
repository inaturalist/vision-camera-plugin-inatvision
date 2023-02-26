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

public class VisionCameraPluginInatvisionPlugin extends FrameProcessorPlugin {
  private ImageClassifier mImageClassifier = null;

  public static final float DEFAULT_CONFIDENCE_THRESHOLD = 0.7f;
  private final static String TAG = "VisionCameraPluginInatvisionPlugin";

  @Override
  public Object callback(@NotNull ImageProxy frame, @NotNull Object[] params) {
    Log.d(TAG, "2: " + frame.getWidth() + " x " + frame.getHeight() + " frame with format #" + frame.getFormat() + ". Logging " + params.length + " parameters:" + params.length);
    for (Object param : params) {
      Log.d(TAG, "  -> " + (param == null ? "(null)" : param.toString() + " (" + param.getClass().getName() + ")"));
    }

    // Image classifier initialization with model and taxonomy files
    if (mImageClassifier == null) {
      String modelPath = (String)params[0];
      String taxonomyPath = (String)params[1];
      Log.d(TAG, "Initializing classifier: " + modelPath + " / " + taxonomyPath);

      try {
        mImageClassifier = new ImageClassifier(modelPath, taxonomyPath);
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

    WritableNativeMap result = new WritableNativeMap();

    if (mImageClassifier != null) {
      Bitmap bmp = BitmapUtils.getBitmap(frame);
      // Resize to expected classifier input size
      Bitmap rescaledBitmap = Bitmap.createScaledBitmap(
        bmp,
        ImageClassifier.DIM_IMG_SIZE_X,
        ImageClassifier.DIM_IMG_SIZE_Y,
        false);
      bmp.recycle();
      bmp = rescaledBitmap;
      Log.d(TAG, "getBitmap: " + bmp + ": " + bmp.getWidth() + " x " + bmp.getHeight());
      List<Prediction> predictions = mImageClassifier.classifyFrame(bmp);
      Log.d(TAG, "Predictions: " + predictions.size());

      // Return only one prediction, as accurate as possible (e.g. prefer species over family), that passes the minimal threshold
      Prediction selectedPrediction = null;

      Collections.reverse(predictions);
      for (Prediction prediction : predictions) {
        // only KPCOFGS ranks qualify as "top" predictions
        // in the iNat taxonomy, KPCOFGS ranks are 70,60,50,40,30,20,10
        if (prediction.rank % 10 != 0) {
          continue;
        }
        if (prediction.probability > DEFAULT_CONFIDENCE_THRESHOLD) {
          selectedPrediction = prediction;
          break;
        }
      }

      WritableNativeArray results = new WritableNativeArray();
      if (selectedPrediction != null) {
        results.pushMap(Taxonomy.predictionToMap(selectedPrediction));
      }

      result.putArray("predictions", results);
    }

    return result;
  }

  public VisionCameraPluginInatvisionPlugin() {
    super("inatVision");
  }
}
