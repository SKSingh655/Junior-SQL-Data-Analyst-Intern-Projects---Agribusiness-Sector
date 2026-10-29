-- =============================================================================
-- Task 3 | Week 3 Internship Assessment
-- MONITORING, DATA QUALITY CHECKS & TEST SUITE
-- Agribusiness ETL Process Plan
-- Database: PostgreSQL 15+
-- =============================================================================
-- Run AFTER 05_load_curated.sql to verify pipeline correctness.
-- =============================================================================

-- =============================================================================
-- 6.1 BATCH SUMMARY REPORT
-- Shows extracted / accepted / rejected / loaded counts per batch.
-- Alert if reject rate exceeds 5% or loaded != accepted.
-- =============================================================================
SELECT
    batch_id,
    source_name,
    status,
    extracted_rows,
    accepted_rows,
    rejected_rows,
    loaded_rows,
    CASE
        WHEN extracted_rows = 0 THEN NULL
        ELSE ROUND(rejected_rows::NUMERIC / extracted_rows * 100, 2)
    END                                             AS reject_pct,
    CASE
        WHEN accepted_rows != loaded_rows THEN 'RECONCILIATION MISMATCH'
        WHEN extracted_rows > 0
             AND (rejected_rows::NUMERIC / extracted_rows) > 0.05
            THEN 'HIGH REJECT RATE — INVESTIGATE'
        ELSE 'OK'
    END                                             AS health_flag,
    retrieved_at
FROM etl_batch
ORDER BY retrieved_at DESC;


-- =============================================================================
-- 6.2 REJECT DETAIL REPORT
-- Shows every quarantined row grouped by source and reason.
-- =============================================================================
SELECT
    eb.source_name,
    er.reason_code,
    COUNT(*)                                        AS reject_count,
    jsonb_agg(er.raw_record ORDER BY er.source_row_number)
                                                    AS sample_raw_records
FROM etl_reject er
JOIN etl_batch  eb ON eb.batch_id = er.batch_id
GROUP BY eb.source_name, er.reason_code
ORDER BY eb.source_name, reject_count DESC;


-- =============================================================================
-- 6.3 RECONCILIATION CHECK
-- Confirms: accepted + rejected = extracted for every batch.
-- =============================================================================
SELECT
    batch_id,
    source_name,
    extracted_rows,
    accepted_rows + rejected_rows                   AS accounted_rows,
    extracted_rows - (accepted_rows + rejected_rows) AS unaccounted_rows,
    CASE
        WHEN extracted_rows = accepted_rows + rejected_rows THEN 'PASS'
        ELSE 'FAIL — rows are missing from accounting'
    END                                             AS reconciliation_result
FROM etl_batch
ORDER BY source_name;


-- =============================================================================
-- 6.4 IDEMPOTENCY TEST
-- Re-running the same batch should not change curated row counts.
-- Record counts before and after; compare.
-- =============================================================================
SELECT
    'market_price'           AS table_name,
    COUNT(*)                 AS row_count
FROM market_price
UNION ALL
SELECT 'crop_production_stat', COUNT(*) FROM crop_production_stat
UNION ALL
SELECT 'weather_observation',  COUNT(*) FROM weather_observation;
-- Run this BEFORE and AFTER re-running 04 + 05 scripts.
-- Counts must remain identical for idempotency to hold.


-- =============================================================================
-- 6.5 DUPLICATE BUSINESS KEY CHECK
-- After loading, confirm no duplicates survived despite ON CONFLICT handling.
-- =============================================================================

-- Market price duplicates (should be 0)
SELECT market_id, crop_id, observed_on, currency_code, COUNT(*) AS dupe_count
FROM market_price
GROUP BY market_id, crop_id, observed_on, currency_code
HAVING COUNT(*) > 1;

-- Crop production stat duplicates (should be 0)
SELECT geography_id, crop_id, period_start, period_end, source_id, COUNT(*) AS dupe_count
FROM crop_production_stat
GROUP BY geography_id, crop_id, period_start, period_end, source_id
HAVING COUNT(*) > 1;

-- Weather observation duplicates (should be 0)
SELECT geography_id, observed_on, source_id, COUNT(*) AS dupe_count
FROM weather_observation
GROUP BY geography_id, observed_on, source_id
HAVING COUNT(*) > 1;


