package com.visioncameraplugininatvision;

import static java.lang.Math.PI;
import static java.lang.Math.cos;
import static java.lang.Math.sin;

import android.util.Log;

import org.tensorflow.lite.Interpreter;

import java.io.FileInputStream;
import java.io.IOException;
import java.nio.MappedByteBuffer;
import java.nio.channels.FileChannel;
import java.util.List;

import timber.log.Timber;

/** Classifies locations (latitude, longitude, elevation) with Tensorflow Lite. */
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

    /** Instance variables to cache the geomodel results */
    private final float mLocationChangeThreshold = 0.001f;
    private float[][] mCachedGeoResult;
    private double mCachedLatitude;
    private double mCachedLongitude;
    private double mCachedElevation;

    /** Initializes a {@code GeoClassifier}. */
    public GeoClassifier(String modelPath, String taxonomyPath, String version) throws IOException {
        mModelFilename = modelPath;
        mTaxonomyFilename = taxonomyPath;
        mModelVersion = version;
        mTFlite = new Interpreter(loadModelFile());
        Timber.tag(TAG).d("Created a Tensorflow Lite Geomodel Classifier.");

        mTaxonomy = new Taxonomy(new FileInputStream(mTaxonomyFilename), mModelVersion);
        mModelSize = mTaxonomy.getModelSize();
    }

    /*
    * iNat geomodel input normalization documented here:
    * https://github.com/inaturalist/inatGeoModelTraining/tree/main#input-normalization
    */
    public float[] normAndEncodeLocation(double latitude, double longitude, double elevation) {
        double normLat = latitude / 90.0;
        double normLng = longitude / 180.0;
        double normElev;
        if (elevation > 0) {
            normElev = elevation / 5705.63;
        } else {
            normElev = elevation / 32768.0;
        }
        double a = sin(PI * normLng);
        double b = sin(PI * normLat);
        double c = cos(PI * normLng);
        double d = cos(PI * normLat);
        return new float[] { (float) a, (float) b, (float) c, (float) d, (float) normElev };
    }

    public float[][] predictionsForLocation(double latitude, double longitude, double elevation) {
        if (mCachedGeoResult == null ||
            Math.abs(latitude - mCachedLatitude) > mLocationChangeThreshold ||
            Math.abs(longitude - mCachedLongitude) > mLocationChangeThreshold ||
            Math.abs(elevation - mCachedElevation) > mLocationChangeThreshold)
        {
            float[][] results = classify(latitude, longitude, elevation);
            if (results != null && results.length > 0) {
                mCachedGeoResult = results;
                mCachedLatitude = latitude;
                mCachedLongitude = longitude;
                mCachedElevation = elevation;
            }
            return results;
        }

        return mCachedGeoResult;
    }

    public List<Prediction> expectedNearby(double latitude, double longitude, double elevation) {
        float[][] scores = predictionsForLocation(latitude, longitude, elevation);
        return mTaxonomy.expectedNearbyFromClassification(scores);
    }

    public float[][] classify(double latitude, double longitude, double elevation) {
        if (mTFlite == null) {
            Timber.tag(TAG).e("Geomodel classifier has not been initialized; Skipped.");
            return null;
        }

        // Get normalized inputs
        float[] normalizedInputs = normAndEncodeLocation(latitude, longitude, elevation);

        // Create input array with shape [1][5]
        float[][] inputArray = new float[1][5];
        inputArray[0] = normalizedInputs;

        // Create output array
        float[][] outputArray = new float[1][mModelSize];

        // Run inference
        try {
            mTFlite.run(inputArray, outputArray);
            return outputArray;
        } catch (Exception exc) {
            exc.printStackTrace();
            return new float[1][];
        } catch (OutOfMemoryError exc) {
            exc.printStackTrace();
            return new float[1][];
        }
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

