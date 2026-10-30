-- =============================================================================
-- Task 4 | Week 4 Internship Assessment
-- DATA RELIABILITY, PERFORMANCE & PITFALL GUARDS
-- Data Aggregation & Business Reporting
-- Database: PostgreSQL 15+
-- =============================================================================
-- Section 5 of the assessment.
-- Covers: reliability controls, aggregation pitfall checks, index guidance,
--         EXPLAIN ANALYZE workflow, and reconciliation queries.
-- =============================================================================

-- =============================================================================
-- 5.1  DATA FRESHNESS CHECK
-- Show the most recent successful ETL batch per source so report viewers
-- know whether the data is current.
-- =============================================================================
SELECT
    source_name,
    MAX(retrieved_at)                                   AS latest_retrieval,
    CURRENT_TIMESTAMP - MAX(retrieved_at)               AS data_age,
    COUNT(*)                                            AS total_batches,
    SUM(CASE WHEN status = 'loaded'  THEN 1 ELSE 0 END) AS successful_batches,
    SUM(CASE WHEN status = 'failed'  THEN 1 ELSE 0 END) AS failed_batches
FROM etl_batch
GROUP BY source_name
ORDER BY latest_retrieval DESC;

-- =============================================================================
-- 5.2  DATA QUALITY DASHBOARD
-- One row per ETL batch showing quality rate, reject rate and health status.
-- Include this as a "Data Quality Note" section in every management report.
-- =============================================================================
SELECT
    source_name,
    batch_id,
    status,
    extracted_rows,
    accepted_rows,
    rejected_rows,
    loaded_rows,
    quality_rate_pct,
    reject_rate_pct,
    health_status,
    retrieved_at
FROM v_data_quality_summary
ORDER BY retrieved_at DESC;

-- =============================================================================
-- 5.3  REJECT BREAKDOWN — Top reason codes per source
-- Shows what kind of data quality issues are most frequent.
-- =============================================================================
SELECT
    eb.source_name,
    er.reason_code,
    COUNT(*)                                            AS reject_count,
    ROUND(100.0 * COUNT(*) /
        NULLIF(SUM(COUNT(*)) OVER (PARTITION BY eb.source_name), 0), 2)
                                                        AS pct_of_source_rejects
FROM etl_reject er
JOIN etl_batch  eb ON eb.batch_id = er.batch_id
GROUP BY eb.source_name, er.reason_code
ORDER BY eb.source_name, reject_count DESC;

-- =============================================================================
-- 5.4  AGGREGATION PITFALL GUARD — Fan-out join detection
-- Check: does joining harvest to market_price directly multiply rows?
-- This query demonstrates the WRONG approach, then the CORRECT one.
-- =============================================================================

-- ❌ WRONG — joining harvest rows to price rows directly inflates row count:
-- SELECT h.farm_id, h.crop_id, h.quantity_tonnes, mp.price_per_tonne
-- FROM harvest h
-- JOIN market_price mp ON mp.crop_id = h.crop_id   ← fans out: 1 harvest × many prices

-- ✅ CORRECT — aggregate each fact table independently, then join at dimension level:
WITH prod_2025 AS (
    SELECT
        h.crop_id,
        SUM(h.quantity_tonnes)  AS total_production_tonnes
    FROM harvest AS h
    WHERE h.season_year = 2025
    GROUP BY h.crop_id
),
price_2025 AS (
    SELECT
        mp.crop_id,
        ROUND(AVG(mp.price_per_tonne), 2) AS avg_price_inr
    FROM market_price AS mp
    WHERE mp.observed_on   >= DATE '2025-01-01'
      AND mp.observed_on   <  DATE '2026-01-01'
      AND mp.currency_code  = 'INR'
    GROUP BY mp.crop_id
)
SELECT
    c.crop_name,
    p.total_production_tonnes,
    pr.avg_price_inr,
    ROUND(p.total_production_tonnes * pr.avg_price_inr, 0) AS estimated_value_inr
FROM prod_2025    AS p
JOIN crop         AS c  ON c.crop_id = p.crop_id
LEFT JOIN price_2025 AS pr ON pr.crop_id = p.crop_id
ORDER BY estimated_value_inr DESC NULLS LAST;

-- =============================================================================
-- 5.5  PITFALL: Average of averages (incorrect overall yield)
-- Wrong: AVG(farm-level yield) — biased toward small farms
-- Right: SUM(production) / SUM(area) — area-weighted correct yield
-- =============================================================================

-- ❌ WRONG — averaging farm-level yields (equal weight regardless of farm size)
SELECT
    c.crop_name,
    h.season_year,
    ROUND(AVG(h.quantity_tonnes / NULLIF(h.area_planted_ha, 0)), 3) AS wrong_avg_yield
