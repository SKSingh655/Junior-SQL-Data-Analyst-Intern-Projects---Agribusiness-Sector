-- =====================================================================
-- File: 04_analytical_queries.sql  (query library grouped by decision area)
-- =====================================================================
SET search_path TO agri;

-- Q1. Weighted yield per crop and year (descriptive aggregation)
SELECT c.crop_name,
       p.season_year,
       SUM(p.area_planted_ha)       AS total_area_ha,
       SUM(p.production_tonnes)     AS total_production_t,
       ROUND(SUM(p.production_tonnes) / NULLIF(SUM(p.area_planted_ha), 0), 3)
                                    AS weighted_yield_t_ha
FROM fact_crop_production p
JOIN dim_crop c ON c.crop_id = p.crop_id
GROUP BY c.crop_name, p.season_year
ORDER BY c.crop_name, p.season_year;

-- Q2. Top districts for a crop and year (CTE + RANK window function)
WITH district_yield AS (
    SELECT r.state_name, r.district,
           SUM(p.production_tonnes) / NULLIF(SUM(p.area_planted_ha), 0) AS yield_t_ha
    FROM fact_crop_production p
    JOIN dim_farm   f ON f.farm_id   = p.farm_id
    JOIN dim_region r ON r.region_id = f.region_id
    JOIN dim_crop   c ON c.crop_id   = p.crop_id
    WHERE c.crop_name = 'Wheat' AND p.season_year = 2024
    GROUP BY r.state_name, r.district
)
SELECT state_name, district, ROUND(yield_t_ha, 3) AS yield_t_ha,
       RANK() OVER (ORDER BY yield_t_ha DESC) AS yield_rank
FROM district_yield
ORDER BY yield_rank
LIMIT 5;

-- Q3. Year-on-year yield growth (LAG window function)
WITH yearly AS (
    SELECT c.crop_name, p.season_year,
           SUM(p.production_tonnes) / NULLIF(SUM(p.area_planted_ha), 0) AS yield_t_ha
    FROM fact_crop_production p
    JOIN dim_crop c ON c.crop_id = p.crop_id
    GROUP BY c.crop_name, p.season_year
), with_prev AS (
    SELECT crop_name, season_year, yield_t_ha,
           LAG(yield_t_ha) OVER (PARTITION BY crop_name ORDER BY season_year) AS prev_yield
    FROM yearly
)
SELECT crop_name, season_year, ROUND(yield_t_ha, 3) AS yield_t_ha,
       ROUND(100.0 * (yield_t_ha - prev_yield) / NULLIF(prev_yield, 0), 2) AS yoy_pct
FROM with_prev
ORDER BY crop_name, season_year;

-- Q4. Profitability per crop and year (pre-aggregate each fact, then join)
WITH ic AS (
    SELECT farm_id, crop_id, season_year, SUM(cost) AS input_cost
    FROM fact_input_usage
    GROUP BY farm_id, crop_id, season_year
), rv AS (
    SELECT farm_id, crop_id, EXTRACT(YEAR FROM sale_date)::INT AS season_year,
           SUM(revenue) AS revenue
    FROM fact_sales
    GROUP BY farm_id, crop_id, EXTRACT(YEAR FROM sale_date)::INT
)
SELECT c.crop_name, rv.season_year,
       SUM(rv.revenue)                                  AS revenue,
       SUM(ic.input_cost)                               AS input_cost,
       SUM(rv.revenue) - SUM(ic.input_cost)             AS gross_margin,
       ROUND(SUM(rv.revenue) / NULLIF(SUM(ic.input_cost), 0), 2) AS benefit_cost_ratio
FROM rv
JOIN ic ON ic.farm_id = rv.farm_id AND ic.crop_id = rv.crop_id
       AND ic.season_year = rv.season_year
JOIN dim_crop c ON c.crop_id = rv.crop_id
GROUP BY c.crop_name, rv.season_year
ORDER BY gross_margin DESC;

