import {
  scalePrediction,
} from '../index';
function prediction(overrides) {
  return {
    name: 'Test taxon',
    rank_level: 10,
    score: 0.5,
    combined_score: 0.5,
    vision_score: 0.5,
    geo_score: null,
    taxon_id: 1,
    ancestor_ids: [],
    ...overrides,
  };
}

describe('scalePrediction', () => {
  it('scales score fields to 0–100', () => {
    const scaled = scalePrediction(
      prediction({
        score: 0.42,
        vision_score: 0.35,
        geo_score: 0.2,
        geo_threshold: 0.15,
      }),
    );

    expect(scaled.score).toBe(42);
    expect(scaled.combined_score).toBe(42);
    expect(scaled.vision_score).toBe(35);
    expect(scaled.geo_score).toBe(20);
    expect(scaled.geo_threshold).toBe(15);
  });

  it('leaves null geo_score unchanged', () => {
    const scaled = scalePrediction(prediction({ geo_score: null }));

    expect(scaled.geo_score).toBeNull();
  });
});
