-- =============================================================================
-- Task 4 | Week 4 Internship Assessment
-- MARKET PRICE & LIVESTOCK REPORTING QUERIES
-- Data Aggregation & Business Reporting
-- Database: PostgreSQL 15+
-- =============================================================================
-- Section 4 of the assessment.
-- Covers: monthly price trends, market ranking, price change %, livestock snapshot.
-- Pitfall guards: no mixing of currencies/units; observations count displayed;
--                 HAVING prevents thin-market distortion; inventory from latest obs only.
-- =============================================================================

-- =============================================================================
-- REPORT 4.1 — Monthly Market Price Trend
-- Business question: How do commodity prices move across markets over time?
-- HAVING COUNT(*) >= 3 exposes sample size; tune per source observation frequency.
-- =============================================================================
SELECT
    crop_name,
    market_name,
    region_name,
    price_month,
    currency_code,
    avg_price_per_tonne,
    min_price,
    max_price,
    price_range,
    observations
FROM v_monthly_market_price
WHERE price_month >= DATE '2025-01-01'
  AND price_month <  DATE '2026-01-01'
  AND currency_code = 'INR'
  AND observations  >= 3          -- suppress thin markets (illustrative threshold)
ORDER BY price_month, crop_name, avg_price_per_tonne DESC;

-- =============================================================================
-- REPORT 4.2 — Highest-Priced Markets for a Selected Crop
-- Business question: Which markets offered the highest average wheat price
--                    in the latest quarter? (Supports selling-timing decisions.)
-- Note: price alone is not sufficient — transport, grade and availability matter.
-- =============================================================================
SELECT
    market_name,
    region_name,
    currency_code,
    avg_price_per_tonne,
    min_price,
    max_price,
    observations,
    RANK() OVER (ORDER BY avg_price_per_tonne DESC)     AS market_rank
FROM v_monthly_market_price
WHERE crop_name     = 'Wheat'
  AND currency_code = 'INR'
  AND price_month  >= DATE '2025-01-01'
  AND price_month  <  DATE '2026-01-01'
  AND observations  >= 2
ORDER BY avg_price_per_tonne DESC
LIMIT 10;

-- =============================================================================
-- REPORT 4.3 — Month-over-Month Price Change (%)
-- Business question: Which crop/market combinations are showing price pressure?
-- Uses v_price_yoy which applies LAG over v_monthly_market_price.
-- =============================================================================
SELECT
    crop_name,
    market_name,
    region_name,
    price_month,
    currency_code,
    avg_price_per_tonne,
    prior_month_price,
    mom_change_pct,
    CASE
        WHEN mom_change_pct IS NULL          THEN 'first_month'
        WHEN mom_change_pct >  5             THEN 'significant_increase'
        WHEN mom_change_pct >  0             THEN 'slight_increase'
        WHEN mom_change_pct =  0             THEN 'stable'
        WHEN mom_change_pct < -5             THEN 'significant_drop'
        ELSE                                      'slight_drop'
    END                                                 AS price_movement
FROM v_price_yoy
WHERE currency_code = 'INR'
  AND observations  >= 2
ORDER BY price_month DESC, ABS(COALESCE(mom_change_pct, 0)) DESC;

-- =============================================================================
-- REPORT 4.4 — Cross-Market Price Comparison (same crop, same month)
-- Business question: How much does the price of Mustard vary across markets?
-- Wide spread may indicate arbitrage opportunity or data quality issues.
-- =============================================================================
SELECT
    price_month,
    crop_name,
    currency_code,
    COUNT(DISTINCT market_name)                         AS markets_reporting,
    ROUND(AVG(avg_price_per_tonne), 2)                  AS overall_avg_price,
    MIN(min_price)                                      AS lowest_market_price,
    MAX(max_price)                                      AS highest_market_price,
    ROUND(MAX(max_price) - MIN(min_price), 2)           AS cross_market_spread,
    ROUND(
        STDDEV(avg_price_per_tonne), 2
    )                                                   AS price_stddev
FROM v_monthly_market_price
WHERE crop_name     = 'Mustard'
  AND currency_code = 'INR'
  AND price_month  >= DATE '2025-01-01'
GROUP BY price_month, crop_name, currency_code
HAVING COUNT(DISTINCT market_name) >= 2
ORDER BY price_month;

-- =============================================================================
-- REPORT 4.5 — Latest Livestock Inventory Snapshot
-- Business question: How many animals does each farm currently hold?
-- CRITICAL: use latest observation only — do NOT sum all historical records.
-- =============================================================================
SELECT
    region_name,
    farm_name,
    farm_code,
    livestock_type,
    production_purpose,
    latest_observation_date,
    animal_count,
    average_weight_kg,
    -- Flag stale observations (>90 days old)
    CURRENT_DATE - latest_observation_date              AS days_since_observation,
    CASE
        WHEN CURRENT_DATE - latest_observation_date > 90 THEN 'STALE — needs update'
        WHEN CURRENT_DATE - latest_observation_date > 30 THEN 'due for update'
        ELSE 'recent'
    END                                                 AS freshness_flag
FROM v_latest_livestock
ORDER BY region_name, farm_name, livestock_type;

-- =============================================================================
-- REPORT 4.6 — Livestock Inventory by Region (aggregated snapshot)
-- Business question: How many animals are there in each region by type?
-- Aggregates the latest per-farm counts — not raw observation rows.
-- =============================================================================
SELECT
    region_name,
    livestock_type,
    production_purpose,
    COUNT(DISTINCT farm_id)                             AS farms_reporting,
    SUM(animal_count)                                   AS total_animals,
    ROUND(AVG(animal_count), 1)                         AS avg_per_farm,
    MAX(latest_observation_date)                        AS most_recent_obs
FROM v_latest_livestock
GROUP BY region_name, livestock_type, production_purpose
ORDER BY region_name, total_animals DESC;

-- =============================================================================
-- REPORT 4.7 — Combined Production vs Market Price Summary
-- Business question: For each crop in 2025, how does total production relate
--                    to average market price? (high output + falling price = margin risk)
-- Key rule: aggregate each fact table INDEPENDENTLY before joining on crop.
-- =============================================================================
WITH prod AS (
    SELECT
        crop_name,
        crop_category,
        SUM(production_tonnes)  AS total_production_tonnes,
        SUM(area_planted_ha)    AS total_area_ha,
        ROUND(SUM(production_tonnes) / NULLIF(SUM(area_planted_ha), 0), 3)
                                AS avg_yield
    FROM v_annual_production
    WHERE season_year = 2025
    GROUP BY crop_name, crop_category
),
price AS (
    SELECT
        crop_name,
        ROUND(AVG(avg_price_per_tonne), 2)  AS avg_market_price_inr,
        SUM(observations)                    AS total_price_observations
    FROM v_monthly_market_price
    WHERE currency_code = 'INR'
      AND price_month  >= DATE '2025-01-01'
      AND price_month  <  DATE '2026-01-01'
    GROUP BY crop_name
)
SELECT
    p.crop_name,
    p.crop_category,
    p.total_production_tonnes,
    p.avg_yield                                         AS yield_t_per_ha,
    pr.avg_market_price_inr,
    pr.total_price_observations,
    ROUND(p.total_production_tonnes * pr.avg_market_price_inr, 0)
                                                        AS estimated_value_inr,
    CASE
        WHEN pr.avg_market_price_inr IS NULL THEN 'no_price_data'
        ELSE 'has_price_data'
    END                                                 AS price_availability
FROM prod AS p
LEFT JOIN price AS pr ON pr.crop_name = p.crop_name
ORDER BY estimated_value_inr DESC NULLS LAST;