-- Q5. Input cost structure per crop (conditional aggregation with FILTER)
SELECT c.crop_name,
       SUM(i.cost) AS total_cost,
       ROUND(100.0 * SUM(i.cost) FILTER (WHERE i.input_type = 'fertilizer')
             / NULLIF(SUM(i.cost), 0), 1) AS fertilizer_share_pct,
       ROUND(100.0 * SUM(i.cost) FILTER (WHERE i.input_type = 'labour')
             / NULLIF(SUM(i.cost), 0), 1) AS labour_share_pct
FROM fact_input_usage i
JOIN dim_crop c ON c.crop_id = i.crop_id
GROUP BY c.crop_name
ORDER BY total_cost DESC;

-- Q6. Livestock productivity and mortality by species and month
SELECT s.species_name,
       DATE_TRUNC('month', l.record_date)::DATE AS month_start,
       ROUND(SUM(l.milk_litres) / NULLIF(SUM(l.head_count), 0), 2) AS litres_per_head_per_day,
       ROUND(100.0 * SUM(l.mortality_count) / NULLIF(AVG(l.head_count) * COUNT(*), 0), 3)
                                                        AS mortality_pct
FROM fact_livestock_record l
JOIN dim_livestock_species s ON s.species_id = l.species_id
GROUP BY s.species_name, DATE_TRUNC('month', l.record_date)
ORDER BY s.species_name, month_start;

-- Q7. 30-record moving average of modal price (window frame)
SELECT p.price_date, m.market_name, c.crop_name, p.modal_price,
       ROUND(AVG(p.modal_price) OVER (
                 PARTITION BY p.market_id, p.crop_id
                 ORDER BY p.price_date
                 ROWS BETWEEN 29 PRECEDING AND CURRENT ROW), 2) AS moving_avg_30
FROM fact_market_price p
JOIN dim_market m ON m.market_id = p.market_id
JOIN dim_crop   c ON c.crop_id   = p.crop_id
WHERE c.crop_name = 'Onion' AND p.price_date >= DATE '2024-01-01'
ORDER BY p.market_id, p.price_date;

-- Q8. Monthly price volatility (coefficient of variation) and seasonal index
WITH monthly AS (
    SELECT p.crop_id, DATE_TRUNC('month', p.price_date)::DATE AS month_start,
           AVG(p.modal_price)         AS avg_price,
           STDDEV_SAMP(p.modal_price) AS sd_price
    FROM fact_market_price p
    GROUP BY p.crop_id, DATE_TRUNC('month', p.price_date)
)
SELECT c.crop_name, mo.month_start,
       ROUND(mo.avg_price, 2) AS avg_price,
       ROUND(100.0 * mo.sd_price / NULLIF(mo.avg_price, 0), 2) AS cv_pct,
       ROUND(100.0 * mo.avg_price /
             NULLIF(AVG(mo.avg_price) OVER (PARTITION BY mo.crop_id), 0), 1) AS seasonal_index
FROM monthly mo
JOIN dim_crop c ON c.crop_id = mo.crop_id
ORDER BY c.crop_name, mo.month_start;

-- Q9. Monsoon rainfall versus rice yield (CORR aggregate across regions)
WITH rain AS (
    SELECT region_id, EXTRACT(YEAR FROM obs_date)::INT AS yr, SUM(rainfall_mm) AS rain_mm
    FROM fact_weather_daily
    WHERE EXTRACT(MONTH FROM obs_date) BETWEEN 6 AND 9
    GROUP BY region_id, EXTRACT(YEAR FROM obs_date)::INT
), yld AS (
    SELECT f.region_id, p.season_year AS yr,
           SUM(p.production_tonnes) / NULLIF(SUM(p.area_planted_ha), 0) AS yield_t_ha
    FROM fact_crop_production p
    JOIN dim_farm f ON f.farm_id = p.farm_id
    JOIN dim_crop c ON c.crop_id = p.crop_id
    WHERE c.crop_name = 'Rice' AND p.season = 'kharif'
    GROUP BY f.region_id, p.season_year
)
SELECT ROUND(CORR(rain.rain_mm, yld.yield_t_ha)::NUMERIC, 3) AS pearson_r,
       COUNT(*) AS n_region_years
FROM rain
JOIN yld ON yld.region_id = rain.region_id AND yld.yr = rain.yr;

