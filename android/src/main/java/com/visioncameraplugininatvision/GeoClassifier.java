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

