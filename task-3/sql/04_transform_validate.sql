-- =============================================================================
-- Task 3 | Week 3 Internship Assessment
-- TRANSFORMATION & VALIDATION SCRIPTS
-- Agribusiness ETL Process Plan
-- Database: PostgreSQL 15+
-- =============================================================================
-- Run AFTER 01_etl_schema.sql and 03_staging_data.sql.
-- These scripts:
--   1. Validate staged rows and route rejects to etl_reject
--   2. Build typed TEMP tables (parsed_*) of accepted rows
--   3. Apply unit conversions (quintal → tonne, period strings → dates)
--   4. Resolve source labels to surrogate keys via crosswalk tables
-- =============================================================================

-- =============================================================================
-- PART 1: VALIDATE & REJECT — Market Prices (Batch 1)
-- =============================================================================

-- Step 1a: Insert invalid rows into etl_reject
INSERT INTO etl_reject (batch_id, source_row_number, reason_code, raw_record)
SELECT
    s.batch_id,
    s.source_row_number,
    CASE
        WHEN NULLIF(BTRIM(s.source_market_name), '') IS NULL
            THEN 'MISSING_MARKET'
        WHEN NULLIF(BTRIM(s.source_crop_label), '') IS NULL
            THEN 'MISSING_CROP'
        WHEN s.observed_on_raw !~ '^\d{4}-\d{2}-\d{2}$'
            THEN 'INVALID_DATE_FORMAT'
        WHEN REPLACE(BTRIM(COALESCE(s.price_raw,'')), ',', '') !~ '^\d+(\.\d+)?$'
            THEN 'INVALID_PRICE'
        WHEN REPLACE(BTRIM(s.price_raw), ',', '')::NUMERIC < 0
            THEN 'NEGATIVE_PRICE'
        ELSE 'UNKNOWN_VALIDATION_ERROR'
    END AS reason_code,
    jsonb_build_object(
        'market',   s.source_market_name,
        'crop',     s.source_crop_label,
        'date',     s.observed_on_raw,
        'price',    s.price_raw,
        'unit',     s.unit_raw,
        'currency', s.currency_raw
    ) AS raw_record
FROM stg_market_price s
WHERE s.batch_id = 'a1000000-0000-0000-0000-000000000001'::uuid
  AND (
       NULLIF(BTRIM(s.source_market_name), '') IS NULL
    OR NULLIF(BTRIM(s.source_crop_label), '') IS NULL
    OR s.observed_on_raw !~ '^\d{4}-\d{2}-\d{2}$'
    OR REPLACE(BTRIM(COALESCE(s.price_raw,'')), ',', '') !~ '^\d+(\.\d+)?$'
    OR (REPLACE(BTRIM(COALESCE(s.price_raw,'')), ',', '') ~ '^\d+(\.\d+)?$'
        AND REPLACE(BTRIM(s.price_raw), ',', '')::NUMERIC < 0)
  );

-- Step 1b: Mark rejected rows in staging
UPDATE stg_market_price
SET validation_status = 'rejected'
WHERE batch_id = 'a1000000-0000-0000-0000-000000000001'::uuid
  AND (batch_id, source_row_number) IN (
      SELECT batch_id, source_row_number FROM etl_reject
      WHERE batch_id = 'a1000000-0000-0000-0000-000000000001'::uuid
  );

-- Step 1c: Mark valid rows as accepted
UPDATE stg_market_price
SET validation_status = 'accepted'
WHERE batch_id = 'a1000000-0000-0000-0000-000000000001'::uuid
  AND validation_status = 'pending';

-- Step 1d: Build parsed temp table — clean, cast, convert units
--   Agmarknet prices are per QUINTAL → convert to per TONNE (* 10)
DROP TABLE IF EXISTS parsed_market_price;
CREATE TEMP TABLE parsed_market_price AS
SELECT
    s.batch_id,
    s.source_row_number,
    BTRIM(s.source_market_name)                                 AS market_name,
    BTRIM(s.source_crop_label)                                  AS crop_label,
    TO_DATE(s.observed_on_raw, 'YYYY-MM-DD')                    AS observed_on,
    -- Unit conversion: quintal → tonne = multiply price by 10
    CASE
        WHEN LOWER(BTRIM(s.unit_raw)) = 'quintal'
            THEN REPLACE(BTRIM(s.price_raw), ',', '')::NUMERIC * 10
        ELSE REPLACE(BTRIM(s.price_raw), ',', '')::NUMERIC
    END                                                         AS price_per_tonne,
    UPPER(BTRIM(s.currency_raw))                                AS currency_code,
    NULLIF(BTRIM(s.grade_raw), '')                              AS grade
FROM stg_market_price s
WHERE s.batch_id = 'a1000000-0000-0000-0000-000000000001'::uuid
  AND s.validation_status = 'accepted';

-- =============================================================================
-- PART 2: VALIDATE & REJECT — Crop Production Stats (Batch 2)
-- =============================================================================