-- Q10. Latest soil test per farm with nutrient status flags (DISTINCT ON + CASE)
-- Thresholds are illustrative (Indian Soil Health Card style); confirm locally.
SELECT DISTINCT ON (s.farm_id)
       s.farm_id, s.test_date, s.ph,
       CASE WHEN s.ph < 5.5 THEN 'Acidic'
            WHEN s.ph > 8.5 THEN 'Alkaline' ELSE 'Normal' END      AS ph_status,
       CASE WHEN s.nitrogen_kg_ha   < 280 THEN 'Low' ELSE 'Adequate' END AS n_status,
       CASE WHEN s.phosphorus_kg_ha < 10  THEN 'Low' ELSE 'Adequate' END AS p_status,
       CASE WHEN s.potassium_kg_ha  < 108 THEN 'Low' ELSE 'Adequate' END AS k_status
FROM fact_soil_test s
ORDER BY s.farm_id, s.test_date DESC;

-- Q11. Yield outliers using z-scores (anomaly detection with window statistics)
WITH base AS (
    SELECT p.production_id, c.crop_name, p.season_year, p.yield_t_per_ha,
           AVG(p.yield_t_per_ha)         OVER (PARTITION BY p.crop_id) AS mean_y,
           STDDEV_SAMP(p.yield_t_per_ha) OVER (PARTITION BY p.crop_id) AS sd_y
    FROM fact_crop_production p
    JOIN dim_crop c ON c.crop_id = p.crop_id
)
SELECT production_id, crop_name, season_year, yield_t_per_ha,
       ROUND((yield_t_per_ha - mean_y) / NULLIF(sd_y, 0), 2) AS z_score
FROM base
WHERE ABS((yield_t_per_ha - mean_y) / NULLIF(sd_y, 0)) > 3
ORDER BY ABS((yield_t_per_ha - mean_y) / NULLIF(sd_y, 0)) DESC;

-- Q12. Farm performance quartiles within each crop-year (NTILE)
SELECT c.crop_name, p.season_year, p.farm_id, p.yield_t_per_ha,
       NTILE(4) OVER (PARTITION BY p.crop_id, p.season_year
                      ORDER BY p.yield_t_per_ha DESC) AS performance_quartile
FROM fact_crop_production p
JOIN dim_crop c ON c.crop_id = p.crop_id;

-- Q13. Data-quality audit queries
-- 13a. Duplicate natural keys (should return zero rows)
SELECT market_id, crop_id, price_date, COUNT(*) AS n
FROM fact_market_price
GROUP BY market_id, crop_id, price_date
HAVING COUNT(*) > 1;

-- 13b. Farms that never reported production (LEFT JOIN anti-join)
SELECT f.farm_id, f.farm_name
FROM dim_farm f
LEFT JOIN fact_crop_production p ON p.farm_id = f.farm_id
WHERE p.farm_id IS NULL AND f.farm_type IN ('crop','mixed');

-- 13c. Column completeness report
SELECT COUNT(*)                                       AS total_rows,
       COUNT(*) FILTER (WHERE irrigation_type IS NULL) AS missing_irrigation,
       ROUND(100.0 * COUNT(*) FILTER (WHERE irrigation_type IS NULL)
             / NULLIF(COUNT(*), 0), 1)                AS missing_irrigation_pct
FROM fact_crop_production;

-- Q14. Reporting layer: materialized view refreshed after each load
CREATE MATERIALIZED VIEW mv_monthly_crop_price AS
SELECT p.crop_id,
       p.market_id,
       DATE_TRUNC('month', p.price_date)::DATE AS month_start,
       AVG(p.modal_price)                      AS avg_modal_price,
       MIN(p.min_price)                        AS lowest_price,
       MAX(p.max_price)                        AS highest_price,
       SUM(p.arrivals_tonnes)                  AS total_arrivals_t
FROM fact_market_price p
GROUP BY p.crop_id, p.market_id, DATE_TRUNC('month', p.price_date)
WITH DATA;

CREATE UNIQUE INDEX ux_mv_monthly_crop_price
    ON mv_monthly_crop_price (crop_id, market_id, month_start);

-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_crop_price;
