package com.visioncameraplugininatvision;

import android.graphics.Bitmap;
import android.graphics.Color;
import android.util.Log;

import org.tensorflow.lite.Interpreter;

import java.io.FileInputStream;
import java.io.IOException;
import java.nio.BufferOverflowException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.MappedByteBuffer;
import java.nio.channels.FileChannel;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import timber.log.Timber;

/** Classifies images with Tensorflow Lite. */
public class ImageClassifier {

    /** Tag for the {@link Log}. */
    private static final String TAG = "ImageClassifier";

    /** Dimensions of inputs. */
    private static final int DIM_BATCH_SIZE = 1;

    private static final int DIM_PIXEL_SIZE = 3;

    public static final int DIM_IMG_SIZE_X = 299;
    public static final int DIM_IMG_SIZE_Y = 299;

    private static final int IMAGE_MEAN = 128;
    private static final float IMAGE_STD = 128.0f;

    private final Taxonomy mTaxonomy;
    private final String mModelFilename;
    private final String mTaxonomyFilename;
    private final String mModelVersion;
    private int mModelSize;

    /* Preallocated buffers for storing image data in. */
    private int[] intValues = new int[DIM_IMG_SIZE_X * DIM_IMG_SIZE_Y];

    /** An instance of the driver class to run model inference with Tensorflow Lite. */
    private Interpreter mTFlite;

    /** A ByteBuffer to hold image data, to be feed into Tensorflow Lite as inputs. */
    private ByteBuffer imgData;

    private float[][] mGeomodelScores;

    public void setFilterByTaxonId(Integer taxonId) {
        mTaxonomy.setFilterByTaxonId(taxonId);
    }

    public Integer getFilterByTaxonId() {
        return mTaxonomy.getFilterByTaxonId();
    }

    public void setNegativeFilter(boolean negative) {
        mTaxonomy.setNegativeFilter(negative);
    }

    public boolean getNegativeFilter() {
        return mTaxonomy.getNegativeFilter();
    }

    public void setGeomodelScores(float[][] scores) {
        mGeomodelScores = scores;
    }

    /** Initializes an {@code ImageClassifier}. */
    public ImageClassifier(String modelPath, String taxonomyPath, String version) throws IOException {
        mModelFilename = modelPath;
        mTaxonomyFilename = taxonomyPath;
        mModelVersion = version;
        mTFlite = new Interpreter(loadModelFile());
        imgData =
                ByteBuffer.allocateDirect(
                        4 * DIM_BATCH_SIZE * DIM_IMG_SIZE_X * DIM_IMG_SIZE_Y * DIM_PIXEL_SIZE);
        imgData.order(ByteOrder.nativeOrder());
        Timber.tag(TAG).d("Created a Tensorflow Lite Image Classifier.");

        mTaxonomy = new Taxonomy(new FileInputStream(mTaxonomyFilename), mModelVersion);
        mModelSize = mTaxonomy.getModelSize();
    }

    /** Classifies a frame from the preview stream. */
    public List<Prediction> classifyBitmap(Bitmap bitmap, Double taxonomyRollupCutoff) {
        if (mTFlite == null) {
            Timber.tag(TAG).e("Image classifier has not been initialized; Skipped.");
            return null;
        }
        if (bitmap == null) {
            Timber.tag(TAG).e("Null input bitmap");
            return null;
        }
        convertBitmapToByteBuffer(bitmap);

        byte[] arr = new byte[imgData.remaining()];
        imgData.get(arr);

        Map<Integer, Object> expectedOutputs = new HashMap<>();
        for (int i = 0; i < 1; i++) {
            expectedOutputs.put(i, new float[1][mModelSize]);
        }

        Object[] input = { imgData };
        List<Prediction> predictions = null;
        try {
            mTFlite.runForMultipleInputsOutputs(input, expectedOutputs);
            predictions = mTaxonomy.predict(expectedOutputs, taxonomyRollupCutoff);
        } catch (Exception exc) {
            exc.printStackTrace();
            return new ArrayList<Prediction>();
        } catch (OutOfMemoryError exc) {
            exc.printStackTrace();
            return new ArrayList<Prediction>();
        }

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

    /** Writes Image data into a {@code ByteBuffer}. */
    private void convertBitmapToByteBuffer(Bitmap bitmap) {
        if (imgData == null) {
            return;
        }
        imgData.rewind();

        // Convert pixel values to be float from 0 to 1
        float[][][][] input = new float[1][ImageClassifier.DIM_IMG_SIZE_X][ImageClassifier.DIM_IMG_SIZE_Y][3];
        for (int x = 0; x < ImageClassifier.DIM_IMG_SIZE_X; x++) {
            for (int y = 0; y < ImageClassifier.DIM_IMG_SIZE_Y; y++) {
                int pixel = bitmap.getPixel(x, y);
                if (mModelVersion.equals("1.0")) {
                  // Normalize channel values to [0.0, 1.0] for version 1.0
                  input[0][x][y][0] = Color.red(pixel) / 255.0f;
                  input[0][x][y][1] = Color.green(pixel) / 255.0f;
                  input[0][x][y][2] = Color.blue(pixel) / 255.0f;
                } else {
                  input[0][x][y][0] = Color.red(pixel);
                  input[0][x][y][1] = Color.green(pixel);
                  input[0][x][y][2] = Color.blue(pixel);
                }
            }
        }
        // Convert to ByteBuffer
        try {
            ByteBuffer byteBuffer = ByteBuffer.allocateDirect(4 * input.length * input[0].length * input[0][0].length * input[0][0][0].length);
            byteBuffer.order(ByteOrder.nativeOrder());
            for (int i = 0; i < input.length; i++) {
                for (int j = 0; j < input[0].length; j++) {
                    for (int k = 0; k < input[0][0].length; k++) {
                        for (int l = 0; l < input[0][0][0].length; l++) {
                            byteBuffer.putFloat(input[i][j][k][l]);
                        }
                    }
                }
            }
            byteBuffer.rewind();
            imgData.put(byteBuffer);
        } catch (BufferOverflowException exc) {
            Timber.tag(TAG).w("Exception while converting to byte buffer: " + exc);
        }
    }

    /** Combines vision and geo model scores */
    private float[] combineVisionScores(float[] visionScores, float[] geoScores) {
        float[] combinedScores = new float[visionScores.length];

        for (int i = 0; i < visionScores.length; i++) {
            float visionScore = visionScores[i];
            float geoScore = geoScores[i];

            // Combine scores using weighted average
            combinedScores[i] = visionScore * geoScore;
        }

        return combinedScores;
    }

}

