package com.visioncameraplugininatvision;

import com.facebook.react.bridge.WritableNativeArray;
import com.facebook.react.bridge.WritableNativeMap;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import timber.log.Timber;

/** Taxonomy data structure */
public class Taxonomy {
    private static final String TAG = "Taxonomy";

    private static final Map<Float, String> RANK_LEVEL_TO_NAME;
    static {
        Map<Float, String> map = new HashMap<>() ;

        map.put(100f, "stateofmatter");
        map.put(70f, "kingdom");
        map.put(67f, "subkingdom");
        map.put(60f, "phylum");
        map.put(57f, "subphylum");
        map.put(53f, "superclass");
        map.put(50f, "class");
        map.put(47f, "subclass");
        map.put(45f, "infraclass");
        map.put(43f, "superorder");
        map.put(40f, "order");
        map.put(37f, "suborder");
        map.put(35f, "infraorder");
        map.put(34.5f, "parvorder");
        map.put(34f, "zoosection");
        map.put(33.5f, "zoosubsection");
        map.put(33f, "superfamily");
        map.put(32f, "epifamily");
        map.put(30f, "family");
        map.put(27f, "subfamily");
        map.put(26f, "supertribe");
        map.put(25f, "tribe");
        map.put(24f, "subtribe");
        map.put(20f, "genus");
        map.put(15f, "subgenus");
        map.put(13f, "section");
        map.put(12f, "subsection");
        map.put(10f, "species");
        map.put(5f, "subspecies");

        RANK_LEVEL_TO_NAME = Collections.unmodifiableMap(map);
    }

    List<Node> mNodes;
    Map<String, Node> mNodeByKey;
    List<Node> mLeaves; // this is a convenience array for testing
    Node mLifeNode;

    private Integer mFilterByTaxonId = null; // If null -> no filter by taxon ID defined
    private boolean mNegativeFilter = false;

    public void setFilterByTaxonId(Integer taxonId) {
        Timber.tag(TAG).d("setFilterByTaxonId: " + taxonId);
        mFilterByTaxonId = taxonId;
    }

    public Integer getFilterByTaxonId() {
        return mFilterByTaxonId;
    }

    public void setNegativeFilter(boolean negative) {
        Timber.tag(TAG).d("setNegativeFilter: " + negative);
        mNegativeFilter = negative;
    }

    public boolean getNegativeFilter() {
        return mNegativeFilter;
    }

    Taxonomy(InputStream is) {
        // Read the taxonomy CSV file into a list of nodes

        BufferedReader reader = new BufferedReader(new InputStreamReader(is));
        try {
            reader.readLine(); // Skip the first line (header line)

            mNodes = new ArrayList<>();
            mLeaves = new ArrayList<>();
            for (String line; (line = reader.readLine()) != null; ) {
                Node node = new Node(line);
                mNodes.add(node);
                if ((node.leafId != null) && (node.leafId.length() > 0)) {
                    mLeaves.add(node);
                }
            }
        } catch (IOException e) {
            e.printStackTrace();
        }

        // Convert list of nodes into a structure with parents and children
        mNodeByKey = new HashMap<>();

        mLifeNode = createLifeNode();

        for (Node node: mNodes) {
            mNodeByKey.put(node.key, node);
        }

        List<Node> lifeList = new ArrayList<Node>();
        lifeList.add(mLifeNode);

        for (Node node: mNodes) {
            if ((node.parentKey != null) && (node.parentKey.length() > 0)) {
                Node parent = mNodeByKey.get(node.parentKey);
                parent.addChild(node);
            } else {
                mLifeNode.addChild(node);
            }
        }

    }

    private Node createLifeNode() {
        Node node = new Node();
        node.key = "48460";
        node.rank = 100;
        node.name = "Life";
        node.parent = null;
        return node;
    }

    public int getModelSize() {
        return mLeaves.size();
    }

    public List<Prediction> predict(Map<Integer, Object> outputs) {
        // Get raw predictions
        float[] results = ((float[][]) outputs.get(0))[0];

        Map<String, Float> scores = aggregateScores(results);
        List<Prediction> bestBranch = buildBestBranchFromScores(scores);

        return bestBranch;
    }


    /** Aggregates scores for nodes, including non-leaf nodes (so each non-leaf node has a score of the sum of all its dependents) */
    private Map<String, Float> aggregateScores(float[] results) {
        return aggregateScores(results, mLifeNode);
    }

