-- =============================================================================
-- Task 4 | Week 4 Internship Assessment
-- KPI VIEWS & REUSABLE REPORTING LAYER
-- Data Aggregation & Business Reporting
-- Database: PostgreSQL 15+
-- =============================================================================
-- Prerequisite: Task 2 schema (01_schema.sql) + Task 3 ETL schema (01_etl_schema.sql)
-- These views encapsulate the KPI definitions from Section 1.2 of the assessment.
-- Stable reporting logic is packaged here so queries in 02_reports.sql stay clean.
-- =============================================================================

-- =============================================================================
-- VIEW 1: v_annual_production
-- KPI: Total Production — SUM(quantity_tonnes) by crop, region, season
-- Grain: one row per region × crop × season_year
-- =============================================================================
CREATE OR REPLACE VIEW v_annual_production AS
SELECT
    r.region_id,
    r.region_name,
    r.country_code,
    c.crop_id,
    c.crop_name,
    c.crop_category,
    h.season_year,
    SUM(h.quantity_tonnes)                              AS production_tonnes,
    SUM(h.area_planted_ha)                              AS area_planted_ha,
    ROUND(
        SUM(h.quantity_tonnes) /
        NULLIF(SUM(h.area_planted_ha), 0), 3
    )                                                   AS yield_t_per_ha,
    COUNT(DISTINCT h.farm_id)                           AS contributing_farms,
    MIN(h.harvest_date)                                 AS earliest_harvest,
    MAX(h.harvest_date)                                 AS latest_harvest
FROM harvest    AS h
JOIN farm       AS f  ON f.farm_id   = h.farm_id
JOIN region     AS r  ON r.region_id = f.region_id
JOIN crop       AS c  ON c.crop_id   = h.crop_id
GROUP BY r.region_id, r.region_name, r.country_code,
         c.crop_id, c.crop_name, c.crop_category, h.season_year;

COMMENT ON VIEW v_annual_production IS
  'KPI: Total production and planted-area yield per region/crop/season. '
  'Filter by season_year or region_name before using in reports.';

-- =============================================================================
-- VIEW 2: v_yoy_production
-- KPI: Production Change (%) — year-over-year using LAG window function
-- Grain: one row per crop × season_year
-- =============================================================================
CREATE OR REPLACE VIEW v_yoy_production AS
WITH annual AS (
    SELECT
        crop_id,
        season_year,
        SUM(quantity_tonnes)   AS production_tonnes,
        SUM(area_planted_ha)   AS area_planted_ha
    FROM harvest
    GROUP BY crop_id, season_year
),
lagged AS (
    SELECT
        crop_id,
        season_year,
        production_tonnes,
        area_planted_ha,
        LAG(production_tonnes) OVER (
            PARTITION BY crop_id ORDER BY season_year
        )                       AS prior_year_tonnes
    FROM annual
)
SELECT
    c.crop_name,
    c.crop_category,
    l.season_year,
    l.production_tonnes,
    l.prior_year_tonnes,
    l.area_planted_ha,
    ROUND(
        100.0 * (l.production_tonnes - l.prior_year_tonnes) /
        NULLIF(l.prior_year_tonnes, 0), 2
    )                                                   AS yoy_change_pct,
    CASE
        WHEN l.prior_year_tonnes IS NULL          THEN 'no_prior_year'
        WHEN l.prior_year_tonnes = 0             THEN 'prior_was_zero'
        WHEN l.production_tonnes > l.prior_year_tonnes THEN 'growth'
        WHEN l.production_tonnes < l.prior_year_tonnes THEN 'decline'
        ELSE 'flat'
    END                                                 AS trend_flag
FROM lagged AS l
JOIN crop AS c ON c.crop_id = l.crop_id;

COMMENT ON VIEW v_yoy_production IS
  'KPI: Year-over-year production change percentage per crop. '
  'trend_flag classifies direction. NULL prior_year_tonnes means first recorded year.';

-- =============================================================================
-- VIEW 3: v_monthly_market_price
-- KPI: Average Market Price — by crop, market, month, currency
-- Grain: one row per crop × market × calendar month × currency
-- =============================================================================
CREATE OR REPLACE VIEW v_monthly_market_price AS
SELECT
    c.crop_id,
    c.crop_name,
    c.crop_category,
    m.market_id,
    m.market_name,
    m.market_type,
    r.region_id,
    r.region_name,
    DATE_TRUNC('month', mp.observed_on)::date           AS price_month,
    mp.currency_code,
    ROUND(AVG(mp.price_per_tonne), 2)                   AS avg_price_per_tonne,
    MIN(mp.price_per_tonne)                             AS min_price,
    MAX(mp.price_per_tonne)                             AS max_price,
    ROUND(MAX(mp.price_per_tonne) - MIN(mp.price_per_tonne), 2)
                                                        AS price_range,
    COUNT(*)                                            AS observations
FROM market_price   AS mp
JOIN crop           AS c  ON c.crop_id   = mp.crop_id
JOIN market         AS m  ON m.market_id = mp.market_id
JOIN region         AS r  ON r.region_id = m.region_id
GROUP BY c.crop_id, c.crop_name, c.crop_category,
         m.market_id, m.market_name, m.market_type,
         r.region_id, r.region_name,
         DATE_TRUNC('month', mp.observed_on),
         mp.currency_code;

COMMENT ON VIEW v_monthly_market_price IS
  'KPI: Monthly average/min/max market prices per crop/market/currency. '
  'Filter by currency_code and price_month; use observations to flag thin markets.';

