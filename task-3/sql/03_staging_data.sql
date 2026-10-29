-- =============================================================================
-- Task 3 | Week 3 Internship Assessment
-- SAMPLE BATCH METADATA & STAGING DATA
-- Agribusiness ETL Process Plan
-- Database: PostgreSQL 15+
-- =============================================================================
-- Simulates raw rows arriving from three public sources:
--   1. Agmarknet (market prices)
--   2. FAOSTAT/National crop stats (crop production)
--   3. IMD/NASA POWER (weather)
-- All values are illustrative and synthetic.
-- =============================================================================

-- =============================================================================
-- STEP 1: Register batches in etl_batch
-- =============================================================================
INSERT INTO etl_batch
  (batch_id, source_name, source_uri, status,
   extracted_rows, schema_version, file_hash)
VALUES
  -- Batch 1: Agmarknet market prices
  ('a1000000-0000-0000-0000-000000000001'::uuid,
   'agmarknet',
   'https://agmarknet.gov.in/SearchCmmMkt.aspx',
   'extracted', 35, 'v1.0',
   'sha256:abc123placeholder'),

  -- Batch 2: FAOSTAT crop production stats
  ('a2000000-0000-0000-0000-000000000002'::uuid,
   'faostat',
   'https://www.fao.org/faostat/en/#data/QCL',
   'extracted', 20, 'v2.1',
   'sha256:def456placeholder'),

  -- Batch 3: IMD weather observations
  ('a3000000-0000-0000-0000-000000000003'::uuid,
   'imd_weather',
   'https://mausam.imd.gov.in/imd_latest/contents/all-india-daily-rainfall.php',
   'extracted', 25, 'v1.0',
   'sha256:ghi789placeholder');

-- =============================================================================
-- STEP 2: Seed crosswalk / alias tables
-- =============================================================================

-- Crop aliases (Agmarknet uses different commodity labels)
INSERT INTO crop_alias (source_name, source_crop_label, crop_id, notes) VALUES
  ('agmarknet', 'Wheat',      1, 'Direct match'),
  ('agmarknet', 'Paddy',      2, 'Paddy = Rice (pre-milling)'),
  ('agmarknet', 'Maize',      3, 'Direct match'),
  ('agmarknet', 'Sugarcane',  4, 'Direct match'),
  ('agmarknet', 'Cotton(lint)',5, 'Lint cotton maps to Cotton'),
  ('agmarknet', 'Soybean',    6, 'Direct match'),
  ('agmarknet', 'Mustard',    7, 'Direct match'),
  ('agmarknet', 'Groundnut',  8, 'Direct match'),
  ('faostat',   'Wheat',      1, 'Direct match'),
  ('faostat',   'Rice, paddy',2, 'FAOSTAT paddy label'),
  ('faostat',   'Maize (corn)',3, 'FAOSTAT maize label'),
  ('faostat',   'Sugar cane', 4, 'FAOSTAT uses two words'),
  ('faostat',   'Soybeans',   6, 'FAOSTAT plural'),
  ('faostat',   'Mustard seed',7,'FAOSTAT seed label');

-- Geography aliases
INSERT INTO geography_alias (source_name, source_geo_code, geography_id, notes) VALUES
  ('agmarknet', 'Punjab',      1, 'State name direct match'),
  ('agmarknet', 'Haryana',     2, 'State name direct match'),
  ('agmarknet', 'Maharashtra', 3, 'State name direct match'),
  ('agmarknet', 'Karnataka',   4, 'State name direct match'),
  ('agmarknet', 'Rajasthan',   5, 'State name direct match'),
  ('faostat',   'IN-PB',       1, 'ISO 3166-2 Punjab'),
  ('faostat',   'IN-HR',       2, 'ISO 3166-2 Haryana'),
  ('faostat',   'IN-MH',       3, 'ISO 3166-2 Maharashtra'),
  ('faostat',   'IN-KA',       4, 'ISO 3166-2 Karnataka'),
  ('faostat',   'IN-RJ',       5, 'ISO 3166-2 Rajasthan'),
  ('imd_weather','PB',         1, 'IMD state abbreviation'),
  ('imd_weather','HR',         2, 'IMD state abbreviation'),
  ('imd_weather','MH',         3, 'IMD state abbreviation'),
  ('imd_weather','KA',         4, 'IMD state abbreviation'),
  ('imd_weather','RJ',         5, 'IMD state abbreviation');

