-- =============================================================================
-- Task 3 | Week 3 Internship Assessment
-- ETL SCHEMA: Staging, Raw Landing, Crosswalks, Batch Audit & Rejects
-- Agribusiness ETL Process Plan
-- Database: PostgreSQL 15+
-- =============================================================================
-- Run order: 01_etl_schema.sql → 02_curated_extensions.sql → 03_staging_data.sql
--            → 04_transform_validate.sql → 05_load_curated.sql
--            → 06_monitoring_tests.sql
-- =============================================================================

-- =============================================================================
-- SECTION A: BATCH AUDIT TABLE
-- Tracks every pipeline run from extraction through to load.
-- =============================================================================
CREATE TABLE IF NOT EXISTS etl_batch (
  batch_id          UUID         PRIMARY KEY,
  source_name       TEXT         NOT NULL,
  source_uri        TEXT,
  retrieved_at      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status            TEXT         NOT NULL
    CHECK (status IN ('started','extracted','validated','loaded','failed')),
  extracted_rows    BIGINT       NOT NULL DEFAULT 0,
  accepted_rows     BIGINT       NOT NULL DEFAULT 0,
  rejected_rows     BIGINT       NOT NULL DEFAULT 0,
  loaded_rows       BIGINT       NOT NULL DEFAULT 0,
  error_message     TEXT,
  schema_version    TEXT,
  file_hash         TEXT
);

COMMENT ON TABLE etl_batch IS
  'One row per pipeline batch run. Watermark must not advance if status != loaded.';
COMMENT ON COLUMN etl_batch.file_hash   IS 'SHA-256 or MD5 of the source file for duplicate-file detection.';
COMMENT ON COLUMN etl_batch.status      IS 'State machine: started → extracted → validated → loaded (or failed at any step).';

