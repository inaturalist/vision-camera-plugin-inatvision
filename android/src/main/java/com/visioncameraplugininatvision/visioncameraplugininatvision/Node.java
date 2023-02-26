package org.inaturalist.seek.inatvisionframeprocessorplugin;

import java.util.ArrayList;
import java.util.List;

public class Node {
    public String key;

    public String name;

    public String parentKey;

    public float rank;

    public String leafId;

    public transient Node parent;

    public transient List<Node> children = new ArrayList<>();

    public String toString() {
        return String.format("%s: %s (rank = %s; parent = %s)", key, name, rank, parent != null ? parent.key : "N/A");
    }

    // Initialize the node from a CSV line
    // NEW:
    // parent_taxon_id,taxon_id,rank_level,leaf_class_id,name
    // OLD:
    // parent_taxon_id,taxon_id,class_id,rank_level,leaf_class_id,name
    public Node(String line) {
        String[] parts = line.trim().split(",", 6);

        this.parentKey = parts[0];
        this.key = parts[1];
        this.rank = Float.parseFloat(parts[2]);
        this.leafId = parts[3];
        this.name = parts[4];
    }

    public Node() {
    }

    public void addChild(Node child) {
        children.add(child);
        child.parent = this;
    }

}

