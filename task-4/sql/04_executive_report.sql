-- =============================================================================
-- Task 4 | Week 4 Internship Assessment
-- EXECUTIVE MANAGEMENT REPORT — COMPLETE SQL SCRIPT
-- Data Aggregation & Business Reporting
-- Database: PostgreSQL 15+
-- =============================================================================
-- Section 6 of the assessment.
-- This single script generates all sections of the management report in order:
--   1. Executive Summary KPI Cards
--   2. Production Overview (ranking + crop mix)
--   3. Trend Analysis (YoY change, seasonal pattern)
--   4. Market Price Comparison (ranking + spread)
--   5. Livestock Inventory Snapshot
--   6. Data Quality Note
-- Run in sequence; output maps 1:1 to the report layout in Section 6.1.
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 1: EXECUTIVE SUMMARY — KPI CARDS
-- Five headline numbers for the management summary slide / page.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    '2025 Total Crop Production (tonnes)'           AS kpi,
    ROUND(SUM(production_tonnes), 0)::TEXT          AS value,
    'All regions, all crops, season_year = 2025'    AS notes
FROM v_annual_production
WHERE season_year = 2025

UNION ALL

SELECT
    'Highest-Yielding Crop 2025',
    crop_name || ' (' || yield_t_per_ha || ' t/ha)',
    'Best yield_t_per_ha across all regions'
FROM v_annual_production
WHERE season_year = 2025
ORDER BY yield_t_per_ha DESC
LIMIT 1

UNION ALL

SELECT
    'Avg Wheat Price — INR/tonne (2025)',
    ROUND(AVG(avg_price_per_tonne), 0)::TEXT,
    'Average across all markets, Jan–Dec 2025, currency = INR'
FROM v_monthly_market_price
WHERE crop_name     = 'Wheat'
  AND currency_code = 'INR'
  AND price_month  >= DATE '2025-01-01'
  AND price_month  <  DATE '2026-01-01'

UNION ALL

SELECT
    'Total Livestock (latest snapshot)',
    SUM(animal_count)::TEXT,
    'Sum of latest animal_count per farm × type'
FROM v_latest_livestock

UNION ALL

SELECT
    'ETL Data Quality Rate (%)',
    ROUND(AVG(quality_rate_pct), 1)::TEXT,
    'Average quality_rate_pct across all loaded batches'
FROM v_data_quality_summary
WHERE health_status = 'healthy';

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 2: PRODUCTION OVERVIEW
-- 2a. Top 10 crop × region combinations by production (2025)
-- Visualization: Ranked bar chart; numbers feed into a crop-by-region table.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    production_rank,
    region_name,
    crop_name,
    crop_category,
    production_tonnes,
    area_planted_ha,
    yield_t_per_ha,
    contributing_farms
FROM v_production_concentration
WHERE season_year = 2025
ORDER BY production_rank
LIMIT 10;

-- 2b. Crop mix — percentage share of total 2025 production by crop category
SELECT
    crop_category,
    ROUND(SUM(production_tonnes), 0)                AS category_production_tonnes,
    ROUND(100.0 * SUM(production_tonnes) /
        SUM(SUM(production_tonnes)) OVER (), 2)     AS share_pct
FROM v_annual_production
WHERE season_year = 2025
GROUP BY crop_category
ORDER BY share_pct DESC;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 3: TREND ANALYSIS
-- 3a. Year-over-year production change per crop (2024 → 2025)
-- Visualization: Line chart with period labels; color-coded by trend_flag.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    crop_name,
    season_year,
    production_tonnes,
    prior_year_tonnes,
    yoy_change_pct,
    trend_flag
FROM v_yoy_production
WHERE season_year IN (2024, 2025)
ORDER BY season_year, yoy_change_pct DESC NULLS LAST;

-- 3b. Monthly price trend for top-3 crops (INR, 2025)
--     Shows price direction alongside production trends.
SELECT
    price_month,
    crop_name,
    avg_price_per_tonne,
    min_price,
    max_price,
    observations
FROM v_monthly_market_price
WHERE currency_code = 'INR'
  AND crop_name    IN ('Wheat', 'Mustard', 'Soybean')
  AND price_month  >= DATE '2025-01-01'
  AND price_month  <  DATE '2026-01-01'
ORDER BY crop_name, price_month;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 4: MARKET PRICE COMPARISON
-- 4a. Market ranking — which markets returned the highest average prices (2025)?
-- Visualization: Horizontal bar chart sorted by avg_price_per_tonne.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    crop_name,
    market_name,
    region_name,
    currency_code,
    ROUND(AVG(avg_price_per_tonne), 2)              AS annual_avg_price,
    SUM(observations)                               AS total_observations,
    RANK() OVER (
        PARTITION BY crop_name, currency_code
        ORDER BY AVG(avg_price_per_tonne) DESC
    )                                               AS market_rank
FROM v_monthly_market_price
WHERE currency_code = 'INR'
  AND price_month  >= DATE '2025-01-01'
  AND price_month  <  DATE '2026-01-01'
GROUP BY crop_name, market_name, region_name, currency_code
HAVING SUM(observations) >= 2
ORDER BY crop_name, market_rank;

-- 4b. Price volatility — crops with widest spread (price risk signal)
SELECT
    crop_name,
    currency_code,
    ROUND(AVG(avg_price_per_tonne), 2)              AS avg_price,
    ROUND(MIN(min_price), 2)                        AS season_low,
    ROUND(MAX(max_price), 2)                        AS season_high,
    ROUND(MAX(max_price) - MIN(min_price), 2)       AS total_spread,
    ROUND(
        100.0 * (MAX(max_price) - MIN(min_price)) /
        NULLIF(AVG(avg_price_per_tonne), 0), 2
    )                                               AS spread_pct_of_avg
FROM v_monthly_market_price
WHERE currency_code = 'INR'
  AND price_month  >= DATE '2025-01-01'
  AND price_month  <  DATE '2026-01-01'
GROUP BY crop_name, currency_code
ORDER BY spread_pct_of_avg DESC;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 5: LIVESTOCK INVENTORY SNAPSHOT
-- Visualization: Stacked bar chart by region and livestock type.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    region_name,
    livestock_type,
    production_purpose,
    COUNT(DISTINCT farm_id)                         AS farms_with_livestock,
    SUM(animal_count)                               AS total_animals,
    ROUND(AVG(animal_count), 1)                     AS avg_animals_per_farm,
    MAX(latest_observation_date)                    AS most_recent_count,
    SUM(CASE WHEN freshness_flag = 'STALE — needs update'
             THEN 1 ELSE 0 END)                     AS stale_farm_count
FROM v_latest_livestock
GROUP BY region_name, livestock_type, production_purpose
ORDER BY region_name, total_animals DESC;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 6: DATA QUALITY NOTE
-- Always append this section to every management report so readers understand
-- data coverage, freshness and any caveats.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    source_name,
    status,
    extracted_rows,
    accepted_rows,
    rejected_rows,
    quality_rate_pct,
    reject_rate_pct,
    health_status,
    retrieved_at                                    AS data_as_of
FROM v_data_quality_summary
ORDER BY retrieved_at DESC;

-- Append reject reasons for transparency
SELECT
    eb.source_name,
    er.reason_code,
    COUNT(*)                                        AS rejected_row_count
FROM etl_reject er
JOIN etl_batch  eb ON eb.batch_id = er.batch_id
GROUP BY eb.source_name, er.reason_code
ORDER BY eb.source_name, rejected_row_count DESC;