FROM harvest AS h
JOIN crop    AS c ON c.crop_id = h.crop_id
WHERE h.season_year = 2025
GROUP BY c.crop_name, h.season_year;

-- ✅ CORRECT — sum both then divide (area-weighted)
SELECT
    c.crop_name,
    h.season_year,
    ROUND(SUM(h.quantity_tonnes) / NULLIF(SUM(h.area_planted_ha), 0), 3)
                                                        AS correct_yield_t_per_ha
FROM harvest AS h
JOIN crop    AS c ON c.crop_id = h.crop_id
WHERE h.season_year = 2025
GROUP BY c.crop_name, h.season_year
ORDER BY correct_yield_t_per_ha DESC;

-- =============================================================================
-- 5.6  NULL AND SPARSE DATA CHECK
-- AVG() ignores NULLs silently. Report observation count alongside averages.
-- =============================================================================
SELECT
    c.crop_name,
    m.market_name,
    mp.currency_code,
    COUNT(*)                                            AS total_observations,
    COUNT(mp.price_per_tonne)                           AS non_null_prices,
    COUNT(*) - COUNT(mp.price_per_tonne)                AS null_prices,
    ROUND(AVG(mp.price_per_tonne), 2)                   AS avg_price,
    -- Flag sparse markets where fewer than 3 obs could mislead averages
    CASE WHEN COUNT(*) < 3 THEN 'SPARSE — interpret with caution' ELSE 'OK' END
                                                        AS coverage_flag
FROM market_price   AS mp
JOIN crop           AS c  ON c.crop_id   = mp.crop_id
JOIN market         AS m  ON m.market_id = mp.market_id
WHERE mp.observed_on >= DATE '2025-01-01'
  AND mp.observed_on <  DATE '2026-01-01'
GROUP BY c.crop_name, m.market_name, mp.currency_code
ORDER BY c.crop_name, m.market_name, mp.currency_code;

-- =============================================================================
-- 5.7  EXPLAIN ANALYZE BASELINE — production report
-- Run before and after adding indexes. Compare actual vs estimated row counts,
-- seq scans vs index scans, sort spills and buffer reads.
-- =============================================================================
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    r.region_name, c.crop_name, h.season_year,
    SUM(h.quantity_tonnes) AS production_tonnes
FROM harvest    AS h
JOIN farm       AS f  ON f.farm_id   = h.farm_id
JOIN region     AS r  ON r.region_id = f.region_id
JOIN crop       AS c  ON c.crop_id   = h.crop_id
WHERE h.season_year = 2025
GROUP BY r.region_name, c.crop_name, h.season_year
ORDER BY production_tonnes DESC;

-- =============================================================================
-- 5.8  EXPLAIN ANALYZE BASELINE — monthly price trend
-- =============================================================================
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    c.crop_name,
    DATE_TRUNC('month', mp.observed_on)::date AS price_month,
    AVG(mp.price_per_tonne) AS avg_price
FROM market_price   AS mp
JOIN crop           AS c ON c.crop_id = mp.crop_id
WHERE mp.observed_on   >= DATE '2025-01-01'
  AND mp.observed_on   <  DATE '2026-01-01'
  AND mp.currency_code  = 'INR'
GROUP BY c.crop_name, DATE_TRUNC('month', mp.observed_on)
ORDER BY price_month, c.crop_name;

-- =============================================================================
-- 5.9  INDEX RECOMMENDATIONS (from Section 5.3 of assessment)
-- Verify these are in place (created by Task 2 / Task 3 scripts).
-- =============================================================================
SELECT
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN (
      'harvest', 'market_price', 'livestock_observation',
      'farm', 'crop', 'market', 'region'
  )
ORDER BY tablename, indexname;

-- =============================================================================
-- 5.10  RECONCILIATION — curated totals vs ETL batch accepted counts
-- Confirms data flowed from staging to curated tables completely.
-- =============================================================================
SELECT
    'market_price'      AS curated_table,
    COUNT(*)            AS curated_rows,
    eb.accepted_rows    AS etl_accepted,
    COUNT(*) - eb.accepted_rows AS gap
FROM market_price, etl_batch eb
WHERE eb.source_name = 'agmarknet'
  AND eb.status      = 'loaded'
GROUP BY eb.accepted_rows
UNION ALL
SELECT
    'weather_observation',
    COUNT(*),
    eb.accepted_rows,
    COUNT(*) - eb.accepted_rows
FROM weather_observation, etl_batch eb
WHERE eb.source_name = 'imd_weather'
  AND eb.status      = 'loaded'
GROUP BY eb.accepted_rows;