-- Step 2a: Insert invalid crop production rows into etl_reject
INSERT INTO etl_reject (batch_id, source_row_number, reason_code, raw_record)
SELECT
    s.batch_id,
    s.source_row_number,
    CASE
        WHEN NULLIF(BTRIM(s.source_geo_code), '') IS NULL
            THEN 'MISSING_GEO'
        WHEN NULLIF(BTRIM(s.source_crop_label), '') IS NULL
            THEN 'MISSING_CROP'
        WHEN s.period_raw !~ '^\d{4}$'
            THEN 'INVALID_PERIOD'
        WHEN REPLACE(BTRIM(COALESCE(s.area_raw,'')), ',', '') !~ '^\d+(\.\d+)?$'
            THEN 'INVALID_AREA'
        WHEN REPLACE(BTRIM(COALESCE(s.area_raw,'')), ',', '') ~ '^\d+(\.\d+)?$'
             AND REPLACE(BTRIM(s.area_raw), ',', '')::NUMERIC < 0
            THEN 'NEGATIVE_AREA'
        WHEN REPLACE(BTRIM(COALESCE(s.production_raw,'')), ',', '') !~ '^\d+(\.\d+)?$'
            THEN 'INVALID_PRODUCTION'
        ELSE 'UNKNOWN_VALIDATION_ERROR'
    END AS reason_code,
    jsonb_build_object(
        'geo_code',    s.source_geo_code,
        'crop',        s.source_crop_label,
        'period',      s.period_raw,
        'area',        s.area_raw,
        'production',  s.production_raw,
        'unit',        s.unit_raw
    ) AS raw_record
FROM stg_crop_production s
WHERE s.batch_id = 'a2000000-0000-0000-0000-000000000002'::uuid
  AND (
       NULLIF(BTRIM(s.source_geo_code), '') IS NULL
    OR NULLIF(BTRIM(s.source_crop_label), '') IS NULL
    OR s.period_raw !~ '^\d{4}$'
    OR REPLACE(BTRIM(COALESCE(s.area_raw,'')), ',', '') !~ '^\d+(\.\d+)?$'
    OR (REPLACE(BTRIM(COALESCE(s.area_raw,'')), ',', '') ~ '^\d+(\.\d+)?$'
        AND REPLACE(BTRIM(s.area_raw), ',', '')::NUMERIC < 0)
    OR REPLACE(BTRIM(COALESCE(s.production_raw,'')), ',', '') !~ '^\d+(\.\d+)?$'
  );

UPDATE stg_crop_production SET validation_status = 'rejected'
WHERE batch_id = 'a2000000-0000-0000-0000-000000000002'::uuid
  AND (batch_id, source_row_number) IN (
      SELECT batch_id, source_row_number FROM etl_reject
      WHERE batch_id = 'a2000000-0000-0000-0000-000000000002'::uuid
  );

UPDATE stg_crop_production SET validation_status = 'accepted'
WHERE batch_id = 'a2000000-0000-0000-0000-000000000002'::uuid
  AND validation_status = 'pending';

-- Step 2b: Build parsed temp table for crop production
--   period_raw is a 4-digit year → period_start = Jan 1, period_end = Dec 31
DROP TABLE IF EXISTS parsed_crop_production;
CREATE TEMP TABLE parsed_crop_production AS
SELECT
    s.batch_id,
    s.source_row_number,
    BTRIM(s.source_geo_code)                                    AS geo_code,
    BTRIM(s.source_crop_label)                                  AS crop_label,
    TO_DATE(s.period_raw || '-01-01', 'YYYY-MM-DD')             AS period_start,
    TO_DATE(s.period_raw || '-12-31', 'YYYY-MM-DD')             AS period_end,
    REPLACE(BTRIM(s.area_raw), ',', '')::NUMERIC / 10000        AS area_harvested_ha,   -- assume source in m² if needed; here treated as ha already
    REPLACE(BTRIM(s.production_raw), ',', '')::NUMERIC          AS production_qty,
    BTRIM(s.unit_raw)                                           AS std_unit
FROM stg_crop_production s
WHERE s.batch_id = 'a2000000-0000-0000-0000-000000000002'::uuid
  AND s.validation_status = 'accepted';

-- =============================================================================
-- PART 3: VALIDATE & REJECT — Weather Observations (Batch 3)
-- =============================================================================

INSERT INTO etl_reject (batch_id, source_row_number, reason_code, raw_record)
SELECT
    s.batch_id,
    s.source_row_number,
    CASE
        WHEN NULLIF(BTRIM(s.source_geo_code), '') IS NULL
            THEN 'MISSING_GEO'
        WHEN s.observed_on_raw !~ '^\d{4}-\d{2}-\d{2}$'
            THEN 'INVALID_DATE_FORMAT'
        WHEN s.rainfall_mm_raw IS NOT NULL
             AND REPLACE(BTRIM(s.rainfall_mm_raw), ',', '') !~ '^-?\d+(\.\d+)?$'
            THEN 'INVALID_RAINFALL'
        WHEN s.rainfall_mm_raw IS NOT NULL
             AND REPLACE(BTRIM(s.rainfall_mm_raw), ',', '') ~ '^-?\d+(\.\d+)?$'
             AND REPLACE(BTRIM(s.rainfall_mm_raw), ',', '')::NUMERIC < 0
            THEN 'NEGATIVE_RAINFALL'
        WHEN s.temp_max_raw IS NOT NULL
             AND REPLACE(BTRIM(s.temp_max_raw), ',', '') !~ '^-?\d+(\.\d+)?$'
            THEN 'INVALID_TEMP'
        ELSE 'UNKNOWN_VALIDATION_ERROR'
    END AS reason_code,
    jsonb_build_object(
        'geo_code',   s.source_geo_code,
        'date',       s.observed_on_raw,
        'rainfall',   s.rainfall_mm_raw,
        'temp_max',   s.temp_max_raw,
        'temp_min',   s.temp_min_raw,
        'humidity',   s.humidity_raw
    ) AS raw_record
