package com.visioncameraplugininatvision;

public class Prediction {
    public Node node;
    public Double score;
    public Double visionScore;
    public Double geoScore;
    public Float rank;

    public Prediction(Node n, double p, double vS, double gS) {
        node = n;
        score = p;
        visionScore = vS;
        geoScore = gS;
        rank = n.rank;
    }
}