-- Market aliases
INSERT INTO market_alias (source_name, source_market_label, market_id, notes) VALUES
  ('agmarknet', 'Amritsar',      1, 'City name match'),
  ('agmarknet', 'Ludhiana',      2, 'City name match'),
  ('agmarknet', 'Karnal',        3, 'City name match'),
  ('agmarknet', 'Pune',          4, 'City name match'),
  ('agmarknet', 'Hubli-Dharwad', 5, 'Agmarknet uses combined name'),
  ('agmarknet', 'Jaipur',        6, 'City name match');

-- =============================================================================
-- STEP 3: Load raw rows into staging tables
-- Mix of valid and intentionally invalid rows to demonstrate validation.
-- =============================================================================

-- ---- stg_market_price (Batch 1 / Agmarknet) --------------------------------
INSERT INTO stg_market_price
  (batch_id, source_row_number, source_market_name, source_crop_label,
   observed_on_raw, price_raw, unit_raw, currency_raw, grade_raw, source_updated_at)
VALUES
  -- Valid rows
  ('a1000000-0000-0000-0000-000000000001', 1,  'Amritsar',      'Wheat',       '2025-04-01', '23800',     'quintal', 'INR', 'FAQ',  '2025-04-02 06:00:00+05:30'),
  ('a1000000-0000-0000-0000-000000000001', 2,  'Amritsar',      'Wheat',       '2025-04-02', '23950',     'quintal', 'INR', 'FAQ',  '2025-04-03 06:00:00+05:30'),
  ('a1000000-0000-0000-0000-000000000001', 3,  'Ludhiana',      'Wheat',       '2025-04-01', '23700',     'quintal', 'INR', 'FAQ',  '2025-04-02 06:00:00+05:30'),
  ('a1000000-0000-0000-0000-000000000001', 4,  'Karnal',        'Paddy',       '2025-10-05', '34500',     'quintal', 'INR', 'Common','2025-10-06 06:00:00+05:30'),
  ('a1000000-0000-0000-0000-000000000001', 5,  'Pune',          'Sugarcane',   '2025-01-10', '3,200',     'tonne',   'INR', '',     '2025-01-11 06:00:00+05:30'),
  ('a1000000-0000-0000-0000-000000000001', 6,  'Hubli-Dharwad', 'Soybean',     '2025-05-15', '45500',     'quintal', 'INR', 'Yellow','2025-05-16 06:00:00+05:30'),
  ('a1000000-0000-0000-0000-000000000001', 7,  'Jaipur',        'Mustard',     '2025-03-20', '54000',     'quintal', 'INR', 'Local','2025-03-21 06:00:00+05:30'),
  ('a1000000-0000-0000-0000-000000000001', 8,  'Hubli-Dharwad', 'Cotton(lint)','2025-06-01', '67000',     'quintal', 'INR', 'Medium','2025-06-02 06:00:00+05:30'),
  ('a1000000-0000-0000-0000-000000000001', 9,  'Amritsar',      'Wheat',       '2025-05-01', '23600',     'quintal', 'INR', 'FAQ',  '2025-05-02 06:00:00+05:30'),
  ('a1000000-0000-0000-0000-000000000001', 10, 'Karnal',        'Paddy',       '2025-11-01', '35200',     'quintal', 'INR', 'Common','2025-11-02 06:00:00+05:30'),
  -- Intentionally invalid rows (for validation/reject demo)
  ('a1000000-0000-0000-0000-000000000001', 11, NULL,            'Wheat',       '2025-04-03', '24000',     'quintal', 'INR', 'FAQ',  NULL),              -- MISSING_MARKET
  ('a1000000-0000-0000-0000-000000000001', 12, 'Amritsar',      NULL,          '2025-04-03', '24000',     'quintal', 'INR', 'FAQ',  NULL),              -- MISSING_CROP
  ('a1000000-0000-0000-0000-000000000001', 13, 'Ludhiana',      'Wheat',       '04/05/2025', '24100',     'quintal', 'INR', 'FAQ',  NULL),              -- INVALID_DATE_FORMAT
  ('a1000000-0000-0000-0000-000000000001', 14, 'Karnal',        'Paddy',       '2025-10-06', 'N/A',       'quintal', 'INR', 'Common',NULL),             -- INVALID_PRICE
  ('a1000000-0000-0000-0000-000000000001', 15, 'Pune',          'Sugarcane',   '2025-01-11', '-500',      'tonne',   'INR', '',     NULL);              -- NEGATIVE_PRICE

