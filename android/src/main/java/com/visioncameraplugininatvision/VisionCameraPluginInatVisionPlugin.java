package com.visioncameraplugininatvision;

import android.graphics.Bitmap;
import android.media.Image;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.mrousavy.camera.frameprocessor.Frame;
import com.mrousavy.camera.frameprocessor.FrameProcessorPlugin;
import com.mrousavy.camera.frameprocessor.SharedArray;
import com.mrousavy.camera.frameprocessor.VisionCameraProxy;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import timber.log.Timber;

public class VisionCameraPluginInatVisionPlugin extends FrameProcessorPlugin {
  VisionCameraPluginInatVisionPlugin(VisionCameraProxy proxy, @Nullable Map<String, Object> options) {
    super();
    Log.d("VisionCameraPluginInatVisionPlugin", "initialized with options: " + options);
  }

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

  @Nullable
  @Override
  public Object callback(@NonNull Frame frame, @Nullable Map<String, Object> arguments) {
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
    String confidenceThreshold = (String)arguments.get("confidenceThreshold");
    if (confidenceThreshold == null) {
      confidenceThreshold = String.valueOf(DEFAULT_CONFIDENCE_THRESHOLD);
    }
    setConfidenceThreshold(Float.parseFloat(confidenceThreshold));

    String filterByTaxonId = (String)arguments.get("filterByTaxonId");
    if (filterByTaxonId != null) {
      setFilterByTaxonId(filterByTaxonId != null ? Integer.valueOf(filterByTaxonId) : null);
    }

    Boolean negativeFilter = (Boolean)arguments.get("negativeFilter");
    if (negativeFilter != null) {
      setNegativeFilter(negativeFilter != null ? negativeFilter : false);
    }

    SharedArray resizedFrameData = (SharedArray)arguments.get("resizedBuffer");
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

    List<Map> results = new ArrayList<>();

    if (mImageClassifier != null) {
      Bitmap bmp = BitmapUtils.getBitmap(image, patchedOrientationAndroid);
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
      List<Prediction> predictions = mImageClassifier.classifySharedArray(resizedFrameData);
      Log.d(TAG, "Predictions: " + predictions.size());

      for (Prediction prediction : predictions) {
        // only KPCOFGS ranks qualify as "top" predictions
        // in the iNat taxonomy, KPCOFGS ranks are 70,60,50,40,30,20,10
        if (prediction.rank % 10 != 0) {
          continue;
        }
        if (prediction.probability > mConfidenceThreshold) {
          Map map = Taxonomy.predictionToMap(prediction);
          if (map == null) continue;
          results.add(map);
        }
      }
    }

    return results;
  }
}
