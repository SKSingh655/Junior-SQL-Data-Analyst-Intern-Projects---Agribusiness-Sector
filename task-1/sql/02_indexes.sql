-- =====================================================================
-- File: 02_indexes.sql  (index strategy; verify with EXPLAIN ANALYZE)
-- =====================================================================
SET search_path TO agri;

-- Foreign-key columns used in joins (PostgreSQL does not index FKs automatically)
CREATE INDEX idx_farm_region        ON dim_farm (region_id);
CREATE INDEX idx_market_region      ON dim_market (region_id);
CREATE INDEX idx_prod_farm          ON fact_crop_production (farm_id);
CREATE INDEX idx_prod_crop_year     ON fact_crop_production (crop_id, season_year);
CREATE INDEX idx_live_farm_date     ON fact_livestock_record (farm_id, record_date);
CREATE INDEX idx_live_species       ON fact_livestock_record (species_id);
CREATE INDEX idx_input_farm_crop    ON fact_input_usage (farm_id, crop_id, season_year);
CREATE INDEX idx_sales_crop_date    ON fact_sales (crop_id, sale_date);
CREATE INDEX idx_sales_farm         ON fact_sales (farm_id);
CREATE INDEX idx_sales_market       ON fact_sales (market_id);
CREATE INDEX idx_soil_farm_date     ON fact_soil_test (farm_id, test_date DESC);

-- Covering index: price trend queries can be answered from the index alone
CREATE INDEX idx_price_crop_market_date
    ON fact_market_price (crop_id, market_id, price_date)
    INCLUDE (modal_price, arrivals_tonnes);

-- BRIN: tiny index for very large, append-only, date-ordered tables
CREATE INDEX idx_weather_date_brin ON fact_weather_daily USING BRIN (obs_date);

-- Partial index: only the rows that a recurring report needs
CREATE INDEX idx_prod_kharif_recent
    ON fact_crop_production (crop_id, farm_id)
    WHERE season = 'kharif' AND season_year >= 2020;
