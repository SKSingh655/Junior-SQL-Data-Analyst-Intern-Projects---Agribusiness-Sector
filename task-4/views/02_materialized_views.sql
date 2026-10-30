-- =============================================================================
-- Task 4 | Week 4 Internship Assessment
-- MATERIALIZED VIEWS FOR HIGH-FREQUENCY REPORTS
-- Data Aggregation & Business Reporting
-- Database: PostgreSQL 15+
-- =============================================================================
-- Use materialized views ONLY when:
--   1. The query is expensive and results do not need real-time freshness.
--   2. The underlying data changes on a known schedule (e.g., daily ETL).
-- Refresh after every successful ETL load (see 05_load_curated.sql in Task 3).
-- =============================================================================

-- =============================================================================
-- MAT VIEW 1: mv_annual_production
-- Pre-aggregated production & yield by region/crop/season for dashboards.
-- Refresh: CONCURRENTLY requires a UNIQUE index; refresh after each ETL load.
-- =============================================================================
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_annual_production AS
SELECT
    r.region_name,
    r.country_code,
    c.crop_name,
    c.crop_category,
    h.season_year,
    SUM(h.quantity_tonnes)                              AS production_tonnes,
    SUM(h.area_planted_ha)                              AS area_planted_ha,
    ROUND(
        SUM(h.quantity_tonnes) /
        NULLIF(SUM(h.area_planted_ha), 0), 3
    )                                                   AS yield_t_per_ha,
    COUNT(DISTINCT h.farm_id)                           AS contributing_farms
FROM harvest    AS h
JOIN farm       AS f  ON f.farm_id   = h.farm_id
JOIN region     AS r  ON r.region_id = f.region_id
JOIN crop       AS c  ON c.crop_id   = h.crop_id
GROUP BY r.region_name, r.country_code, c.crop_name, c.crop_category, h.season_year
WITH DATA;

-- Unique index required for REFRESH CONCURRENTLY (non-blocking refresh)
CREATE UNIQUE INDEX IF NOT EXISTS uidx_mv_annual_production
  ON mv_annual_production(region_name, crop_name, season_year);

-- Standard index for fast dashboard filters
CREATE INDEX IF NOT EXISTS idx_mv_annual_production_year
  ON mv_annual_production(season_year);

COMMENT ON MATERIALIZED VIEW mv_annual_production IS
  'Pre-aggregated production KPIs. Refresh after ETL load: '
  'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_annual_production;';

-- =============================================================================
-- MAT VIEW 2: mv_monthly_price_summary
-- Pre-aggregated monthly price stats per crop/market/currency.
-- =============================================================================
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_monthly_price_summary AS
SELECT
    c.crop_name,
    m.market_name,
    r.region_name,
    DATE_TRUNC('month', mp.observed_on)::date           AS price_month,
    mp.currency_code,
    ROUND(AVG(mp.price_per_tonne), 2)                   AS avg_price_per_tonne,
    MIN(mp.price_per_tonne)                             AS min_price,
    MAX(mp.price_per_tonne)                             AS max_price,
    COUNT(*)                                            AS observations
FROM market_price   AS mp
JOIN crop           AS c  ON c.crop_id   = mp.crop_id
JOIN market         AS m  ON m.market_id = mp.market_id
JOIN region         AS r  ON r.region_id = m.region_id
GROUP BY c.crop_name, m.market_name, r.region_name,
         DATE_TRUNC('month', mp.observed_on), mp.currency_code
WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS uidx_mv_monthly_price
  ON mv_monthly_price_summary(crop_name, market_name, price_month, currency_code);

CREATE INDEX IF NOT EXISTS idx_mv_monthly_price_month
  ON mv_monthly_price_summary(price_month, currency_code);

COMMENT ON MATERIALIZED VIEW mv_monthly_price_summary IS
  'Pre-aggregated monthly market price KPIs. '
  'Refresh: REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_price_summary;';

-- =============================================================================
-- REFRESH COMMANDS (run after each successful ETL load)
-- =============================================================================
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_annual_production;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_price_summary;
