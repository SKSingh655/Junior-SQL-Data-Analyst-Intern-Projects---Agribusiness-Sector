-- =============================================================================
-- Task 2 | Week 2 Internship Assessment
-- INDEXES FOR QUERY OPTIMIZATION
-- Agribusiness Data Analysis Platform
-- Database: PostgreSQL 15+
-- =============================================================================
-- NOTE: Indexes should be created AFTER schema (01_schema.sql) and sample
--       data (03_sample_data.sql) are loaded. Measure before/after with
--       EXPLAIN (ANALYZE, BUFFERS) on representative data.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- FARM table
-- -----------------------------------------------------------------------------
-- Supports filtering / joining by region
CREATE INDEX IF NOT EXISTS idx_farm_region_id
  ON farm(region_id);

-- -----------------------------------------------------------------------------
-- HARVEST table
-- -----------------------------------------------------------------------------
-- Year-based production reports (most common analytics filter)
CREATE INDEX IF NOT EXISTS idx_harvest_season_year_crop_farm
  ON harvest(season_year, crop_id, farm_id);

-- Date-window reports by farm (half-open range queries)
CREATE INDEX IF NOT EXISTS idx_harvest_date_farm
  ON harvest(harvest_date, farm_id);

-- Crop-first lookups (e.g., all harvests for a given crop)
CREATE INDEX IF NOT EXISTS idx_harvest_crop_id
  ON harvest(crop_id);

-- -----------------------------------------------------------------------------
-- MARKET_PRICE table
-- -----------------------------------------------------------------------------
-- Currency + date filter (most trend queries filter by currency first)
CREATE INDEX IF NOT EXISTS idx_market_price_currency_date
  ON market_price(currency_code, observed_on);

-- Market + crop + date history (per-commodity at a specific market)
CREATE INDEX IF NOT EXISTS idx_market_price_market_crop_date
  ON market_price(market_id, crop_id, observed_on);

-- -----------------------------------------------------------------------------
-- LIVESTOCK_OBSERVATION table
-- -----------------------------------------------------------------------------
-- Latest-observation query: partition by farm/type, order by date DESC
CREATE INDEX IF NOT EXISTS idx_livestock_obs_farm_type_date
  ON livestock_observation(farm_id, livestock_type_id, observed_on DESC);

-- -----------------------------------------------------------------------------
-- MARKET table
-- -----------------------------------------------------------------------------
-- Filter markets by region
CREATE INDEX IF NOT EXISTS idx_market_region_id
  ON market(region_id);