-- =============================================================================
-- SECTION B: RAW REJECT TABLE
-- Quarantines invalid rows with a reason code rather than silently dropping them.
-- =============================================================================
CREATE TABLE IF NOT EXISTS etl_reject (
  reject_id         BIGSERIAL    PRIMARY KEY,
  batch_id          UUID         NOT NULL REFERENCES etl_batch(batch_id),
  source_row_number BIGINT       NOT NULL,
  reason_code       TEXT         NOT NULL,
  raw_record        JSONB,
  rejected_at       TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_etl_reject_batch
  ON etl_reject(batch_id);

COMMENT ON TABLE etl_reject IS
  'All rows failing validation. Inspect to fix source issues or mapping gaps.';

-- =============================================================================
-- SECTION C: CANONICAL CROSSWALK TABLES
-- Map source-specific labels to governed surrogate keys.
-- Safer than hard-coded CASE expressions; auditable and reusable.
-- =============================================================================

-- C1. Crop alias: maps each source's crop label to the canonical crop_id
CREATE TABLE IF NOT EXISTS crop_alias (
  source_name       TEXT    NOT NULL,
  source_crop_label TEXT    NOT NULL,
  crop_id           BIGINT  NOT NULL REFERENCES crop(crop_id),
  notes             TEXT,
  PRIMARY KEY (source_name, source_crop_label)
);

COMMENT ON TABLE crop_alias IS
  'Crosswalk between source-specific commodity labels and canonical crop_id.';

-- C2. Geography alias: maps each source's geographic code to region_id
CREATE TABLE IF NOT EXISTS geography_alias (
  source_name       TEXT    NOT NULL,
  source_geo_code   TEXT    NOT NULL,
  geography_id      BIGINT  NOT NULL REFERENCES region(region_id),
  notes             TEXT,
  PRIMARY KEY (source_name, source_geo_code)
);

COMMENT ON TABLE geography_alias IS
  'Crosswalk between source geographic codes/names and canonical region_id.';

-- C3. Market alias: maps each source's market label to market_id
CREATE TABLE IF NOT EXISTS market_alias (
  source_name          TEXT    NOT NULL,
  source_market_label  TEXT    NOT NULL,
  market_id            BIGINT  NOT NULL REFERENCES market(market_id),
  notes                TEXT,
  PRIMARY KEY (source_name, source_market_label)
);

COMMENT ON TABLE market_alias IS
  'Crosswalk between source market labels and canonical market_id.';

-- =============================================================================
-- SECTION D: STAGING TABLES (TEXT-FIRST, source-specific raw fields)
-- Purpose: accept source rows without parsing failures, then validate
--          and cast in a controlled downstream step.
-- =============================================================================

-- D1. Market price staging (Agmarknet / similar sources)
CREATE TABLE IF NOT EXISTS stg_market_price (
  batch_id              UUID    NOT NULL REFERENCES etl_batch(batch_id),
  source_row_number     BIGINT  NOT NULL,
  source_market_name    TEXT,
  source_crop_label     TEXT,
  observed_on_raw       TEXT,
  price_raw             TEXT,
  unit_raw              TEXT,
  currency_raw          TEXT,
  grade_raw             TEXT,
  source_updated_at     TIMESTAMPTZ,
  validation_status     TEXT    DEFAULT 'pending'
    CHECK (validation_status IN ('pending','accepted','rejected')),
  PRIMARY KEY (batch_id, source_row_number)
);

CREATE INDEX IF NOT EXISTS idx_stg_market_price_batch
  ON stg_market_price(batch_id, validation_status);

COMMENT ON TABLE stg_market_price IS
  'Raw market price rows from source. TEXT columns prevent early parse failures.';

-- D2. Crop production statistics staging (FAOSTAT / national crop reports)
CREATE TABLE IF NOT EXISTS stg_crop_production (
  batch_id              UUID    NOT NULL REFERENCES etl_batch(batch_id),
  source_row_number     BIGINT  NOT NULL,
  source_geo_code       TEXT,
  source_geo_name       TEXT,
  source_crop_label     TEXT,
  period_raw            TEXT,   -- e.g. '2025', '2024-25', 'Rabi 2025'
  area_raw              TEXT,
  production_raw        TEXT,
  unit_raw              TEXT,
  source_updated_at     TIMESTAMPTZ,
  validation_status     TEXT    DEFAULT 'pending'
    CHECK (validation_status IN ('pending','accepted','rejected')),
  PRIMARY KEY (batch_id, source_row_number)
);

CREATE INDEX IF NOT EXISTS idx_stg_crop_production_batch
  ON stg_crop_production(batch_id, validation_status);

-- D3. Weather observation staging (IMD / NASA POWER)
CREATE TABLE IF NOT EXISTS stg_weather (
  batch_id              UUID    NOT NULL REFERENCES etl_batch(batch_id),
  source_row_number     BIGINT  NOT NULL,
  source_geo_code       TEXT,
  observed_on_raw       TEXT,
  rainfall_mm_raw       TEXT,
  temp_max_raw          TEXT,
  temp_min_raw          TEXT,
  humidity_raw          TEXT,
  source_updated_at     TIMESTAMPTZ,
  validation_status     TEXT    DEFAULT 'pending'
    CHECK (validation_status IN ('pending','accepted','rejected')),
  PRIMARY KEY (batch_id, source_row_number)
);

CREATE INDEX IF NOT EXISTS idx_stg_weather_batch
  ON stg_weather(batch_id, validation_status);

-- =============================================================================
-- SECTION E: CURATED EXTENSION TABLES
-- Extend the Week 2 schema with ETL-specific and aggregate fact tables.
-- =============================================================================

-- E1. Aggregate crop production statistics (public national data, no farm_id)
CREATE TABLE IF NOT EXISTS crop_production_stat (
  stat_id             BIGINT        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  geography_id        BIGINT        NOT NULL REFERENCES region(region_id),
  crop_id             BIGINT        NOT NULL REFERENCES crop(crop_id),
  period_start        DATE          NOT NULL,
  period_end          DATE          NOT NULL,
  area_harvested_ha   NUMERIC(16,2),
  production_quantity NUMERIC(18,3),
  standard_unit       VARCHAR(30)   NOT NULL DEFAULT 'tonne',
  source_id           UUID          NOT NULL REFERENCES etl_batch(batch_id),
  CONSTRAINT uq_crop_stat UNIQUE (geography_id, crop_id, period_start, period_end, source_id)
);

CREATE INDEX IF NOT EXISTS idx_crop_stat_geo_period_crop
  ON crop_production_stat(geography_id, period_start, crop_id);

COMMENT ON TABLE crop_production_stat IS
  'Aggregate crop production from public datasets. Never invent farm_id for these rows.';

-- E2. Weather observations
CREATE TABLE IF NOT EXISTS weather_observation (
  obs_id              BIGINT        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  geography_id        BIGINT        NOT NULL REFERENCES region(region_id),
  observed_on         DATE          NOT NULL,
  rainfall_mm         NUMERIC(8,2),
  temp_max_c          NUMERIC(5,2),
  temp_min_c          NUMERIC(5,2),
  humidity_pct        NUMERIC(5,2),
  source_id           UUID          NOT NULL REFERENCES etl_batch(batch_id),
  CONSTRAINT uq_weather UNIQUE (geography_id, observed_on, source_id)
);

CREATE INDEX IF NOT EXISTS idx_weather_geo_date
  ON weather_observation(geography_id, observed_on);

COMMENT ON TABLE weather_observation IS
  'Daily weather observations matched to region. NULL for unmeasured values.';
