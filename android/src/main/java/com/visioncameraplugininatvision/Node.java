package com.visioncameraplugininatvision;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public class Node {
    public String key;

    public String name;

    public String parentKey;

    public float rank;

    public String leafId;

    public Double geoThreshold;

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
    public Node(String[] headers, String line) {
        String[] parts = line.trim().split(",", headers.length);
        List<String> headerList = new ArrayList<>(Arrays.asList(headers));

        if (headerList.contains("parent_taxon_id")) {
          int parentTaxonIdIndex = headerList.indexOf("parent_taxon_id");
          this.parentKey = parts[parentTaxonIdIndex];
        }

        if (headerList.contains("taxon_id")) {
          int taxonIdIndex = headerList.indexOf("taxon_id");
          this.key = parts[taxonIdIndex];
        }

        if (headerList.contains("rank_level")) {
          int rankLevelIndex = headerList.indexOf("rank_level");
          this.rank = Float.parseFloat(parts[rankLevelIndex]);
        }

        if (headerList.contains("leaf_class_id")) {
          int leafClassIdIndex = headerList.indexOf("leaf_class_id");
          this.leafId = parts[leafClassIdIndex];
        }

        if (headerList.contains("geo_threshold")) {
          int spatialThresholdIndex = headerList.indexOf("geo_threshold");
          String spatialThreshold = parts[spatialThresholdIndex];
          if (spatialThreshold.length() > 0) {
            this.geoThreshold = Double.valueOf(parts[spatialThresholdIndex]);
          }
        }

        if (headerList.contains("name")) {
          int nameIndex = headerList.indexOf("name");
          this.name = parts[nameIndex];
        }
    }

    public Node() {
    }

    public void addChild(Node child) {
        children.add(child);
        child.parent = this;
    }

}