-- =============================================================================
-- 6.6 REFERENTIAL INTEGRITY CHECKS
-- Foreign-key constraints should block orphans, but verify explicitly.
-- =============================================================================

-- Orphaned market prices (no matching market)
SELECT mp.price_id FROM market_price mp
LEFT JOIN market m ON m.market_id = mp.market_id
WHERE m.market_id IS NULL;

-- Orphaned crop production stats (no matching region)
SELECT cps.stat_id FROM crop_production_stat cps
LEFT JOIN region r ON r.region_id = cps.geography_id
WHERE r.region_id IS NULL;

-- Orphaned weather observations (no matching region)
SELECT wo.obs_id FROM weather_observation wo
LEFT JOIN region r ON r.region_id = wo.geography_id
WHERE r.region_id IS NULL;

-- Unmapped crop aliases (source labels without a matching crop_id in crosswalk)
SELECT DISTINCT s.source_crop_label
FROM stg_market_price s
WHERE s.validation_status = 'accepted'
  AND NOT EXISTS (
      SELECT 1 FROM crop_alias ca
      WHERE ca.source_name = 'agmarknet'
        AND ca.source_crop_label = BTRIM(s.source_crop_label)
  );


-- =============================================================================
-- 6.7 DATA QUALITY SPOT CHECKS
-- =============================================================================

-- Market prices: any negative values in curated table?
SELECT price_id, price_per_tonne FROM market_price WHERE price_per_tonne < 0;

-- Crop production: any impossible values?
SELECT stat_id, area_harvested_ha, production_quantity
FROM crop_production_stat
WHERE area_harvested_ha < 0 OR production_quantity < 0;

-- Weather: negative rainfall in curated table?
SELECT obs_id, rainfall_mm FROM weather_observation WHERE rainfall_mm < 0;

-- Weather: physically impossible temperatures?
SELECT obs_id, temp_max_c, temp_min_c
FROM weather_observation
WHERE temp_max_c > 60 OR temp_min_c < -20
   OR temp_max_c < temp_min_c;


-- =============================================================================
-- 6.8 ANALYTICAL CROSS-SOURCE QUERY
-- Business question: For Wheat in Punjab in 2025, compare the national
-- production stat with the average market price observed in the same year.
-- Join at crop + region level only (never join fact rows 1-to-1).
-- =============================================================================
WITH production AS (
    SELECT
        r.region_name,
        c.crop_name,
        cps.period_start,
        cps.period_end,
        cps.production_quantity AS national_production_tonnes
    FROM crop_production_stat cps
    JOIN region r ON r.region_id = cps.geography_id
    JOIN crop   c ON c.crop_id   = cps.crop_id
    WHERE c.crop_name   = 'Wheat'
      AND r.region_name = 'Punjab'
      AND cps.period_start = '2025-01-01'
),
prices AS (
    SELECT
        c.crop_name,
        ROUND(AVG(mp.price_per_tonne), 2)   AS avg_price_inr_per_tonne
    FROM market_price mp
    JOIN crop   c ON c.crop_id   = mp.crop_id
    JOIN market m ON m.market_id = mp.market_id
    JOIN region r ON r.region_id = m.region_id
    WHERE c.crop_name   = 'Wheat'
      AND r.region_name = 'Punjab'
      AND mp.observed_on >= '2025-01-01'
      AND mp.observed_on <  '2026-01-01'
      AND mp.currency_code = 'INR'
    GROUP BY c.crop_name
)
SELECT
    p.region_name,
    p.crop_name,
    p.national_production_tonnes,
    pr.avg_price_inr_per_tonne,
    ROUND(p.national_production_tonnes * pr.avg_price_inr_per_tonne, 2)
                                            AS estimated_market_value_inr
FROM production p
JOIN prices pr ON pr.crop_name = p.crop_name;


-- =============================================================================
-- 6.9 INDEX USAGE REPORT (run after several analytical queries)
-- =============================================================================
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan        AS times_used,
    idx_tup_read    AS tuples_read
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
  AND tablename IN (
      'etl_batch', 'etl_reject',
      'stg_market_price', 'stg_crop_production', 'stg_weather',
      'market_price', 'crop_production_stat', 'weather_observation',
      'crop_alias', 'geography_alias', 'market_alias'
  )
ORDER BY idx_scan DESC;
