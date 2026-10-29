-- =============================================================================
-- Task 2 | Week 2 Internship Assessment
-- ANALYTICAL REPORTING QUERIES
-- Agribusiness Data Analysis Platform
-- Database: PostgreSQL 15+
-- =============================================================================

-- =============================================================================
-- 4.1  Annual Crop Production by Region
-- Business question: Which region+crop combinations produced the greatest
--                    quantity in a selected year?
-- Optimization: Filter early on season_year before joining reference tables.
--               Index: harvest(season_year, crop_id, farm_id)
-- =============================================================================
SELECT
    r.region_name,
    c.crop_name,
    h.season_year,
    SUM(h.quantity_tonnes)                          AS total_tonnes,
    SUM(h.area_planted_ha)                          AS total_area_ha,
    ROUND(
        SUM(h.quantity_tonnes) /
        NULLIF(SUM(h.area_planted_ha), 0), 3
    )                                               AS avg_yield_t_per_ha
FROM harvest    AS h
JOIN farm       AS f  ON f.farm_id   = h.farm_id
JOIN region     AS r  ON r.region_id = f.region_id
JOIN crop       AS c  ON c.crop_id   = h.crop_id
WHERE h.season_year = 2025
GROUP BY r.region_name, c.crop_name, h.season_year
ORDER BY total_tonnes DESC;


-- =============================================================================
-- 4.2  Yield by Crop and Season (date-range variant)
-- Business question: Which crops had the highest yield (tonnes per hectare)
--                    across all harvests in 2025?
-- Optimization: Use a half-open date range so the filter is sargable on a
--               B-tree index on harvest_date. Avoid EXTRACT() in WHERE.
-- =============================================================================
SELECT
    c.crop_name,
    h.season_year,
    SUM(h.quantity_tonnes)                          AS tonnes_harvested,
    SUM(h.area_planted_ha)                          AS hectares_planted,
    ROUND(
        SUM(h.quantity_tonnes) /
        NULLIF(SUM(h.area_planted_ha), 0), 3
    )                                               AS tonnes_per_hectare
FROM harvest    AS h
JOIN crop       AS c  ON c.crop_id = h.crop_id
WHERE h.harvest_date >= DATE '2025-01-01'
  AND h.harvest_date <  DATE '2026-01-01'
GROUP BY c.crop_name, h.season_year
ORDER BY tonnes_per_hectare DESC;


-- =============================================================================
-- 4.3  Monthly Market Price Trend
-- Business question: How do average prices change by commodity, market and
--                    month for a given currency?
-- Optimization: Filter on currency_code first (leading index column) then
--               on observed_on. Do NOT join to harvest before aggregation.
-- =============================================================================
SELECT
    c.crop_name,
    m.market_name,
    DATE_TRUNC('month', mp.observed_on)::date       AS price_month,
    mp.currency_code,
    ROUND(AVG(mp.price_per_tonne), 2)               AS avg_price_per_tonne,
    MIN(mp.price_per_tonne)                         AS min_price,
    MAX(mp.price_per_tonne)                         AS max_price
FROM market_price   AS mp
JOIN crop           AS c  ON c.crop_id   = mp.crop_id
JOIN market         AS m  ON m.market_id = mp.market_id
WHERE mp.observed_on   >= DATE '2025-01-01'
  AND mp.observed_on   <  DATE '2026-01-01'
  AND mp.currency_code  = 'INR'
GROUP BY c.crop_name, m.market_name,
         DATE_TRUNC('month', mp.observed_on),
         mp.currency_code
ORDER BY price_month, c.crop_name, m.market_name;


-- =============================================================================
-- 5.1  Latest Livestock Count per Farm and Type
-- Business question: What is the most recent animal count for every
--                    farm/livestock-type combination?
-- Optimization: ROW_NUMBER() with PARTITION avoids correlated sub-queries.
--               Index: livestock_observation(farm_id, livestock_type_id, observed_on DESC)
-- =============================================================================
WITH ranked AS (
    SELECT
        lo.farm_id,
        lo.livestock_type_id,
        lo.observed_on,
        lo.animal_count,
        lo.average_weight_kg,
        ROW_NUMBER() OVER (
            PARTITION BY lo.farm_id, lo.livestock_type_id
            ORDER BY lo.observed_on DESC, lo.observation_id DESC
        ) AS rn
    FROM livestock_observation AS lo
)
SELECT
    f.farm_name,
    lt.type_name,
    r.observed_on       AS latest_observation,
    r.animal_count,
    r.average_weight_kg
