-- =============================================================================
-- Task 2 | Week 2 Internship Assessment
-- QUERY OPTIMIZATION DEMONSTRATIONS
-- Agribusiness Data Analysis Platform
-- Database: PostgreSQL 15+
-- =============================================================================
-- This file demonstrates the query tuning workflow described in Section 5.4
-- of the assessment. Run these in a test environment with representative data.
-- =============================================================================

-- =============================================================================
-- STEP 1: EXPLAIN ANALYZE baselines (run BEFORE adding indexes)
-- =============================================================================

-- Baseline: annual production report (no index on season_year yet)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    r.region_name,
    c.crop_name,
    SUM(h.quantity_tonnes) AS total_tonnes
FROM harvest    AS h
JOIN farm       AS f  ON f.farm_id   = h.farm_id
JOIN region     AS r  ON r.region_id = f.region_id
JOIN crop       AS c  ON c.crop_id   = h.crop_id
WHERE h.season_year = 2025
GROUP BY r.region_name, c.crop_name
ORDER BY total_tonnes DESC;

-- Baseline: monthly market price trend
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    c.crop_name,
    DATE_TRUNC('month', mp.observed_on)::date AS price_month,
    AVG(mp.price_per_tonne)                   AS avg_price
FROM market_price   AS mp
JOIN crop           AS c ON c.crop_id = mp.crop_id
WHERE mp.observed_on   >= DATE '2025-01-01'
  AND mp.observed_on   <  DATE '2026-01-01'
  AND mp.currency_code  = 'INR'
GROUP BY c.crop_name, DATE_TRUNC('month', mp.observed_on)
ORDER BY price_month, c.crop_name;


-- =============================================================================
-- STEP 2: Apply indexes (from 02_indexes.sql — shown here for reference)
-- =============================================================================

-- CREATE INDEX IF NOT EXISTS idx_harvest_season_year_crop_farm
--   ON harvest(season_year, crop_id, farm_id);

-- CREATE INDEX IF NOT EXISTS idx_market_price_currency_date
--   ON market_price(currency_code, observed_on);


-- =============================================================================
-- STEP 3: Re-run EXPLAIN ANALYZE after indexes and compare plans
-- =============================================================================
-- Look for:
--   * Index Scan replacing Seq Scan on large tables
--   * Reduction in "actual rows" passed to aggregations
--   * Lower "Buffers: shared read" numbers
--   * Elimination of sort spills to disk


-- =============================================================================
-- STEP 4: Keep statistics current
-- =============================================================================
-- Run after bulk inserts or significant data changes:
ANALYZE harvest;
ANALYZE market_price;
ANALYZE livestock_observation;
ANALYZE farm;
ANALYZE crop;
ANALYZE market;
ANALYZE region;
ANALYZE livestock_type;


-- =============================================================================
-- DATA QUALITY VALIDATION QUERIES
-- =============================================================================

-- Check for harvests with no matching farm (should return 0 rows)
SELECT h.harvest_id
FROM harvest AS h
LEFT JOIN farm AS f ON f.farm_id = h.farm_id
WHERE f.farm_id IS NULL;

-- Check for negative quantities (constraint should already block these)
SELECT harvest_id, quantity_tonnes
FROM harvest
WHERE quantity_tonnes < 0;

-- Check for market prices without a matching crop
SELECT mp.price_id
FROM market_price AS mp
LEFT JOIN crop AS c ON c.crop_id = mp.crop_id
WHERE c.crop_id IS NULL;

-- Identify duplicate farm codes (unique constraint should prevent these)
SELECT farm_code, COUNT(*) AS occurrences
FROM farm
GROUP BY farm_code
HAVING COUNT(*) > 1;

-- Identify duplicate daily price quotes per market/crop/date/currency
-- (beyond what the unique constraint covers — useful to check before adding it)
SELECT market_id, crop_id, observed_on, currency_code, COUNT(*) AS cnt
FROM market_price
GROUP BY market_id, crop_id, observed_on, currency_code
HAVING COUNT(*) > 1;

-- Farms with NULL region_id (referential integrity check)
SELECT farm_id, farm_code
FROM farm
WHERE region_id IS NULL;

-- Livestock observations with animal_count = 0 (flag for review)
SELECT observation_id, farm_id, livestock_type_id, observed_on, animal_count
FROM livestock_observation
WHERE animal_count = 0;


-- =============================================================================
-- INDEX USAGE REPORT (after queries have run)
-- =============================================================================
-- Shows which indexes on agribusiness tables are actually being used.
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan        AS times_used,
    idx_tup_read    AS tuples_read,
    idx_tup_fetch   AS tuples_fetched
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
  AND tablename IN (
      'harvest', 'farm', 'crop', 'region',
      'market', 'market_price',
      'livestock_observation', 'livestock_type'
  )
ORDER BY times_used DESC;