    /** Following: https://github.com/inaturalist/inatVisionAPI/blob/multiclass/inferrers/multi_class_inferrer.py#L136 */
    private Map<String, Float> aggregateScores(float[] results, Node currentNode) {
        Map<String, Float> allScores = new HashMap<>();

        if (currentNode.children.size() > 0) {
            // we'll populate this and return it

            for (Node child : currentNode.children) {
                Map<String, Float> childScores = aggregateScores(results, child);
                allScores.putAll(childScores);
            }

            float thisScore = 0.0f;
            for (Node child : currentNode.children) {
                thisScore += allScores.get(child.key);
            }

            allScores.put(currentNode.key, thisScore);

        } else {
            // base case, no children
            boolean resetScore = false;

            if (mFilterByTaxonId != null) {
                // Filter

                // Reset current prediction score if:
                // A) Negative filter + prediction does contain taxon ID as ancestor
                // B) Non-negative filter + prediction does not contain taxon ID as ancestor
                boolean containsAncestor = hasAncestor(currentNode, mFilterByTaxonId.toString());
                resetScore = (containsAncestor && mNegativeFilter) || (!containsAncestor && !mNegativeFilter);
            }

            allScores.put(currentNode.key, resetScore ? 0.0f : results[Integer.valueOf(currentNode.leafId)]);
        }

        return allScores;
    }

    /** Returns whether or not this taxon node has an ancestor with a specified taxon ID */
    private boolean hasAncestor(Node node, String taxonId) {
        if (node.key.equals(taxonId)) {
            return true;
        } else if (node.parent != null) {
            // Climb up the tree
            return hasAncestor(node.parent, taxonId);
        } else {
            // Reach to life node (root node) without finding that taxon ID
            return false;
        }
    }


    /** Finds the best branch from all result scores */
    private List<Prediction> buildBestBranchFromScores(Map<String, Float> scores) {
        List<Prediction> bestBranch = new ArrayList<>();

        // Start from life
        Node currentNode = mLifeNode;

        float lifeScore = scores.get(currentNode.key);
        Prediction lifePrediction = new Prediction(currentNode, lifeScore);
        bestBranch.add(lifePrediction);

        List<Node> currentNodeChildren = currentNode.children;

        // loop while the last current node (the previous best child node) has more children
        while (currentNodeChildren.size() > 0) {
            // find the best child of the current node
            Node bestChild = null;
            float bestChildScore = -1;
            for (Node child : currentNodeChildren) {
                float childScore = scores.get(child.key);
                if (childScore > bestChildScore) {
                    bestChildScore = childScore;
                    bestChild = child;
                }
            }

            if (bestChild != null) {
                Prediction bestChildPrediction = new Prediction(bestChild, bestChildScore);
                bestBranch.add(bestChildPrediction);
            }

            currentNode = bestChild;
            currentNodeChildren = currentNode.children;
        }

        return bestBranch;
    }

    /** Converts the predictions array into "clean" map of results (separated by rank), sent back to React Native */
    public static WritableNativeMap predictionToMap(Prediction prediction) {
        WritableNativeMap event = new WritableNativeMap();

        Map<Float, WritableNativeArray> ranks = new HashMap<>();

        WritableNativeMap result = nodeToMap(prediction);

        if (!ranks.containsKey(prediction.node.rank)) {
            ranks.put(prediction.node.rank, new WritableNativeArray());
        }

        ranks.get(prediction.node.rank).pushMap(result);

        // Convert from rank level to rank name
        for (Float rank : RANK_LEVEL_TO_NAME.keySet()) {
            if (ranks.containsKey(rank)) {
                event.putArray(RANK_LEVEL_TO_NAME.get(rank), ranks.get(rank));
            }
        }

        return event;
    }

    /** Converts a prediction result to a map */
    public static WritableNativeMap nodeToMap(Prediction prediction) {
        WritableNativeMap result = new WritableNativeMap();

        if (prediction.node == null) return null;

        try {
            result.putInt("taxon_id", Integer.valueOf(prediction.node.key));
            result.putString("name", prediction.node.name);
            result.putDouble("score", prediction.probability);
            result.putDouble("rank", prediction.node.rank);
        } catch (NumberFormatException exc) {
            // Invalid node key or class ID
            exc.printStackTrace();
            return null;
        }

        // Create the ancestors list for the result
        List<Integer> ancestorsList = new ArrayList<>();
        Node currentNode = prediction.node;
        while (currentNode.parent != null) {
            if ((currentNode.parent.key != null) && (currentNode.parent.key.matches("\\d+"))) {
                ancestorsList.add(Integer.valueOf(currentNode.parent.key));
            }
            currentNode = currentNode.parent;
        }
        Collections.reverse(ancestorsList);
        WritableNativeArray ancestors = new WritableNativeArray();
        for (Integer id : ancestorsList) {
            ancestors.pushInt(id);
        }

        result.putArray("ancestor_ids", ancestors);

        return result;
    }
}

