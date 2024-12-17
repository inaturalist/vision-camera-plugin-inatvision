package com.visioncameraplugininatvision;

import java.util.ArrayList;
import java.util.List;

public class Node {
    public String key;

    public String name;

    public String parentKey;

    public float rank;

    public String leafId;

    public String iconicId;

    public String spatialId;

    public String spatialThreshold;

    public transient Node parent;

    public transient List<Node> children = new ArrayList<>();

    public String toString() {
        return String.format("%s: %s (rank = %s; parent = %s)", key, name, rank, parent != null ? parent.key : "N/A");
    }

    // Initialize the node from a CSV line
    // Seek model 2.3, 2.4:
    // parent_taxon_id,taxon_id,rank_level,leaf_class_id,iconic_class_id,spatial_class_id,name
    // Seek model 1.0:
    // parent_taxon_id,taxon_id,rank_level,leaf_class_id,name
    public Node(String line, String version) {
        String[] parts = line.trim().split(",", 8);

        this.parentKey = parts[0];
        this.key = parts[1];
        this.rank = Float.parseFloat(parts[2]);
        this.leafId = parts[3];
        if (version.equals("1.0")) {
            this.name = parts[4];
        } else {
          this.iconicId = parts[4];
          this.spatialId = parts[5];
          if (version.equals("2.3") || version.equals("2.4")) {
            this.name = parts[6];
          } else {
            this.spatialThreshold = parts[6];
            this.name = parts[7];
          }
        }
    }

    public Node() {
    }

    public void addChild(Node child) {
        children.add(child);
        child.parent = this;
    }

}