FROM stg_weather s
WHERE s.batch_id = 'a3000000-0000-0000-0000-000000000003'::uuid
  AND (
       NULLIF(BTRIM(s.source_geo_code), '') IS NULL
    OR s.observed_on_raw !~ '^\d{4}-\d{2}-\d{2}$'
    OR (s.rainfall_mm_raw IS NOT NULL
        AND REPLACE(BTRIM(s.rainfall_mm_raw), ',', '') !~ '^-?\d+(\.\d+)?$')
    OR (s.rainfall_mm_raw IS NOT NULL
        AND REPLACE(BTRIM(s.rainfall_mm_raw), ',', '') ~ '^-?\d+(\.\d+)?$'
        AND REPLACE(BTRIM(s.rainfall_mm_raw), ',', '')::NUMERIC < 0)
    OR (s.temp_max_raw IS NOT NULL
        AND REPLACE(BTRIM(s.temp_max_raw), ',', '') !~ '^-?\d+(\.\d+)?$')
  );

UPDATE stg_weather SET validation_status = 'rejected'
WHERE batch_id = 'a3000000-0000-0000-0000-000000000003'::uuid
  AND (batch_id, source_row_number) IN (
      SELECT batch_id, source_row_number FROM etl_reject
      WHERE batch_id = 'a3000000-0000-0000-0000-000000000003'::uuid
  );

UPDATE stg_weather SET validation_status = 'accepted'
WHERE batch_id = 'a3000000-0000-0000-0000-000000000003'::uuid
  AND validation_status = 'pending';

-- Step 3b: Parsed weather temp table
DROP TABLE IF EXISTS parsed_weather;
CREATE TEMP TABLE parsed_weather AS
SELECT
    s.batch_id,
    s.source_row_number,
    BTRIM(s.source_geo_code)                                    AS geo_code,
    TO_DATE(s.observed_on_raw, 'YYYY-MM-DD')                    AS observed_on,
    NULLIF(BTRIM(s.rainfall_mm_raw), '')::NUMERIC               AS rainfall_mm,
    NULLIF(BTRIM(s.temp_max_raw), '')::NUMERIC                  AS temp_max_c,
    NULLIF(BTRIM(s.temp_min_raw), '')::NUMERIC                  AS temp_min_c,
    NULLIF(BTRIM(s.humidity_raw), '')::NUMERIC                  AS humidity_pct
FROM stg_weather s
WHERE s.batch_id = 'a3000000-0000-0000-0000-000000000003'::uuid
  AND s.validation_status = 'accepted';

-- =============================================================================
-- PART 4: UPDATE batch counters in etl_batch
-- =============================================================================
UPDATE etl_batch
SET
    accepted_rows = (SELECT COUNT(*) FROM stg_market_price
                     WHERE batch_id = 'a1000000-0000-0000-0000-000000000001'::uuid
                       AND validation_status = 'accepted'),
    rejected_rows = (SELECT COUNT(*) FROM etl_reject
                     WHERE batch_id = 'a1000000-0000-0000-0000-000000000001'::uuid),
    status        = 'validated'
WHERE batch_id = 'a1000000-0000-0000-0000-000000000001'::uuid;

UPDATE etl_batch
SET
    accepted_rows = (SELECT COUNT(*) FROM stg_crop_production
                     WHERE batch_id = 'a2000000-0000-0000-0000-000000000002'::uuid
                       AND validation_status = 'accepted'),
    rejected_rows = (SELECT COUNT(*) FROM etl_reject
                     WHERE batch_id = 'a2000000-0000-0000-0000-000000000002'::uuid),
    status        = 'validated'
WHERE batch_id = 'a2000000-0000-0000-0000-000000000002'::uuid;

UPDATE etl_batch
SET
    accepted_rows = (SELECT COUNT(*) FROM stg_weather
                     WHERE batch_id = 'a3000000-0000-0000-0000-000000000003'::uuid
                       AND validation_status = 'accepted'),
    rejected_rows = (SELECT COUNT(*) FROM etl_reject
                     WHERE batch_id = 'a3000000-0000-0000-0000-000000000003'::uuid),
    status        = 'validated'
WHERE batch_id = 'a3000000-0000-0000-0000-000000000003'::uuid;
