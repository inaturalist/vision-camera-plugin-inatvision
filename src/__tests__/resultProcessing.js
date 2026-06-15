import {
  limitLeafPredictionsThatIncludeHumans,
  scalePrediction,
} from '../index';

const HUMAN_TAXON_ID = 43584;

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

describe('limitLeafPredictionsThatIncludeHumans', () => {
  it('returns an empty array unchanged', () => {
    expect(limitLeafPredictionsThatIncludeHumans([])).toEqual([]);
  });

  it('returns a single prediction unchanged', () => {
    const only = [prediction({ taxon_id: 123 })];

    expect(limitLeafPredictionsThatIncludeHumans(only)).toBe(only);
  });

  it('returns all predictions when humans are absent', () => {
    const predictions = [
      prediction({ taxon_id: 1, score: 0.9 }),
      prediction({ taxon_id: 2, score: 0.1 }),
    ];

    expect(limitLeafPredictionsThatIncludeHumans(predictions)).toEqual(
      predictions,
    );
  });

  it('returns only humans when they lead with a wide margin', () => {
    const human = prediction({ taxon_id: HUMAN_TAXON_ID, score: 0.9 });
    const other = prediction({ taxon_id: 2, score: 0.5 });

    expect(limitLeafPredictionsThatIncludeHumans([human, other])).toEqual([
      human,
    ]);
  });

  it('returns an empty array when humans lead but the margin is too small', () => {
    const human = prediction({ taxon_id: HUMAN_TAXON_ID, score: 0.6 });
    const other = prediction({ taxon_id: 2, score: 0.5 });

    expect(limitLeafPredictionsThatIncludeHumans([human, other])).toEqual([]);
  });

  it('returns an empty array when humans are not the top prediction', () => {
    const other = prediction({ taxon_id: 2, score: 0.9 });
    const human = prediction({ taxon_id: HUMAN_TAXON_ID, score: 0.5 });

    expect(limitLeafPredictionsThatIncludeHumans([other, human])).toEqual([]);
  });
});
