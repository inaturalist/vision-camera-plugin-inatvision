package com.visioncameraplugininatvision;

public class Prediction {
    public Node node;
    public Double score;
    public Double visionScore;
    public Double geoScore;
    public Float rank;

    public Prediction(Node n, float p, float vS, Float gS) {
        node = n;
        score = (double) p;
        visionScore = (double) vS;
        if (gS != null) {
          geoScore = Double.valueOf(gS);
        }
        rank = n.rank;
    }
}