-- =============================================================================
-- VIEW 4: v_price_yoy
-- KPI: Price Change (%) — month-over-month and year-over-year via LAG
-- Grain: one row per crop × market × month × currency
-- =============================================================================
CREATE OR REPLACE VIEW v_price_yoy AS
SELECT
    crop_name,
    market_name,
    region_name,
    price_month,
    currency_code,
    avg_price_per_tonne,
    observations,
    LAG(avg_price_per_tonne) OVER (
        PARTITION BY crop_id, market_id, currency_code
        ORDER BY price_month
    )                                                   AS prior_month_price,
    ROUND(
        100.0 * (avg_price_per_tonne -
            LAG(avg_price_per_tonne) OVER (
                PARTITION BY crop_id, market_id, currency_code
                ORDER BY price_month
            )
        ) /
        NULLIF(LAG(avg_price_per_tonne) OVER (
            PARTITION BY crop_id, market_id, currency_code
            ORDER BY price_month
        ), 0), 2
    )                                                   AS mom_change_pct
FROM v_monthly_market_price;

COMMENT ON VIEW v_price_yoy IS
  'KPI: Month-over-month price change % built on v_monthly_market_price. '
  'Filter to a single currency and crop for meaningful comparisons.';

-- =============================================================================
-- VIEW 5: v_latest_livestock
-- KPI: Livestock Inventory — latest observation per farm × livestock type
-- Grain: one row per farm × livestock_type (most recent snapshot)
-- =============================================================================
CREATE OR REPLACE VIEW v_latest_livestock AS
WITH ranked AS (
    SELECT
        lo.*,
        ROW_NUMBER() OVER (
            PARTITION BY lo.farm_id, lo.livestock_type_id
            ORDER BY lo.observed_on DESC, lo.observation_id DESC
        )                                               AS rn
    FROM livestock_observation AS lo
)
SELECT
    f.farm_id,
    f.farm_name,
    f.farm_code,
    r.region_name,
    lt.type_name                                        AS livestock_type,
    lt.production_purpose,
    rk.observed_on                                      AS latest_observation_date,
    rk.animal_count,
    rk.average_weight_kg
FROM ranked         AS rk
JOIN farm           AS f  ON f.farm_id           = rk.farm_id
JOIN region         AS r  ON r.region_id         = f.region_id
JOIN livestock_type AS lt ON lt.livestock_type_id = rk.livestock_type_id
WHERE rk.rn = 1;

COMMENT ON VIEW v_latest_livestock IS
  'KPI: Latest animal count per farm × livestock type. '
  'Never sums all historical observations — that would double-count animals.';

-- =============================================================================
-- VIEW 6: v_production_concentration
-- KPI: Production Concentration — region/crop share of total production
-- Grain: one row per region × crop × season_year
-- =============================================================================
CREATE OR REPLACE VIEW v_production_concentration AS
WITH totals AS (
    SELECT season_year, SUM(production_tonnes) AS grand_total
    FROM v_annual_production
    GROUP BY season_year
)
SELECT
    ap.region_name,
    ap.crop_name,
    ap.season_year,
    ap.production_tonnes,
    t.grand_total,
    ROUND(100.0 * ap.production_tonnes / NULLIF(t.grand_total, 0), 2)
                                                        AS share_pct,
    RANK() OVER (
        PARTITION BY ap.season_year ORDER BY ap.production_tonnes DESC
    )                                                   AS production_rank
FROM v_annual_production AS ap
JOIN totals              AS t  ON t.season_year = ap.season_year;

COMMENT ON VIEW v_production_concentration IS
  'KPI: Regional/crop concentration — share of total production per season. '
  'High share_pct signals supply-chain concentration risk.';

-- =============================================================================
-- VIEW 7: v_data_quality_summary
-- KPI: Data Quality Rate — accepted rows / parsed rows per ETL batch
-- Grain: one row per ETL batch
-- =============================================================================
CREATE OR REPLACE VIEW v_data_quality_summary AS
SELECT
    eb.batch_id,
    eb.source_name,
    eb.status,
    eb.extracted_rows,
    eb.accepted_rows,
    eb.rejected_rows,
    eb.loaded_rows,
    eb.retrieved_at,
    CASE
        WHEN eb.extracted_rows = 0 THEN NULL
        ELSE ROUND(100.0 * eb.accepted_rows / eb.extracted_rows, 2)
    END                                                 AS quality_rate_pct,
    CASE
        WHEN eb.extracted_rows = 0 THEN NULL
        ELSE ROUND(100.0 * eb.rejected_rows / eb.extracted_rows, 2)
    END                                                 AS reject_rate_pct,
    CASE
        WHEN eb.extracted_rows = 0 THEN 'no_data'
        WHEN eb.rejected_rows::NUMERIC / eb.extracted_rows > 0.05
            THEN 'high_reject_rate'
        WHEN eb.accepted_rows != eb.loaded_rows
            THEN 'reconciliation_gap'
        WHEN eb.status != 'loaded'
            THEN 'incomplete_batch'
        ELSE 'healthy'
    END                                                 AS health_status
FROM etl_batch AS eb;

COMMENT ON VIEW v_data_quality_summary IS
  'KPI: Data quality rate per ETL batch. '
  'health_status = high_reject_rate if >5% rows rejected; reconciliation_gap if accepted != loaded.';
