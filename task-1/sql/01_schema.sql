-- =====================================================================
-- Agribusiness Analytics Database  |  PostgreSQL 14+
-- File: 01_schema.sql  (dimension, fact, staging and audit tables)
-- =====================================================================
CREATE SCHEMA IF NOT EXISTS agri;
SET search_path TO agri;

-- ---------------------------- DIMENSIONS -----------------------------
CREATE TABLE dim_region (
    region_id   SERIAL PRIMARY KEY,
    country     VARCHAR(60)  NOT NULL DEFAULT 'India',
    state_name  VARCHAR(80)  NOT NULL,
    district    VARCHAR(80)  NOT NULL,
    latitude    NUMERIC(9,6),
    longitude   NUMERIC(9,6),
    UNIQUE (country, state_name, district)
);

CREATE TABLE dim_farm (
    farm_id        SERIAL PRIMARY KEY,
    region_id      INT          NOT NULL REFERENCES dim_region(region_id),
    farm_name      VARCHAR(120) NOT NULL,   -- anonymised label, no personal data
    farm_type      VARCHAR(20)  NOT NULL
                   CHECK (farm_type IN ('crop','livestock','mixed')),
    total_area_ha  NUMERIC(10,2) NOT NULL CHECK (total_area_ha > 0),
    registered_on  DATE         NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE dim_crop (
    crop_id           SERIAL PRIMARY KEY,
    crop_name         VARCHAR(80) NOT NULL UNIQUE,
    crop_category     VARCHAR(40) NOT NULL,  -- cereal, pulse, oilseed, vegetable...
    typical_season    VARCHAR(20)
                      CHECK (typical_season IN ('kharif','rabi','zaid','perennial')),
    avg_duration_days INT CHECK (avg_duration_days > 0)
);

CREATE TABLE dim_livestock_species (
    species_id      SERIAL PRIMARY KEY,
    species_name    VARCHAR(60) NOT NULL UNIQUE,
    primary_purpose VARCHAR(20) NOT NULL
                    CHECK (primary_purpose IN ('milk','meat','eggs','draught','wool','mixed'))
);

CREATE TABLE dim_market (
    market_id    SERIAL PRIMARY KEY,
    region_id    INT          NOT NULL REFERENCES dim_region(region_id),
    market_name  VARCHAR(120) NOT NULL,
    market_type  VARCHAR(20)  NOT NULL
                 CHECK (market_type IN ('mandi','wholesale','retail','export')),
    UNIQUE (region_id, market_name)
);

CREATE TABLE dim_date AS
SELECT d::date                          AS date_id,
       EXTRACT(YEAR    FROM d)::INT     AS year_num,
       EXTRACT(QUARTER FROM d)::INT     AS quarter_num,
       EXTRACT(MONTH   FROM d)::INT     AS month_num,
       TO_CHAR(d, 'Mon')                AS month_name,
       EXTRACT(WEEK    FROM d)::INT     AS week_num,
       CASE WHEN EXTRACT(MONTH FROM d) BETWEEN 6  AND 10 THEN 'kharif'
            WHEN EXTRACT(MONTH FROM d) IN (11,12,1,2,3,4) THEN 'rabi'
            ELSE 'zaid' END             AS agri_season
FROM generate_series(DATE '2015-01-01', DATE '2030-12-31', INTERVAL '1 day') AS g(d);
ALTER TABLE dim_date ADD PRIMARY KEY (date_id);

-- ------------------------------- FACTS -------------------------------
CREATE TABLE fact_crop_production (
    production_id     BIGSERIAL PRIMARY KEY,
    farm_id           INT         NOT NULL REFERENCES dim_farm(farm_id),
    crop_id           INT         NOT NULL REFERENCES dim_crop(crop_id),
    season_year       SMALLINT    NOT NULL CHECK (season_year BETWEEN 1990 AND 2100),
    season            VARCHAR(20) NOT NULL CHECK (season IN ('kharif','rabi','zaid','perennial')),
    area_planted_ha   NUMERIC(10,2) NOT NULL CHECK (area_planted_ha > 0),
    production_tonnes NUMERIC(12,3) NOT NULL CHECK (production_tonnes >= 0),
    yield_t_per_ha    NUMERIC(10,3) GENERATED ALWAYS AS
                      (production_tonnes / area_planted_ha) STORED,
    irrigation_type   VARCHAR(30),
    UNIQUE (farm_id, crop_id, season_year, season)
);

CREATE TABLE fact_livestock_record (
    record_id       BIGSERIAL PRIMARY KEY,
    farm_id         INT  NOT NULL REFERENCES dim_farm(farm_id),
    species_id      INT  NOT NULL REFERENCES dim_livestock_species(species_id),
    record_date     DATE NOT NULL,
    head_count      INT  NOT NULL CHECK (head_count >= 0),
    milk_litres     NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (milk_litres >= 0),
    eggs_count      INT  NOT NULL DEFAULT 0 CHECK (eggs_count >= 0),
    mortality_count INT  NOT NULL DEFAULT 0 CHECK (mortality_count >= 0),
    feed_kg         NUMERIC(10,2) CHECK (feed_kg >= 0),
    veterinary_cost NUMERIC(12,2) CHECK (veterinary_cost >= 0),
    UNIQUE (farm_id, species_id, record_date)
);

CREATE TABLE fact_market_price (
    price_id       BIGSERIAL PRIMARY KEY,
    market_id      INT  NOT NULL REFERENCES dim_market(market_id),
    crop_id        INT  NOT NULL REFERENCES dim_crop(crop_id),
    price_date     DATE NOT NULL,
    min_price      NUMERIC(10,2) NOT NULL CHECK (min_price >= 0),
    max_price      NUMERIC(10,2) NOT NULL,
    modal_price    NUMERIC(10,2) NOT NULL,   -- INR per quintal (standardised on load)
    arrivals_tonnes NUMERIC(12,3) CHECK (arrivals_tonnes >= 0),
    UNIQUE (market_id, crop_id, price_date),
    CHECK (min_price <= modal_price AND modal_price <= max_price)
);

CREATE TABLE fact_weather_daily (
    weather_id   BIGSERIAL PRIMARY KEY,
    region_id    INT  NOT NULL REFERENCES dim_region(region_id),
    obs_date     DATE NOT NULL,
    rainfall_mm  NUMERIC(7,2) CHECK (rainfall_mm >= 0),
    temp_max_c   NUMERIC(4,1),
    temp_min_c   NUMERIC(4,1),
    humidity_pct NUMERIC(5,2) CHECK (humidity_pct BETWEEN 0 AND 100),
    UNIQUE (region_id, obs_date),
    CHECK (temp_min_c <= temp_max_c)
);

CREATE TABLE fact_soil_test (
    test_id            BIGSERIAL PRIMARY KEY,
    farm_id            INT  NOT NULL REFERENCES dim_farm(farm_id),
    test_date          DATE NOT NULL,
    ph                 NUMERIC(3,1) CHECK (ph BETWEEN 3 AND 11),
    nitrogen_kg_ha     NUMERIC(8,2) CHECK (nitrogen_kg_ha >= 0),
    phosphorus_kg_ha   NUMERIC(8,2) CHECK (phosphorus_kg_ha >= 0),
    potassium_kg_ha    NUMERIC(8,2) CHECK (potassium_kg_ha >= 0),
    organic_carbon_pct NUMERIC(4,2) CHECK (organic_carbon_pct >= 0),
    UNIQUE (farm_id, test_date)
);

CREATE TABLE fact_input_usage (
    input_id    BIGSERIAL PRIMARY KEY,
    farm_id     INT         NOT NULL REFERENCES dim_farm(farm_id),
    crop_id     INT         NOT NULL REFERENCES dim_crop(crop_id),
    season_year SMALLINT    NOT NULL,
    input_type  VARCHAR(20) NOT NULL
                CHECK (input_type IN ('seed','fertilizer','pesticide','labour',
                                      'machinery','irrigation','other')),
    quantity    NUMERIC(12,2) CHECK (quantity >= 0),
    unit        VARCHAR(20),
    cost        NUMERIC(14,2) NOT NULL CHECK (cost >= 0)
);

CREATE TABLE fact_sales (
    sale_id          BIGSERIAL PRIMARY KEY,
    farm_id          INT  NOT NULL REFERENCES dim_farm(farm_id),
    crop_id          INT  NOT NULL REFERENCES dim_crop(crop_id),
    market_id        INT  NOT NULL REFERENCES dim_market(market_id),
    sale_date        DATE NOT NULL,
    quantity_tonnes  NUMERIC(12,3) NOT NULL CHECK (quantity_tonnes > 0),
    price_per_tonne  NUMERIC(12,2) NOT NULL CHECK (price_per_tonne > 0),
    revenue          NUMERIC(16,2) GENERATED ALWAYS AS
                     (quantity_tonnes * price_per_tonne) STORED
);

-- ---------------------- STAGING AND AUDIT TABLES ---------------------
-- Staging keeps raw text so that bad rows never break the bulk load.
CREATE TABLE stg_market_price (
    batch_id        TEXT,
    market_name     TEXT,
    state_name      TEXT,
    district        TEXT,
    commodity       TEXT,
    price_date      TEXT,
    min_price       TEXT,
    max_price       TEXT,
    modal_price     TEXT,
    arrivals_tonnes TEXT,
    loaded_at       TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE etl_error_log (
    error_id      BIGSERIAL PRIMARY KEY,
    batch_id      TEXT,
    source_name   TEXT,
    target_table  TEXT,
    sqlstate_code TEXT,
    error_message TEXT,
    raw_record    JSONB,
    logged_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
