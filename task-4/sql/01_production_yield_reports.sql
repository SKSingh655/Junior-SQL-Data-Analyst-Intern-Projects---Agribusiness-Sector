-- =============================================================================
-- Task 4 | Week 4 Internship Assessment
-- PRODUCTION & YIELD REPORTING QUERIES
-- Data Aggregation & Business Reporting
-- Database: PostgreSQL 15+
-- =============================================================================
-- Section 3 of the assessment.
-- All queries use the KPI views from views/01_kpi_views.sql.
-- Replace literal dates with :start_date / :end_date bound parameters
-- in an application layer. Use half-open intervals (>= start AND < end).
-- =============================================================================

-- =============================================================================
-- REPORT 3.1 — Annual Production by Crop and Region
-- Business question: Which crop/region combinations drove the most output?
-- Output: ranked table for procurement, storage and supply planning.
-- =============================================================================
SELECT
    ap.region_name,
    ap.crop_name,
    ap.crop_category,
    ap.season_year,
    ap.production_tonnes,
    ap.area_planted_ha,
    ap.yield_t_per_ha,
    ap.contributing_farms,
    RANK() OVER (
        PARTITION BY ap.season_year
        ORDER BY ap.production_tonnes DESC
    )                                                       AS production_rank
FROM v_annual_production AS ap
WHERE ap.season_year = 2025
ORDER BY production_rank, ap.region_name, ap.crop_name;

-- =============================================================================
-- REPORT 3.1b — Top 5 crop/region combinations per season
-- Quick executive summary: where does the most food come from?
-- =============================================================================
SELECT
    season_year,
    region_name,
    crop_name,
    production_tonnes,
    yield_t_per_ha,
    contributing_farms
FROM (
    SELECT
        ap.*,
        RANK() OVER (
            PARTITION BY season_year ORDER BY production_tonnes DESC
        ) AS rnk
    FROM v_annual_production AS ap
    WHERE season_year IN (2024, 2025)
) ranked
WHERE rnk <= 5
ORDER BY season_year DESC, rnk;

-- =============================================================================
-- REPORT 3.2 — Yield by Crop and Season (2024 vs 2025)
-- Business question: Which crops are most productive per planted hectare?
-- Note: yield is SUM(quantity) / SUM(area) — not AVG of farm yields.
-- =============================================================================
SELECT
    crop_name,
    crop_category,
    season_year,
    production_tonnes,
    area_planted_ha,
    yield_t_per_ha,
    RANK() OVER (
        PARTITION BY season_year ORDER BY yield_t_per_ha DESC
    )                                                       AS yield_rank
FROM v_annual_production
WHERE season_year IN (2024, 2025)
ORDER BY season_year, yield_rank;

-- =============================================================================
-- REPORT 3.3 — Year-over-Year Production Change
-- Business question: Which crops grew or declined vs the previous season?
-- Uses LAG window function via v_yoy_production view.
-- =============================================================================
SELECT
    crop_name,
    crop_category,
    season_year,
    production_tonnes,
    prior_year_tonnes,
    yoy_change_pct,
    trend_flag
FROM v_yoy_production
WHERE season_year >= 2024
ORDER BY season_year DESC, yoy_change_pct DESC NULLS LAST;

-- =============================================================================
-- REPORT 3.4 — Production Concentration Analysis
-- Business question: How dependent are we on a few regions/crops?
-- High share_pct signals supply-chain concentration risk.
-- =============================================================================
SELECT
    season_year,
    region_name,
    crop_name,
    production_tonnes,
    share_pct,
    production_rank,
    CASE
        WHEN share_pct >= 30 THEN 'HIGH_CONCENTRATION'
        WHEN share_pct >= 15 THEN 'MODERATE_CONCENTRATION'
        ELSE 'DIVERSIFIED'
    END                                                     AS concentration_flag
FROM v_production_concentration
WHERE season_year = 2025
ORDER BY share_pct DESC;

-- =============================================================================
-- REPORT 3.5 — Farm-Level Production Deep-Dive
-- Business question: Which farms drove the most production? Are any outliers?
-- Uses direct harvest table for farm-level granularity (not in aggregated views).
-- =============================================================================
SELECT
    f.farm_code,
    f.farm_name,
    r.region_name,
    c.crop_name,
    h.season_year,
    SUM(h.quantity_tonnes)                              AS farm_production_tonnes,
    SUM(h.area_planted_ha)                              AS farm_area_ha,
    ROUND(SUM(h.quantity_tonnes) / NULLIF(SUM(h.area_planted_ha), 0), 3)
                                                        AS farm_yield_t_per_ha,
    -- Compare each farm's yield to the crop's average that season
    ROUND(
        SUM(h.quantity_tonnes) / NULLIF(SUM(h.area_planted_ha), 0) -
        AVG(
            SUM(h.quantity_tonnes) / NULLIF(SUM(h.area_planted_ha), 0)
        ) OVER (PARTITION BY h.crop_id, h.season_year),
        3
    )                                                   AS yield_vs_crop_avg
FROM harvest    AS h
JOIN farm       AS f  ON f.farm_id   = h.farm_id
JOIN region     AS r  ON r.region_id = f.region_id
JOIN crop       AS c  ON c.crop_id   = h.crop_id
WHERE h.season_year = 2025
GROUP BY f.farm_id, f.farm_code, f.farm_name, r.region_name,
         c.crop_id, c.crop_name, h.season_year
ORDER BY farm_production_tonnes DESC;
