package com.visioncameraplugininatvision;

import android.util.Log;

import org.tensorflow.lite.Interpreter;

import java.io.FileInputStream;
import java.io.IOException;
import java.nio.MappedByteBuffer;
import java.nio.channels.FileChannel;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import timber.log.Timber;

/** Classifies images with Tensorflow Lite. */
public class GeoClassifier {

    /** Tag for the {@link Log}. */
    private static final String TAG = "GeoClassifier";

    private final Taxonomy mTaxonomy;
    private final String mModelFilename;
    private final String mTaxonomyFilename;
    private final String mModelVersion;
    private int mModelSize;

    /** An instance of the driver class to run model inference with Tensorflow Lite. */
    private Interpreter mTFlite;

    /** Initializes an {@code GeoClassifier}. */
    public GeoClassifier(String modelPath, String taxonomyPath, String version) throws IOException {
        mModelFilename = modelPath;
        mTaxonomyFilename = taxonomyPath;
        mModelVersion = version;
        mTFlite = new Interpreter(loadModelFile());
        Timber.tag(TAG).d("Created a Tensorflow Lite Geo Model Classifier.");

        mTaxonomy = new Taxonomy(new FileInputStream(mTaxonomyFilename), mModelVersion);
        mModelSize = mTaxonomy.getModelSize();
    }

    /** Classifies a frame from the preview stream. */
    // public List<Prediction> classifyFrame(Bitmap bitmap) {
    //     if (mTFlite == null) {
    //         Timber.tag(TAG).e("Image classifier has not been initialized; Skipped.");
    //         return null;
    //     }
    //     if (bitmap == null) {
    //         Timber.tag(TAG).e("Null input bitmap");
    //         return null;
    //     }

    //     long startTime = SystemClock.uptimeMillis();
    //     convertBitmapToByteBuffer(bitmap);

    //     byte[] arr = new byte[imgData.remaining()];
    //     imgData.get(arr);

    //     Map<Integer, Object> expectedOutputs = new HashMap<>();
    //     for (int i = 0; i < 1; i++) {
    //         expectedOutputs.put(i, new float[1][mModelSize]);
    //     }

    //     Object[] input = { imgData };
    //     List<Prediction> predictions = null;
    //     try {
    //         mTFlite.runForMultipleInputsOutputs(input, expectedOutputs);
    //         predictions = mTaxonomy.predict(expectedOutputs);
    //     } catch (Exception exc) {
    //         exc.printStackTrace();
    //         return new ArrayList<Prediction>();
    //     } catch (OutOfMemoryError exc) {
    //         exc.printStackTrace();
    //         return new ArrayList<Prediction>();
    //     }
    //     long endTime = SystemClock.uptimeMillis();

    //     return predictions;
    // }
    /*
    * iNat geo model input normalization documented here:
    * https://github.com/inaturalist/inatGeoModelTraining/tree/main#input-normalization
    */
    public TensorBuffer normAndEncodeLocation(double latitude, double longitude, double elevation) {
        double normLat = latitude / 90.0;
        double normLng = longitude / 180.0;
        double normElev = 0.0;
        if (elevation > 0) {
            normElev = elevation / 5705.63;
        } else {
            normElev = elevation / 32768.0;
        }
        double a = sin(PI * normLng);
        double b = sin(PI * normLat);
        double c = cos(PI * normLng);
        double d = cos(PI * normLat);
    }

    public List<Prediction> classifyLocation(double latitude, double longitude, double elevation) {
        if (mTFlite == null) {
            Timber.tag(TAG).e("Geo model classifier has not been initialized; Skipped.");
            return null;
        }
        List<Prediction> predictions = null;
        return predictions;
    }

    /** Closes tflite to release resources. */
    public void close() {
        mTFlite.close();
        mTFlite = null;
    }

    /** Memory-map the model file in Assets. */
    private MappedByteBuffer loadModelFile() throws IOException {
        FileInputStream inputStream = new FileInputStream(mModelFilename);
        FileChannel fileChannel = inputStream.getChannel();
        return fileChannel.map(FileChannel.MapMode.READ_ONLY, 0, inputStream.available());
    }
}