-- ---- stg_crop_production (Batch 2 / FAOSTAT) --------------------------------
INSERT INTO stg_crop_production
  (batch_id, source_row_number, source_geo_code, source_geo_name,
   source_crop_label, period_raw, area_raw, production_raw, unit_raw, source_updated_at)
VALUES
  -- Valid rows
  ('a2000000-0000-0000-0000-000000000002', 1,  'IN-PB', 'Punjab',      'Wheat',       '2024', '3520000', '19800000', 'tonne', '2025-01-15 00:00:00+00'),
  ('a2000000-0000-0000-0000-000000000002', 2,  'IN-PB', 'Punjab',      'Rice, paddy', '2024', '2800000', '11760000', 'tonne', '2025-01-15 00:00:00+00'),
  ('a2000000-0000-0000-0000-000000000002', 3,  'IN-HR', 'Haryana',     'Wheat',       '2024', '2550000', '13770000', 'tonne', '2025-01-15 00:00:00+00'),
  ('a2000000-0000-0000-0000-000000000002', 4,  'IN-HR', 'Haryana',     'Mustard seed','2024',  '750000',  '1350000', 'tonne', '2025-01-15 00:00:00+00'),
  ('a2000000-0000-0000-0000-000000000002', 5,  'IN-MH', 'Maharashtra', 'Sugar cane',  '2024', '1100000', '59400000', 'tonne', '2025-01-15 00:00:00+00'),
  ('a2000000-0000-0000-0000-000000000002', 6,  'IN-MH', 'Maharashtra', 'Soybeans',    '2024', '4200000',  '6720000', 'tonne', '2025-01-15 00:00:00+00'),
  ('a2000000-0000-0000-0000-000000000002', 7,  'IN-KA', 'Karnataka',   'Maize (corn)','2024',  '950000',  '2660000', 'tonne', '2025-01-15 00:00:00+00'),
  ('a2000000-0000-0000-0000-000000000002', 8,  'IN-RJ', 'Rajasthan',   'Mustard seed','2024', '2900000',  '5220000', 'tonne', '2025-01-15 00:00:00+00'),
  ('a2000000-0000-0000-0000-000000000002', 9,  'IN-PB', 'Punjab',      'Wheat',       '2025', '3580000', '20508000', 'tonne', '2026-01-10 00:00:00+00'),
  ('a2000000-0000-0000-0000-000000000002', 10, 'IN-HR', 'Haryana',     'Wheat',       '2025', '2600000', '14326000', 'tonne', '2026-01-10 00:00:00+00'),
  -- Invalid rows
  ('a2000000-0000-0000-0000-000000000002', 11, NULL,    NULL,          'Wheat',       '2024', '1000000', '5000000',  'tonne', NULL),   -- MISSING_GEO
  ('a2000000-0000-0000-0000-000000000002', 12, 'IN-PB', 'Punjab',      NULL,          '2024', '500000',  '2500000',  'tonne', NULL),   -- MISSING_CROP
  ('a2000000-0000-0000-0000-000000000002', 13, 'IN-MH', 'Maharashtra', 'Sugar cane',  'TBD',  '1100000', '59000000', 'tonne', NULL),   -- INVALID_PERIOD
  ('a2000000-0000-0000-0000-000000000002', 14, 'IN-KA', 'Karnataka',   'Maize (corn)','2024', '-500',    '2660000',  'tonne', NULL),   -- NEGATIVE_AREA
  ('a2000000-0000-0000-0000-000000000002', 15, 'IN-PB', 'Punjab',      'Wheat',       '2024', '3520000', 'N/A',      'tonne', NULL);   -- INVALID_PRODUCTION

