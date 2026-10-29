-- =============================================================================
-- Task 2 | Week 2 Internship Assessment
-- DATABASE SCHEMA DESIGN & QUERY OPTIMIZATION
-- Agribusiness Data Analysis Platform
-- Database: PostgreSQL 15+
-- =============================================================================

-- =============================================================================
-- REFERENCE / GEOGRAPHY TABLES
-- =============================================================================

-- 1. region: administrative/geographic grouping
CREATE TABLE region (
  region_id    BIGINT      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  region_name  VARCHAR(120) NOT NULL,
  country_code CHAR(3)      NOT NULL,
  CONSTRAINT uq_region_name_country UNIQUE (region_name, country_code)
);

-- 2. farm: farm identity and its location
CREATE TABLE farm (
  farm_id        BIGINT         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  farm_code      VARCHAR(40)    NOT NULL UNIQUE,
  farm_name      VARCHAR(160)   NOT NULL,
  region_id      BIGINT         NOT NULL REFERENCES region(region_id),
  area_hectares  NUMERIC(12,2)  NOT NULL CHECK (area_hectares > 0),
  created_at     TIMESTAMPTZ    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 3. crop: crop/commodity reference data
CREATE TABLE crop (
  crop_id        BIGINT       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  crop_name      VARCHAR(100) NOT NULL UNIQUE,
  crop_category  VARCHAR(60),
  standard_unit  VARCHAR(30)  NOT NULL DEFAULT 'tonne'
);

-- 4. livestock_type: species or production class
CREATE TABLE livestock_type (
  livestock_type_id  BIGINT       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  type_name          VARCHAR(100) NOT NULL UNIQUE,
  production_purpose VARCHAR(120)
);

-- 5. market: market identity and location
CREATE TABLE market (
  market_id    BIGINT       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  market_name  VARCHAR(160) NOT NULL,
  region_id    BIGINT       NOT NULL REFERENCES region(region_id),
  market_type  VARCHAR(60)
);

-- =============================================================================
-- FACT TABLES
-- =============================================================================

-- 6. harvest: farm-level crop output per season/date
CREATE TABLE harvest (
  harvest_id       BIGINT         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  farm_id          BIGINT         NOT NULL REFERENCES farm(farm_id),
  crop_id          BIGINT         NOT NULL REFERENCES crop(crop_id),
  season_year      SMALLINT       NOT NULL,
  harvest_date     DATE           NOT NULL,
  area_planted_ha  NUMERIC(12,2)  NOT NULL CHECK (area_planted_ha > 0),
  quantity_tonnes  NUMERIC(14,3)  NOT NULL CHECK (quantity_tonnes >= 0)
);

-- 7. livestock_observation: periodic animal count and related measure
CREATE TABLE livestock_observation (
  observation_id     BIGINT         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  farm_id            BIGINT         NOT NULL REFERENCES farm(farm_id),
  livestock_type_id  BIGINT         NOT NULL REFERENCES livestock_type(livestock_type_id),
  observed_on        DATE           NOT NULL,
  animal_count       INT            NOT NULL CHECK (animal_count >= 0),
  average_weight_kg  NUMERIC(10,2)  -- NULL when not measured
);

-- 8. market_price: price observations for commodities at markets
CREATE TABLE market_price (
  price_id         BIGINT         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  market_id        BIGINT         NOT NULL REFERENCES market(market_id),
  crop_id          BIGINT         NOT NULL REFERENCES crop(crop_id),
  observed_on      DATE           NOT NULL,
  price_per_tonne  NUMERIC(14,2)  NOT NULL CHECK (price_per_tonne >= 0),
  currency_code    CHAR(3)        NOT NULL,
  -- One daily quote per market/crop/date/currency (remove if multiple sources exist)
  CONSTRAINT uq_market_price_daily UNIQUE (market_id, crop_id, observed_on, currency_code)
);
