package com.visioncameraplugininatvision;

public class Prediction {
    public Node node;
    public Double score;
    public Float rank;

    public Prediction(Node n, double p) {
        node = n;
        score = p;
        rank = n.rank;
    }
}