-- ---- stg_weather (Batch 3 / IMD) -------------------------------------------
INSERT INTO stg_weather
  (batch_id, source_row_number, source_geo_code,
   observed_on_raw, rainfall_mm_raw, temp_max_raw, temp_min_raw, humidity_raw, source_updated_at)
VALUES
  -- Valid rows
  ('a3000000-0000-0000-0000-000000000003', 1,  'PB', '2025-06-01', '12.5', '38.2', '27.1', '72', '2025-06-02 00:00:00+05:30'),
  ('a3000000-0000-0000-0000-000000000003', 2,  'PB', '2025-06-02', '0',    '39.5', '28.0', '65', '2025-06-03 00:00:00+05:30'),
  ('a3000000-0000-0000-0000-000000000003', 3,  'PB', '2025-06-03', '45.2', '33.1', '24.5', '89', '2025-06-04 00:00:00+05:30'),
  ('a3000000-0000-0000-0000-000000000003', 4,  'HR', '2025-06-01', '5.0',  '40.1', '28.2', '68', '2025-06-02 00:00:00+05:30'),
  ('a3000000-0000-0000-0000-000000000003', 5,  'HR', '2025-06-02', '0',    '41.0', '29.5', '61', '2025-06-03 00:00:00+05:30'),
  ('a3000000-0000-0000-0000-000000000003', 6,  'MH', '2025-06-01', '88.0', '31.2', '24.0', '92', '2025-06-02 00:00:00+05:30'),
  ('a3000000-0000-0000-0000-000000000003', 7,  'MH', '2025-06-02', '120.5','29.8', '23.1', '95', '2025-06-03 00:00:00+05:30'),
  ('a3000000-0000-0000-0000-000000000003', 8,  'KA', '2025-06-01', '55.0', '29.5', '21.5', '88', '2025-06-02 00:00:00+05:30'),
  ('a3000000-0000-0000-0000-000000000003', 9,  'RJ', '2025-06-01', '0',    '42.5', '30.0', '45', '2025-06-02 00:00:00+05:30'),
  ('a3000000-0000-0000-0000-000000000003', 10, 'RJ', '2025-06-02', '0',    '43.0', '30.5', '42', '2025-06-03 00:00:00+05:30'),
  -- Invalid rows
  ('a3000000-0000-0000-0000-000000000003', 11, NULL, '2025-06-01', '10.0', '38.0', '26.0', '70', NULL),              -- MISSING_GEO
  ('a3000000-0000-0000-0000-000000000003', 12, 'PB', '01/06/2025', '10.0', '38.0', '26.0', '70', NULL),              -- INVALID_DATE_FORMAT
  ('a3000000-0000-0000-0000-000000000003', 13, 'HR', '2025-06-03', '-5.0', '40.0', '27.0', '60', NULL),              -- NEGATIVE_RAINFALL
  ('a3000000-0000-0000-0000-000000000003', 14, 'MH', '2025-06-03', 'N/A',  '30.0', '22.0', '90', NULL),              -- INVALID_RAINFALL
  ('a3000000-0000-0000-0000-000000000003', 15, 'KA', '2025-06-02', '60.0', 'HOT',  '21.0', '85', NULL);              -- INVALID_TEMP
