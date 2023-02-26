package com.visioncameraplugininatvision;

public class Prediction {
    public Node node;
    public Double probability;
    public Float rank;

    public Prediction(Node n, double p) {
        node = n;
        probability = p;
        rank = n.rank;
    }
}

