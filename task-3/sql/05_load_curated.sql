-- =============================================================================
-- Task 3 | Week 3 Internship Assessment
-- LOAD CURATED TABLES (Idempotent Upserts)
-- Agribusiness ETL Process Plan
-- Database: PostgreSQL 15+
-- =============================================================================
-- Run AFTER 04_transform_validate.sql.
-- All loads are wrapped in a transaction per batch.
-- ON CONFLICT rules make every batch safe to rerun.
-- Watermark (status = 'loaded') is advanced ONLY after a successful commit.
-- =============================================================================

-- =============================================================================
-- BATCH 1: Load market prices into curated market_price table
-- =============================================================================
BEGIN;

INSERT INTO market_price
    (market_id, crop_id, observed_on, price_per_tonne, currency_code)
SELECT
    m.market_id,
    ca.crop_id,
    p.observed_on,
    p.price_per_tonne,
    p.currency_code
FROM parsed_market_price  p
JOIN market_alias         ma ON  ma.source_name         = 'agmarknet'
                             AND ma.source_market_label  = p.market_name
JOIN crop_alias           ca ON  ca.source_name         = 'agmarknet'
                             AND ca.source_crop_label    = p.crop_label
JOIN market               m  ON  m.market_id            = ma.market_id
WHERE p.observed_on   IS NOT NULL
  AND p.price_per_tonne >= 0
  AND p.currency_code IS NOT NULL
ON CONFLICT (market_id, crop_id, observed_on, currency_code)
DO UPDATE SET price_per_tonne = EXCLUDED.price_per_tonne;

-- Update batch status and loaded_rows count
UPDATE etl_batch
SET status      = 'loaded',
    loaded_rows = (
        SELECT COUNT(*)
        FROM parsed_market_price p
        JOIN market_alias  ma ON ma.source_name        = 'agmarknet'
                              AND ma.source_market_label = p.market_name
        JOIN crop_alias    ca ON ca.source_name        = 'agmarknet'
                              AND ca.source_crop_label  = p.crop_label
        WHERE p.observed_on IS NOT NULL
          AND p.price_per_tonne >= 0
    )
WHERE batch_id = 'a1000000-0000-0000-0000-000000000001'::uuid;

COMMIT;

-- =============================================================================
-- BATCH 2: Load crop production stats into curated crop_production_stat table
-- =============================================================================
BEGIN;

INSERT INTO crop_production_stat
    (geography_id, crop_id, period_start, period_end,
     area_harvested_ha, production_quantity, standard_unit, source_id)
SELECT
    ga.geography_id,
    ca.crop_id,
    p.period_start,
    p.period_end,
    p.area_harvested_ha,
    p.production_qty,
    p.std_unit,
    p.batch_id
FROM parsed_crop_production p
JOIN geography_alias ga ON ga.source_name     = 'faostat'
                        AND ga.source_geo_code = p.geo_code
JOIN crop_alias      ca ON ca.source_name     = 'faostat'
                        AND ca.source_crop_label = p.crop_label
WHERE p.period_start IS NOT NULL
  AND p.production_qty >= 0
ON CONFLICT (geography_id, crop_id, period_start, period_end, source_id)
DO UPDATE SET
    area_harvested_ha   = EXCLUDED.area_harvested_ha,
    production_quantity = EXCLUDED.production_quantity;

UPDATE etl_batch
SET status = 'loaded',
    loaded_rows = (
        SELECT COUNT(*)
        FROM parsed_crop_production p
        JOIN geography_alias ga ON ga.source_name      = 'faostat'
                                AND ga.source_geo_code  = p.geo_code
        JOIN crop_alias      ca ON ca.source_name      = 'faostat'
                                AND ca.source_crop_label = p.crop_label
        WHERE p.period_start IS NOT NULL AND p.production_qty >= 0
    )
WHERE batch_id = 'a2000000-0000-0000-0000-000000000002'::uuid;

COMMIT;

-- =============================================================================
-- BATCH 3: Load weather observations into curated weather_observation table
-- =============================================================================
BEGIN;

INSERT INTO weather_observation
    (geography_id, observed_on,
     rainfall_mm, temp_max_c, temp_min_c, humidity_pct, source_id)
SELECT
    ga.geography_id,
    p.observed_on,
    p.rainfall_mm,
    p.temp_max_c,
    p.temp_min_c,
    p.humidity_pct,
    p.batch_id
FROM parsed_weather p
JOIN geography_alias ga ON ga.source_name     = 'imd_weather'
                        AND ga.source_geo_code = p.geo_code
WHERE p.observed_on IS NOT NULL
ON CONFLICT (geography_id, observed_on, source_id)
DO UPDATE SET
    rainfall_mm  = EXCLUDED.rainfall_mm,
    temp_max_c   = EXCLUDED.temp_max_c,
    temp_min_c   = EXCLUDED.temp_min_c,
    humidity_pct = EXCLUDED.humidity_pct;

UPDATE etl_batch
SET status = 'loaded',
    loaded_rows = (
        SELECT COUNT(*)
        FROM parsed_weather p
        JOIN geography_alias ga ON ga.source_name     = 'imd_weather'
                                AND ga.source_geo_code = p.geo_code
        WHERE p.observed_on IS NOT NULL
    )
WHERE batch_id = 'a3000000-0000-0000-0000-000000000003'::uuid;

COMMIT;