FROM ranked         AS r
JOIN farm           AS f  ON f.farm_id           = r.farm_id
JOIN livestock_type AS lt ON lt.livestock_type_id = r.livestock_type_id
WHERE r.rn = 1
ORDER BY f.farm_name, lt.type_name;


-- =============================================================================
-- 5.2  Farms with Total Output Above a Threshold
-- Business question: Which farms exceeded 100 tonnes of harvest in 2025?
-- Optimization: WHERE filters rows before aggregation; HAVING filters
--               groups after. Only create a materialized summary after
--               measuring the cost versus freshness trade-off.
-- =============================================================================
SELECT
    f.farm_code,
    f.farm_name,
    r.region_name,
    SUM(h.quantity_tonnes)  AS total_tonnes,
    COUNT(DISTINCT h.crop_id) AS distinct_crops
FROM farm           AS f
JOIN region         AS r  ON r.region_id = f.region_id
JOIN harvest        AS h  ON h.farm_id   = f.farm_id
WHERE h.harvest_date >= DATE '2025-01-01'
  AND h.harvest_date <  DATE '2026-01-01'
GROUP BY f.farm_id, f.farm_code, f.farm_name, r.region_name
HAVING SUM(h.quantity_tonnes) > 100
ORDER BY total_tonnes DESC;


-- =============================================================================
-- BONUS 1: Cross-region production vs. price comparison
-- Business question: For wheat in 2025, compare regional production totals
--                    against average market prices (same crop, same year).
--                    Join production and price at the crop level only —
--                    never join harvest rows to price rows 1-to-1.
-- =============================================================================
WITH production AS (
    SELECT
        r.region_name,
        c.crop_name,
        SUM(h.quantity_tonnes)  AS total_tonnes
    FROM harvest    AS h
    JOIN farm       AS f  ON f.farm_id   = h.farm_id
    JOIN region     AS r  ON r.region_id = f.region_id
    JOIN crop       AS c  ON c.crop_id   = h.crop_id
    WHERE h.season_year = 2025
      AND c.crop_name   = 'Wheat'
    GROUP BY r.region_name, c.crop_name
),
prices AS (
    SELECT
        c.crop_name,
        ROUND(AVG(mp.price_per_tonne), 2)   AS avg_price_inr
    FROM market_price   AS mp
    JOIN crop           AS c  ON c.crop_id = mp.crop_id
    WHERE mp.observed_on   >= DATE '2025-01-01'
      AND mp.observed_on   <  DATE '2026-01-01'
      AND mp.currency_code  = 'INR'
      AND c.crop_name       = 'Wheat'
    GROUP BY c.crop_name
)
SELECT
    p.region_name,
    p.crop_name,
    p.total_tonnes,
    pr.avg_price_inr,
    ROUND(p.total_tonnes * pr.avg_price_inr, 2)   AS estimated_revenue_inr
FROM production AS p
JOIN prices     AS pr ON pr.crop_name = p.crop_name
ORDER BY p.total_tonnes DESC;


-- =============================================================================
-- BONUS 2: Season-over-season production change
-- Business question: For each farm+crop pair, compare 2024 and 2025 totals.
-- =============================================================================
SELECT
    f.farm_name,
    c.crop_name,
    SUM(CASE WHEN h.season_year = 2024 THEN h.quantity_tonnes END)  AS tonnes_2024,
    SUM(CASE WHEN h.season_year = 2025 THEN h.quantity_tonnes END)  AS tonnes_2025,
    ROUND(
        (SUM(CASE WHEN h.season_year = 2025 THEN h.quantity_tonnes END) -
         SUM(CASE WHEN h.season_year = 2024 THEN h.quantity_tonnes END)) /
        NULLIF(SUM(CASE WHEN h.season_year = 2024 THEN h.quantity_tonnes END), 0) * 100,
        2
    )                                                                AS pct_change
FROM harvest    AS h
JOIN farm       AS f  ON f.farm_id  = h.farm_id
JOIN crop       AS c  ON c.crop_id  = h.crop_id
WHERE h.season_year IN (2024, 2025)
GROUP BY f.farm_id, f.farm_name, c.crop_id, c.crop_name
HAVING SUM(CASE WHEN h.season_year = 2024 THEN h.quantity_tonnes END) IS NOT NULL
   AND SUM(CASE WHEN h.season_year = 2025 THEN h.quantity_tonnes END) IS NOT NULL
ORDER BY pct_change DESC;
